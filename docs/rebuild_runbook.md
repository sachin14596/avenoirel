# AVENOIREL rebuild runbook

How to rebuild the whole AVENOIREL setup in a new, empty Snowflake account, starting from zero.
Every step has a check. If a check fails, stop and find the root cause before going on.

Status tags: `[VERIFIED]` proven by running it, `[ASSUMED]` taken from documentation, not yet run.
Sections 2 to 5 were run end to end on the existing account on 2026-11-23 (`[VERIFIED]`, the scripts
are safe to repeat). In section 0 the venv and the imports were verified in a fresh venv the same
day. The rest of section 0, and sections 1 and 6, are `[ASSUMED]` until the first real migration
has followed them.

## Sections

0. Local machine
1. Snowflake trial account
2. Snowflake scripts 00 to 06
3. Frozen raw data
4. Load, clone and dbt build
5. Smoke test
6. GitHub secrets, CI and Airflow
7. If something fails

## 0. Local machine

Why: dbt, the loader and the checks run on your computer and talk to Snowflake.

Tools (versions used and verified):
- Shell: bash (MSYS2 UCRT64 on Windows)
- Git 2.56
- Python 3.12.10 (3.14 is not compatible)
- Docker Desktop 29.0.1 and Astro CLI 1.45.0: only for local Airflow (section 6)

Steps:
1. Clone the repo (any folder works, the original is `D:\Projects\avenoirel`):
   `git clone https://github.com/sachin14596/avenoirel.git && cd avenoirel`
2. Create the venv and install the pinned packages:
   `python -m venv .venv && source .venv/Scripts/activate && pip install -r requirements-local.txt`
   Do not use `requirements.txt` for this: it belongs to CI and Astro (dbt 1.9.5).
3. Install the git hooks: `pre-commit install`
4. Create `.env` in the repo root (it is gitignored, never commit it). One `NAME=value` per line:
   - `SNOWFLAKE_ACCOUNT` = account identifier from section 1 (format `org-account`)
   - `SNOWFLAKE_USER`, `SNOWFLAKE_PASSWORD` = from section 1
   - `SNOWFLAKE_WAREHOUSE=AVENOIREL_WH`
   - `SNOWFLAKE_DATABASE=AVENOIREL_DEV`
   - `SNOWFLAKE_SCHEMA=RAW` (upper case: the loader quotes the name, so `raw` is not found)
   - `SNOWFLAKE_ROLE=DEV_ROLE`
   - `DBT_ENV=dev` (a label, nothing reads it)
   - `ANTHROPIC_API_KEY` is only needed from Phase 6, leave it out for a rebuild
   Fill account, user and password after section 1. The role works only after section 2.
5. Create the dbt profile: `cp dags/dbt/profiles.yml.example dags/dbt/profiles.yml`
   (gitignored). It has three targets: dev (reads the env vars), prod and preprod (role
   `prod_role`, databases `avenoirel_prod` and `avenoirel_preprod`).
6. In every new terminal run `source activate.sh`. It activates the venv and loads `.env`.
7. Always pass `--project-dir dags/dbt --profiles-dir dags/dbt` to dbt. A stale
   `~/.dbt/profiles.yml` on the machine can contain the wrong user.

Check:
- `source activate.sh` prints the new account identifier
- `dbt --version` shows core 1.8.8 and snowflake 1.8.4
- `python -c "import pandas, dotenv, yaml, faker, snowflake.connector"` prints no error
- `dbt debug` is checked after section 2, when the roles exist

## 1. Snowflake trial account

Why: everything below runs inside a Snowflake account. A trial lasts 30 days or until the free
credits are used, whichever comes first, so this section is repeated every time the trial ends.

1. Open https://signup.snowflake.com and fill in the form. A valid email is enough, no payment
   details are needed.
2. Choose these three options. They cannot be changed later. If one is wrong, create a new trial.
   - Edition: Enterprise (masking policies and 90 day Time Travel for prod need it)
   - Cloud: AWS
   - Region: Europe (Frankfurt), region code AWS_EU_CENTRAL_1
3. Wait for the activation email, open the link, choose a user name and a password.
   Keep the password in a password manager. Never put it in the repo or in a chat.
4. Log in to Snowsight. Write down the account identifier (format `org-account`) and the
   trial end date shown in the banner.
