# Phase 5/8: Governance & Security

Motto: the right person sees the right data, and we can prove it.

Status: built and verified on 2026-11-23. Branch `phase/5-governance`.

---

## 1. What we built (in one paragraph)

Before this phase every role could do almost anything, and guest personal data (name, email, phone, address) was readable by everyone. After this phase:

- Three roles exist with clear limits: `dev_role` (builds in dev), `prod_role` (builds in preprod and prod), `analyst_role` (reads finished marts only).
- Guest personal data lives in one mart, `dim_guest`, and is hidden from analysts by a masking policy.
- The masking is applied automatically by dbt after every build, driven by one line of YAML (`meta: pii: true`).
- Dev, preprod and prod are real, populated environments and the deploy pipeline writes to prod only.
- Four tests prove the rules hold. A rebuild kit can recreate the whole setup in a new Snowflake account.

## 2. Why it matters

Hotel analogy: a front desk keeps the guest registration card (name, address, passport details) in a locked drawer. The night auditor can open it, the marketing intern cannot. Nobody trusts "we told the intern not to look". The lock is what counts.

In the data platform the lock is a role plus a masking policy. Without it, every dashboard and every analyst query could expose guest personal information (PII, personally identifiable information). With it, access is decided by the platform, not by good behaviour.

## 3. The story so far

- Phase 0/8 Foundation: Snowflake, synthetic Opera-style hotel data (10 raw tables), environment.
- Phase 1/8 Staging: one clean view per raw table.
- Phase 2/8 Intermediate: business logic (revenue, cancellations, loyalty).
- Phase 3/8 Marts: the tables people actually query (RevPAR, ADR, occupancy, bookings).
- Phase 4/8 Orchestration: Airflow DAGs run the builds on a schedule.
- Phase 4.5/8 Hardening: unit tests, reconciliation tests, contracts.
- Phase 5/8 Governance: the data was correct and automated, but anyone could read everything. This phase locks the doors.

## 4. Concepts in plain words

| Term | Plain meaning | Hotel analogy |
|---|---|---|
| Role (RBAC) | What you may do depends on your role, not on who you are | Key card levels: housekeeping, front desk, manager |
| Role hierarchy | A role can contain other roles | The manager card also opens everything the front desk card opens |
| Secondary roles | Extra roles active in the same session | Carrying several key cards in one pocket |
| Masking policy | A rule that shows `***MASKED***` instead of the real value for some roles | Card number printed as XXXX4444 on a receipt |
| Tag | A label on a column, here `data_classification = PII` | A red sticker "confidential" on a file |
| Post-hook | A command dbt runs right after building a table | The cleaner who locks the room after every checkout |
| Zero-copy clone | A copy that shares the same stored data until something changes | A photocopy that costs nothing until you write on it |
| Environment | dev (play), preprod (rehearse), prod (real) | Training hotel, dress rehearsal, the real hotel |
| Userland schema | A personal sandbox schema | A draft register next to the live folio system |

## 5. How the masking works (flow chart) 
01 script: roles created and granted
|
02/03/04 scripts: schema "governance" + masking policy + tag
|
schema.yml: meta: pii: true on 5 guest columns
|
dbt build: table dim_guest is built (CREATE OR REPLACE)
|
marts post-hook: macro apply_pii_masking

reads meta: pii: true
attaches the policy and the tag to each PII column
|
someone queries dim_guest
|
policy asks: is PROD_ROLE or DEV_ROLE in this session?
yes -> real value no -> MASKED 

Why the post-hook: dbt rebuilds a table with `CREATE OR REPLACE`, which drops policies attached to the old table. The hook re-attaches them on every build, so a rebuild can never silently unmask the data.


## 6. How it was built

