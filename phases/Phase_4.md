# Phase 4 -- Orchestration
**Status:** Complete
**Date:** November 2026
**Branch:** phase/4-orchestration (merged to main)

---

## What We Did

Built the full orchestration layer for AVENOIREL -- three Airflow DAGs using Astronomer Cosmos pattern, plus a two-workflow CI/CD pipeline (ci.yml + deploy.yml) using GitHub Actions.

**DAGs created:**

| DAG | Schedule | Domain | Models |
|---|---|---|---|
| `revenue_hotel_daily` | Daily at 06:00 UTC | revenue | `tag:revenue` |
| `loyalty_tier_weekly` | Weekly Monday 06:00 UTC | loyalty | `tag:loyalty` |
| `ops_bookings_hourly` | Every hour | operations | `tag:operations` |

**CI/CD workflows:**

| Workflow | Trigger | Purpose |
|---|---|---|
| `ci.yml` | PR to main | SQLFluff lint + dbt parse + dbt build (Slim CI) |
| `deploy.yml` | Push to main | Full dbt build + dbt docs generate + manifest artifact upload |

---

## Why We Did It

Without orchestration, dbt models had to be run manually. No schedule, no retry logic, no source freshness checks, no visibility into what ran and when.

Airflow + Cosmos gives:
- Scheduled execution per domain -- revenue daily, loyalty weekly, operations hourly
- Task-level visibility -- each dbt model becomes an Airflow task with its own status
- Retry logic -- 3 retries with 5-minute delay on failure
- Source freshness gate -- runs before dbt models, fails fast if data is stale

CI/CD gives:
- Quality gate on every PR -- no broken code reaches main
- Automated production build on merge -- manifest always up to date
- Slim CI -- only changed models tested on PR, not full rebuild every time

---

## How It Works

### Cosmos DAG Pattern

Each DAG follows the same structure:

```
source_freshness (BashOperator) >> dbt_[domain] (DbtTaskGroup)
```

`DbtTaskGroup` reads the dbt project, finds all models tagged with the domain tag, and generates one Airflow task per model automatically. No manual task definition needed.

```python
dbt_revenue = DbtTaskGroup(
    group_id="revenue_models",
    project_config=ProjectConfig(dbt_project_path="/usr/local/airflow/dags/dbt"),
    profile_config=profile_config,
    render_config=RenderConfig(select=["tag:revenue"]),
)
```

**Why `dags/dbt/` nesting?** Airflow scans the `dags/` folder for DAG files. By nesting the dbt project under `dags/dbt/`, Cosmos can find the project and DAG Python files coexist in the same repo. One repo, one deploy.

### Mandatory DAG Tags

Every DAG has three required tags:

```python
tags=["owner:sachin", "domain:revenue", "criticality:high"]
```

These tags enable filtering in Airflow UI -- find all revenue DAGs, all high-criticality DAGs, all DAGs owned by a specific engineer.

### DAG Naming Convention

```
[domain]_[subdomain]_[frequency]

revenue_hotel_daily
loyalty_tier_weekly
ops_bookings_hourly
```

### CI/CD -- Two-Workflow Design

**ci.yml** (PR gate):
```
Checkout -> Install deps -> SQLFluff lint (non-blocking) -> Create profiles.yml
-> dbt deps -> dbt parse -> Download prod manifest -> dbt build (Slim CI or full)
```

**deploy.yml** (production build):
```
Checkout -> Install deps -> Create profiles.yml -> dbt deps
-> dbt build (full) -> dbt docs generate -> Upload manifest artifact
```

### Slim CI Loop

The two workflows feed each other:

```
PR open    --> ci.yml     --> download prod-manifest --> build changed models only
PR merge   --> deploy.yml --> full build             --> upload prod-manifest
Next PR    --> ci.yml     --> download prod-manifest --> build changed models only
```

First run has no manifest -- ci.yml falls back to full build. Every subsequent PR uses Slim CI.