5. MFA: trial accounts are exempt from the default MFA policy in Snowflake's documentation.
   If Snowsight asks to enrol, use an authenticator app.

Check: in a Snowsight worksheet run
`SELECT CURRENT_ACCOUNT(), CURRENT_REGION(), CURRENT_VERSION();`
Expected: the region is `AWS_EU_CENTRAL_1`. The edition is proven later: script 02 creates a
masking policy and fails on a Standard edition account.

## 2. Snowflake scripts 00 to 06

Why: they build everything inside Snowflake: databases, warehouse, roles, governance objects.
Every script is safe to run twice and starts with `USE ROLE`.

Before you run: in `scripts/snowflake/00_bootstrap_account.sql` set `CREDIT_QUOTA` (20 by default,
about 5 times the observed monthly use) for the credits of the new account.

Run (automatic): `bash scripts/rebuild_account.sh sql`
It runs 00, 01, 02, 03, 04, 06 in this order through the connector in one session and stops at
the first error. Script 05 runs after the load (section 4).

Run (manual alternative): for each script `clip < scripts/snowflake/<file>`, paste into a Snowsight
worksheet, Run all. "Run all" shows only the last result, so a success message is not proof: use
the checks below.

| Script | Role | Builds | Quick check in Snowsight |
|---|---|---|---|
| 00_bootstrap_account | ACCOUNTADMIN | 3 databases (retention 1, 7, 90 days), 4 schemas each, warehouse AVENOIREL_WH, resource monitor | `SHOW DATABASES LIKE 'AVENOIREL%'` and `SHOW WAREHOUSES LIKE 'AVENOIREL_WH'` |
| 01_roles_and_grants | ACCOUNTADMIN | 3 roles, hierarchy, grants, future grants, the roles for the user who runs it | `SHOW GRANTS TO USER <your user>` |
| 02_masking_policies | DEV_ROLE | governance schema and masking policy in dev | `SHOW MASKING POLICIES IN SCHEMA avenoirel_dev.governance` |
| 03_classification_tags | DEV_ROLE | tag data_classification in dev | `SHOW TAGS IN SCHEMA avenoirel_dev.governance` |
| 04_governance_preprod_prod | PROD_ROLE | governance schema, policy and tag in preprod and prod | `SHOW MASKING POLICIES IN ACCOUNT` |
| 06_userland_schemas | DEV_ROLE | sandbox schema avenoirel_dev.dev_sachin | `SHOW SCHEMAS LIKE 'DEV_SACHIN' IN DATABASE avenoirel_dev` |

Check:
- `dbt debug --project-dir dags/dbt --profiles-dir dags/dbt --target dev` passes, and the same for
  `--target preprod` and `--target prod`
- Script 02 creates a masking policy. If it fails with an edition error, the account is not
  Enterprise: create a new trial (section 1).
- The smoke test (section 5) repeats all of this.

## 3. Frozen raw data

Why: a rebuild never regenerates data. The 10 CSVs of version raw-v1 are the golden copy.
They are synthetic (Faker). Never put real or live guest data here.

Where it lives: GitHub Release `raw-v1` (asset `avenoirel-raw-v1.zip`), a private backup and one
copy outside the machine.

Run (automatic): `bash scripts/rebuild_account.sh data`
It downloads the zip when `data/raw/` holds fewer than 10 CSVs, then runs
`md5sum -c docs/raw_checksums.txt`.

Run (manual alternative):
`curl -fL -o raw-v1.zip https://github.com/sachin14596/avenoirel/releases/download/raw-v1/avenoirel-raw-v1.zip`
`python -m zipfile -e raw-v1.zip .` then `md5sum -c docs/raw_checksums.txt`

Check: all 10 files say OK. If one does not, stop: do not load.

If the data ever has to change: generate new CSVs with `scripts/generate_data.py` (seed 42), publish
them as release `raw-v2`, write a new checksum file, and update this runbook and the smoke test
numbers together.

Note: `docs/raw_checksums.txt` must keep LF line endings (`.gitattributes` has `*.txt text eol=lf`),
otherwise `md5sum -c` fails on Windows.

## 4. Load, clone and dbt build

Run: `bash scripts/rebuild_account.sh load clone dbt`