| Step | What | Result (verified by command output) |
|---|---|---|
| 5.1 | Check the three roles exist | `dev_role`, `prod_role`, `analyst_role` present |
| 5.2 | Decide where guest PII lives | New mart `dim_guest`, staging stays unmasked |
| 5.3 | Decide which environments to populate | Preprod and prod are populated, not just documented |
| 5.4 | Build `dim_guest` with a contract | 45,000 rows, 16 columns, 6 tests pass |
| 5.5 | Roles and grants as code | `01_roles_and_grants.sql`, safe to run twice |
| 5.6 | Masking policy | `mask_pii_string` using `IS_ROLE_IN_SESSION` |
| 5.7 | Post-hook macro | `apply_pii_masking` reads `meta: pii: true` |
| 5.8 | Classification tag | `data_classification = PII` on 5 columns |
| 5.9 | Populate preprod and prod | Raw cloned, `dbt build` PASS=368 WARN=2 ERROR=0 in all three databases |
| 5.10 | Userland schema | `avenoirel_dev.dev_sachin`, owned by `dev_role` |
| 5.11 | Four RBAC tests | All four pass, each with a positive control |
| 5.12 | Rebuild kit | Runbook, runner, smoke test, frozen raw data |

### 6.1 The four RBAC tests

Each test runs one role at a time (`USE SECONDARY ROLES NONE`) and pairs the "must fail" query with a query the same role CAN run. Without that pair, a failure could just mean the object is missing.

| Test | Claim | Evidence |
|---|---|---|
| 1 | `analyst_role` cannot read prod raw | `Schema 'AVENOIREL_PROD.RAW' does not exist or not authorized`, while the same role reads `fct_bookings` (60,300 rows) |
| 2 | `analyst_role` sees masked PII | `dim_guest`: 1 distinct email value, 45,000 masked values |
| 3 | `prod_role` sees real PII | 40,758 distinct emails, 0 masked values |
| 4 | `dev_role` cannot write to prod | Zero-row INSERT into `avenoirel_prod.marts.fct_bookings` fails at database level, `dev_role` cannot even see prod |

Test 4 uses `INSERT ... SELECT ... WHERE 1 = 0`. If the test ever failed, it still could not change prod data.

## 7. Tradeoffs

- Masking by role, not by environment: a developer in dev sees real values, an analyst never does, in any environment. Simple to explain and test. The cost is that dev holds real-looking PII (the data is synthetic here).
- Policies live in a separate `governance` schema, so a dbt rebuild of marts never touches them.
- `staging` stays unmasked. Developers need real data to debug. Analysts only read marts, where PII is masked.
- Preprod and prod raw are zero-copy clones of dev raw. Cheap and instant, but they are not independent copies of a real source system.
- `prod_role` has ALL PRIVILEGES on the preprod and prod databases. Simple, but not least privilege. Trimming it is an optional later step.

## 8. Key decisions

| Decision | Choice | Reason |
|---|---|---|
| Where PII lives (K1) | `dim_guest` mart | Analysts query marts, so the mask protects what they use |
| Environments (K2) | Populate preprod and prod | They are meant to be used and demonstrated |
| Masking rule (D19) | `dev_role` and `prod_role` see real values, everyone else masked | Role-based, as is common practice `[INDUSTRY]` |
| Policy location (D20) | Separate `governance` schema | dbt rebuilds do not drop policies `[INDUSTRY]` |
| Source database (D21) | Sources read `target.database` | One place decides where dbt builds and reads |
| Deploy target (D22) | `deploy.yml` writes `prod_role` and `avenoirel_prod` directly | Environment names are config, not secrets |
| Warehouse safety (D23) | Query acceleration off, resource monitor of 20 credits | A trial account had neither guard |
| Frozen raw data (D25) | The 10 CSVs are kept forever and never regenerated | A rebuild must give identical data |
| Userland schema (D27) | Only `dev_sachin` in dev | Preprod and prod are already separate databases |
| `member_number` (D28) | Not masked | It is a join key, an indirect identifier, and the data is synthetic |
| Secondary roles (D29) | User default left as `ALL`, tests switch them off | Changing it could break dbt, the loader and Airflow |


## 9. The rebuild story

The Snowflake trial account expires about 5 December 2026, and a new trial means an empty account. Everything in this phase had to be recreatable, so the setup was turned into a kit before it was needed.

Hotel analogy: opening a new hotel from the same blueprint. The plans (scripts), the furniture list (frozen data), the opening checklist (runbook) and the final inspection (smoke test) all exist before the keys are handed over.

The kit:

- Numbered SQL scripts `00` to `06` in `scripts/snowflake/`. Each is safe to run twice.
- Frozen raw data (raw-v1): the 10 CSVs are stored as a GitHub Release asset, with a private backup and a second off-machine copy. Checksums in `docs/raw_checksums.txt` prove nothing changed. A rebuild never regenerates the data.
- A runner, `scripts/rebuild_account.sh`, that runs the steps in order and stops at the first failure.
- A smoke test, `scripts/smoke_test.py`, that checks databases, retention, warehouse, grants, row counts, masking and the RBAC tests.
- A runbook, `docs/rebuild_runbook.md`, written from an empty account: trial signup, region, local machine, scripts, data, builds, checks.

The kit was tested on the existing account before any migration: all three dbt builds gave `PASS=368 WARN=2 ERROR=0 SKIP=0 TOTAL=370` and the smoke test printed "All checks passed". The real move to a new account (planned for 30 November to 1 December 2026) has not been run yet. Update this section with what it teaches.

### 9.1 Short runbook: how to rebuild a new account

1. Create the trial account: Enterprise edition, AWS EU Frankfurt. Cloud, region and edition cannot be changed afterwards.
2. Set up the local machine: Python 3.12 venv from `requirements-local.txt`, a `.env` file with the new account, user and password (`SNOWFLAKE_SCHEMA=RAW` in upper case), and a `dags/dbt/profiles.yml` copied from `profiles.yml.example`.
3. Run the whole kit:
source activate.sh
bash scripts/rebuild_account.sh 
4. The steps are `data` (download and checksum), `sql` (scripts 00 to 06), `load` (raw into dev), `clone` (raw into preprod and prod), `dbt` (build all three targets), `smoke` (final checks). One step can be run alone, for example `bash scripts/rebuild_account.sh smoke`.
5. Update the GitHub secrets and the Airflow connection to the new account.

The full version, with checks after every step, is in `docs/rebuild_runbook.md`.

## 10. Known limitations

| Limitation | Why it exists | Impact |
|---|---|---|
| `member_number` is not masked | It is the join key of the loyalty marts, so masking would break analyst joins. It is an indirect identifier, usually controlled by access or pseudonymised. The data is synthetic | An analyst can see member numbers |
| Short unmasked window after a build | The post-hook runs after the table is built, so for a moment the new table has no policy | Analysts hold a future SELECT grant, so they can read a new table the moment it is created, before the post-hook attaches the policy. For the seconds of a build, real values could be visible. Reasoned from how future grants work, not tested `[ASSUMED]`. Later option: build in a window analysts do not use, or attach the policy at creation `[INDUSTRY]` |
| NULL emails are masked too | The policy body ends with `ELSE '***MASKED***'` | Better for privacy, but an analyst cannot see which guests have no email |
| Secondary roles default is `ALL` | The test user holds every role. Changing the default could affect dbt, the loader and Airflow | The tests and the smoke test switch secondary roles off. A real analyst user who holds only `analyst_role` is not affected |
| Masking is role-based, not environment-based | Chosen for simplicity | `dev_role` sees real values in dev. Acceptable because the data is synthetic |
| `prod_role` has ALL PRIVILEGES on whole databases | Simple to operate | Not least privilege, optional trimming later |
| CI runs dbt 1.9.5, the local venv runs dbt 1.8.8 | Two requirements files (`requirements.txt` for CI and Astro, `requirements-local.txt` for local) | A difference between CI and local results is possible until the two are aligned |
| `dev_sachin` sandbox is empty | The dbt dev target does not build into it | It is a ready workspace, not a used one |
| `schema_lock.md` says guest PII is "masked in non-prod" | The comment predates the role-based rule | The comment is stale, the rule in section 8 is the truth |


## 11. How Accor does it (sources)