```bash
if [ -f prod_manifest/manifest.json ]; then
  dbt build --select state:modified+ --defer --state prod_manifest/ ...
else
  dbt build ...
fi
```

### profiles.yml -- Runtime Generation

profiles.yml is never committed to Git (contains credentials). Both ci.yml and deploy.yml generate it at runtime from GitHub Secrets:

```yaml
- name: Create dbt profiles.yml
  run: |
    cat > dags/dbt/profiles.yml << EOF
    avenoirel:
      target: dev
      outputs:
        dev:
          type: snowflake
          account: ${{ secrets.SNOWFLAKE_ACCOUNT }}
          ...
    EOF
```

---

## Key Decisions

**1. DbtTaskGroup over DbtDag**
Blueprint showed `DbtDag` pattern. Switched to `DbtTaskGroup` to allow a `source_freshness` task before dbt models run. `DbtDag` does not support pre-tasks; `DbtTaskGroup` sits inside a regular DAG and allows full task dependency control.

**2. SQLFluff continue-on-error: true**
SQLFluff lint step is non-blocking in CI. Real violations exist (CP01, LT08, LT12, LT14) -- these will be fixed in Phase 8 when SQLFluff cleanup is done properly. Blocking CI on style violations before they are fixed would prevent all merges.

**3. Astronomer deploy -- documented, not executed**
deploy.yml was written for Astronomer Cloud (`astro deploy --dags`). Astronomer trial requires a paid account. The deploy step is commented out with explanation. The dbt build + manifest upload portion works fully -- this is what enables Slim CI. Portfolio constraint documented explicitly.

**4. target: dev in DAG profile_config**
DAGs connect to `dev` target. In a production Astronomer deployment, this would be `prod`. Since we are not deploying to Astronomer, keeping `dev` avoids accidental prod writes during local testing.

---

## Tradeoffs

| Tradeoff | Decision | Reason |
|---|---|---|
| DbtTaskGroup vs DbtDag | DbtTaskGroup | Allows source_freshness pre-task |
| SQLFluff blocking vs non-blocking | Non-blocking (continue-on-error) | Violations exist -- fix in Phase 8, not Phase 4 |
| Astronomer deploy executed vs documented | Documented only | Paid product -- portfolio constraint |
| Full build on deploy vs Slim CI on deploy | Full build | deploy.yml is production build -- always rebuild everything. Slim CI is for PRs only |

---

## Blockers We Solved

**1. schedule_interval deprecated in Airflow 3.x**
- DAGs initially used `schedule_interval="0 6 * * *"`
- Airflow 3.x renamed this to `schedule`
- Fix: replaced all `schedule_interval` with `schedule`
- Learning: Airflow 3.x has breaking changes from 2.x -- check release notes when upgrading

**2. Docker Desktop not running**
- `astro dev start` failed -- Docker not running
- Fix: start Docker Desktop before any local Airflow commands
- Learning: Astronomer CLI requires Docker -- document this in environment setup

**3. Source freshness _loaded_at field mismatch**
- `dbt source freshness` failed -- `_loaded_at` column not found in raw tables
- The `loaded_at_field` in sources.yml and the load timestamp column in the raw tables did not have the same name
- Fix: aligned sources.yml and the raw tables on one column name. Verified in Phase 4.5: all 10 raw tables have `_loaded_at` and sources.yml uses `_loaded_at`
- Learning: sources.yml `loaded_at_field` must match exact column name in raw table

**4. operator_args select syntax error**
- Initial DAG used `operator_args={"select": "tag:revenue"}` -- incorrect
- Cosmos does not accept select via operator_args for DbtTaskGroup
- Fix: moved to `RenderConfig(select=["tag:revenue"])` -- correct Cosmos API
- Learning: Cosmos select filtering goes in RenderConfig, not operator_args

**5. dim_loyalty_tier duplicate key error**
- `dbt seed` run twice on same environment -- duplicate primary keys in dim_loyalty_tier
- Fix: `dbt seed --full-refresh` to drop and recreate seed tables
- Learning: always use `--full-refresh` on seeds when re-running in same environment