- load: the loader runs as DEV_ROLE into `AVENOIREL_DEV.RAW`. The runner sets role, database,
  warehouse and the schema (upper case `RAW`) itself. Dev owns the tables and PROD_ROLE reads them
  through the role hierarchy. The loader exits with an error if a CSV is missing or a table fails.
- clone: script 05 as PROD_ROLE clones the 10 raw tables (zero copy, table by table) into preprod
  and prod.
- dbt: `dbt deps`, then `dbt build --exclude-resource-type unit_test` for dev, preprod and prod.
  It took about 3 minutes per target.

Expected for each target: `PASS=368 WARN=2 ERROR=0 SKIP=0 TOTAL=370`. The runner stops if preprod
or prod differ. The 2 WARN are known data issues: assert_nights_match_stay_dates (86 rows) and
assert_property_rooms_match_inventory (45 rows). dbt prints 5 "Masked and tagged" lines for
dim_guest per target.

Check: the smoke test (section 5) compares the raw row counts and the object counts.

## 5. Smoke test

Run: `python scripts/smoke_test.py` (or `bash scripts/rebuild_account.sh smoke`).
Exit code 0 and "All checks passed" means the rebuilt account is proven.

| Check | Expected |
|---|---|
| Databases | 3, retention dev 1 / preprod 7 / prod 90 |
| Warehouse | AVENOIREL_WH X-Small, auto-suspend 60, query acceleration false, monitor AVENOIREL_MONITOR |
| Roles | dev_role and analyst_role granted to prod_role, the admin user holds all 3 roles |
| Governance | mask_pii_string and data_classification in all 3 databases, owner DEV_ROLE in dev, PROD_ROLE in preprod and prod |
| Raw rows (all 3 databases) | properties 50, room_types 305, guests 45,000, avenir_members 29,173, reservations 60,300, folios 78,241, cancellations 14,034, room_availability 334,280, avenir_points_transactions 30,343, avenir_tier_history 45,190 |
| Objects per schema (all 3) | RAW 10, STAGING 15, INTERMEDIATE 7, MARTS 12, SNAPSHOT 1, DBT_TEST__AUDIT 2 |
| dim_guest | 45,000 rows in all 3, 5 columns masked and tagged PII |
| analyst_role | 12 SELECT on the prod marts, USAGE on prod and prod.marts |
| RBAC tests 1 to 4 | pass, each with a positive control |

The RBAC tests are the 3 files in `scripts/snowflake/tests/`. The smoke test runs them part by part.
The expected ERROR in test 1 (part 3B) and in test 4 (part 4C) counts as a PASS. Every part runs
with `USE SECONDARY ROLES NONE`: a user who holds all roles would otherwise carry the privileges
of all of them, and the test would prove the wrong thing.

## 6. GitHub secrets, CI and Airflow

GitHub secrets (repository settings): `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PASSWORD`,
`SNOWFLAKE_WAREHOUSE`, and for `ci.yml` also `SNOWFLAKE_ROLE` and `SNOWFLAKE_DATABASE` (dev values:
`DEV_ROLE`, `AVENOIREL_DEV`) `[ASSUMED]`. `deploy.yml` writes `prod_role` and `avenoirel_prod`
itself. Never paste secret values anywhere.

Steps:
1. Update the secrets for the new account.
2. Re-run the `dbt_ci` check (re-run it on a pull request).
3. After the next merge to main, watch the `deploy.yml` run.
4. Airflow: update the Snowflake connection of the local Astro project for the new account, run
   `astro dev start`, trigger one DAG. How the connection is configured is not written down yet:
   record it here the first time you change it.

## 7. If something fails

- Stop. Do not skip a step and do not retry blind. Read the exact error text.
- Every script is safe to run again after a fix.
- "Successful" is not proof. Use the SHOW output, a count or the smoke test.
- "does not exist or not authorized" is the same message for a missing object and for a missing
  privilege. Read the role named in the message first.
- Objects owned by DEV_ROLE are invisible to ACCOUNTADMIN. Run a script under the role that
  should own what it creates.
- In Snowsight, Ctrl+Enter runs only the statement at the cursor. Select the lines first.
- Always pass `--project-dir dags/dbt --profiles-dir dags/dbt` to dbt. A stale
  `~/.dbt/profiles.yml` can hold the wrong user.
- Schema names in `.env` for the loader are upper case (`RAW`).