- Data governance as a top priority: a Snowflake customer case study on Accor (2018) says Accor made data governance a critical issue for all employees, put respect of personal data first, and has a Data Governance Board. https://www.snowflake.com/wp-content/uploads/2018/07/CS_EN_BD_CaseStudy_Talend_Accor.pdf
- Governance as one of the two biggest data challenges: CDO Magazine, March 2025, "Data Governance in Action: Inside Accor's Strategy for Data Products and Frictionless Access". https://www.cdomagazine.tech/data-management/data-governance-in-action-inside-accors-strategy-for-data-products-and-frictionless-access
- Both links come from the project notes and were not re-opened when this document was written.
- No public Accor source is on file for these choices, so they are tagged `[INDUSTRY]`: the separate `governance` schema, classification tags, the post-hook pattern, zero-copy clones per environment, resource monitors, numbered bootstrap scripts, the smoke test and the personal sandbox schema.

## 12. Challenges

### 12.1 The test that proved the wrong thing
- Challenge: RBAC test 1 failed. `analyst_role` could read `avenoirel_prod.raw.reservations`.
- Root cause: the test user holds every role and secondary roles were `ALL`, so the privileges of `prod_role` were active in the session. `SELECT CURRENT_ROLE(), CURRENT_SECONDARY_ROLES()` showed it.
- Fix: `USE SECONDARY ROLES NONE` after every `USE ROLE` in every test, and in the smoke test. The user default was left unchanged (D29).
- Learning: test one role alone, and pair every "must fail" query with a positive control.

### 12.2 `--target prod` would have read dev data
- Challenge: before building prod, the sources were found to read their database from an environment variable, which pointed at dev.
- Root cause: two places decided the database, the profile and an environment variable.
- Fix: sources read `target.database` (D21).
- Learning: one source of truth per environment. Check where a build reads before checking where it writes.

### 12.3 ACCOUNTADMIN could not see a schema
- Challenge: "does not exist or not authorized" for a schema that existed.
- Root cause: objects owned by `dev_role` are invisible to `ACCOUNTADMIN`, and Snowflake gives the same error for a missing object and a missing privilege.
- Fix: run each script under the role that should own the object.
- Learning: read the role named in the error text before suspecting the grants.

### 12.4 Success on the last line was not proof
- Challenge: Snowsight "Run all" shows only the last statement, and "Successful" says nothing about the earlier ones.
- Fix: every step was checked with a `SHOW` query, a count or a diff.
- Learning: verify with output, never with a success message.

### 12.5 A loader that said success while skipping tables
- Challenge: the loader printed SKIP for a missing CSV and still ended with "All tables loaded successfully".
- Root cause: failures were printed, not raised.
- Fix: the loader now checks all CSVs before connecting and exits with code 1 on a missing file or a failed table.
- Learning: a script must fail loudly. Check row counts after every load.

### 12.6 Writing the runbook from zero found a hole
- Challenge: script 01 never granted the roles to any user. In the old account the grants had been made by hand, so a new account would have failed at the first load as `dev_role`.
- Fix: script 01 grants the three roles to `CURRENT_USER()`.
- Learning: a rebuild is only proven when someone follows the steps from nothing.

### 12.7 `requirements.txt` was not the local environment
- Challenge: the root file is for CI and Astro (dbt 1.9.5) and lacks pandas, python-dotenv, Faker and PyYAML, while the local venv runs dbt 1.8.8.
- Fix: `requirements-local.txt`, proven in a fresh venv. The root file was left alone so CI cannot break.
- Learning: pin what you verified with. The difference between CI and local is still open.

### 12.8 The first live run of the runner failed
- Challenge: the load step failed with `Schema 'AVENOIREL_DEV."raw"' does not exist`.
- Root cause: the loader quotes identifiers, so the schema must be upper case `RAW`.
- Fix: `RAW` in the runner and the runbook. Nothing changed in Snowflake because it failed before the first table.
- Learning: run a rebuild kit once on the live account before the real migration, where the same failure would cost far more.

### 12.9 The test tool needed its own test
- Challenge: the first smoke test run crashed. The rest of a test part's header comment was sent to Snowflake as SQL.
- Fix: skip the header line of each part.
- Learning: run a new test tool once for real before trusting "All checks passed".

### 12.10 Warehouse guards were missing
- Challenge: the trial warehouse had query acceleration on and no resource monitor.
- Fix: bootstrap script 00 turns acceleration off and attaches a 20 credit monitor (D23).
- Learning: put cost guards in the setup script, not in memory.