**6. --profiles-dir missing in BashOperator bash_command**
- `source_freshness` BashOperator ran `dbt source freshness --project-dir ...` only
- Failed with "Could not find profile named avenoirel"
- Fix: added `--profiles-dir /usr/local/airflow/dags/dbt` to bash_command
- Learning: every dbt CLI command needs both `--project-dir` and `--profiles-dir` when profiles.yml is not in default location

---

## Challenges

### Challenge 1: schedule_interval renamed in Airflow 3.x

**What Challenge:** DAGs failed to parse -- `schedule_interval` not recognised

**Root Cause:** Airflow 3.x removed `schedule_interval` parameter. Renamed to `schedule` in Airflow 2.4+ and removed entirely in 3.x. Astronomer Cosmos 1.x ships with Airflow 3.x.

**Fix:** Replaced `schedule_interval` with `schedule` in all three DAGs

**Learning:** Always check Airflow version compatibility when copying DAG patterns from older documentation. Airflow 3.x has several breaking changes from 2.x.

---

### Challenge 2: Docker not running -- astro dev start failed

**What Challenge:** `astro dev start` failed immediately with connection error

**Root Cause:** Docker Desktop was not running. Astronomer CLI uses Docker to spin up local Airflow containers.

**Fix:** Start Docker Desktop before any `astro dev` commands

**Learning:** Astronomer local development requires Docker Desktop running. Add this to environment setup documentation.

---

### Challenge 3: Source freshness _loaded_at field mismatch

**What Challenge:** `dbt source freshness` failed -- column `_loaded_at` not found

**Root Cause:** the `loaded_at_field` in sources.yml and the load timestamp column in the raw tables did not have the same name, so the freshness check could not find the column.

**Fix:** Aligned sources.yml and the raw tables on one column name. Verified in Phase 4.5: all 10 raw tables have `_loaded_at` and sources.yml uses `_loaded_at`.

**Learning:** `loaded_at_field` in sources.yml must exactly match the column name in the raw table. No assumptions -- always check the raw table schema first.

---

### Challenge 4: RenderConfig vs operator_args for Cosmos select

**What Challenge:** DAG not filtering models by tag -- all models ran instead of domain-specific ones

**Root Cause:** Used `operator_args={"select": "tag:revenue"}` which is not the correct Cosmos API for filtering models in DbtTaskGroup

**Fix:** Moved filtering to `RenderConfig(select=["tag:revenue"])` -- the correct Cosmos pattern

**Learning:** Cosmos has specific APIs for each concern. Model selection goes in `RenderConfig`. Profile configuration goes in `ProfileConfig`. Do not pass dbt CLI flags through `operator_args` for things Cosmos has native support for.

---

### Challenge 5: dim_loyalty_tier duplicate keys from double seed run

**What Challenge:** dbt seed failed with duplicate primary key error on dim_loyalty_tier

**Root Cause:** `dbt seed` run twice in same environment without full refresh. Second run tried to insert same records -- primary key violation.

**Fix:** `dbt seed --full-refresh` drops and recreates seed tables before inserting

**Learning:** In development, always use `--full-refresh` on seeds. In production, seeds are run once and rarely changed -- but `--full-refresh` is still the safe option when re-running.

---

### Challenge 6: --profiles-dir missing in BashOperator

**What Challenge:** source_freshness task failed -- "Could not find profile named avenoirel"

**Root Cause:** BashOperator bash_command had `--project-dir` but not `--profiles-dir`. dbt looked for profiles.yml in default location (`~/.dbt/`) which does not exist in Airflow container.

**Fix:** Added `--profiles-dir /usr/local/airflow/dags/dbt` to bash_command

**Learning:** Every dbt CLI command needs both flags when profiles.yml is in a non-default location. `--project-dir` alone is not enough.

---

### Challenge 7: sqlfluff not in requirements.txt -- CI exit 127

**What Challenge:** CI failed at SQLFluff lint step -- `sqlfluff: command not found` (exit code 127)

**Root Cause:** requirements.txt did not include sqlfluff. pip install step ran successfully but sqlfluff was never installed.

**Fix:** Added `sqlfluff==3.3.1` and `sqlfluff-templater-dbt==3.3.1` to requirements.txt

**Learning:** Every CLI tool used in CI must be in requirements.txt. Never assume a tool is pre-installed on GitHub Actions ubuntu-latest runner.

---

### Challenge 8: SQLFluff dbt templater requires profiles.yml

**What Challenge:** SQLFluff lint failed -- "dbt_profiles_dir could not be accessed"

**Root Cause:** `.sqlfluff` had `templater = dbt` which requires a live dbt connection (profiles.yml) to render Jinja. profiles.yml does not exist in CI at lint time.

**Fix:** Changed to `templater = jinja` with `apply_dbt_builtins = true`. Jinja templater does not need a live dbt connection -- handles dbt-specific Jinja builtins without connecting to Snowflake.

**Learning:** `dbt` templater is for local development where profiles.yml exists. `jinja` templater is for CI where no connection is available. Use jinja in CI.

---

### Challenge 9: profiles.yml not committed -- dbt parse fails in CI

**What Challenge:** CI failed at dbt parse -- "Could not find profile named avenoirel"

**Root Cause:** profiles.yml is gitignored (contains credentials). CI runner has no profiles.yml after checkout.

**Fix:** Generate profiles.yml at runtime in CI using GitHub Secrets. Added a "Create dbt profiles.yml" step that writes the file from secrets before any dbt command.

**Learning:** profiles.yml must never be committed. Runtime generation from secrets is the production pattern. Same pattern applied to both ci.yml and deploy.yml.

---

### Challenge 10: dbt deps added after dbt parse -- wrong order

**What Challenge:** CI failed -- "dbt found 1 package but 0 installed"

**Root Cause:** `dbt deps` step was added to ci.yml after `dbt parse`. dbt parse runs first, finds packages.yml, checks dbt_packages/ folder -- empty. Fails before deps can install.

**Fix:** Moved `dbt deps` step to run before `dbt parse`

**Learning:** Step order in CI matters. deps before parse before build -- always. deps installs packages, parse validates project (including packages), build executes.

---

### Challenge 11: Slim CI fails first run -- no prod manifest

**What Challenge:** CI failed -- "Got a state selector method but no comparison manifest"

**Root Cause:** First run of Slim CI has no prod manifest to compare against. `--select state:modified+` requires a manifest.json from a previous prod run.

**Fix:** Bash conditional -- if manifest.json exists use Slim CI, else full build:
```bash
if [ -f prod_manifest/manifest.json ]; then
  dbt build --select state:modified+ --defer --state prod_manifest/ ...
else
  dbt build ...
fi
```

**Learning:** Slim CI requires a chicken-and-egg bootstrap. First run is always full build. After first deploy.yml run saves the manifest, all subsequent CI runs use Slim CI.

---

### Challenge 12: deploy.yml profiles.yml missing

**What Challenge:** deploy.yml failed -- "Could not find profile named avenoirel"

**Root Cause:** Same as ci.yml Challenge 9 -- profiles.yml not committed, deploy.yml had no step to generate it at runtime.

**Fix:** Added "Create dbt profiles.yml" step to deploy.yml, identical to ci.yml step but with `target: prod`

**Learning:** Every workflow that runs dbt commands needs its own profiles.yml generation step. CI and CD are independent runners -- they do not share files.

---

### Challenge 13: deploy.yml dbt deps missing

**What Challenge:** deploy.yml failed -- "dbt found 1 package but 0 installed"

**Root Cause:** `dbt deps` step was not in deploy.yml. Same packages issue as ci.yml Challenge 10 but on the deploy workflow.

**Fix:** Added `dbt deps` step after profiles.yml generation and before `dbt build`

**Learning:** Every workflow that runs dbt must install packages first. deps step is not optional -- it is required whenever dbt_packages/ is not committed (which it should not be, per .gitignore).
