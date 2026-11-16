# Phase 4.5 - Hardening

**Branch:** phase/4.5-hardening | **Date:** 2026-11-16 | **Status:** DONE

## What

Closed the exit-criteria debt of Phases 0 to 3 before governance work. Steps H1 to H7 of the blueprint were completed. Writing the unit tests exposed three real bugs in the revenue KPIs, which were fixed test-first.

| Step | Result |
|---|---|
| H1 Repo hygiene | 27 deprecated `tests:` keys renamed to `data_tests:` (loyalty 11, operations 16), `dbt parse` has 0 warnings. 3 merged branches deleted. `main` protected by a ruleset |
| H2 Unit tests | 9 unit tests on `int_revenue_by_property_daily` (5) and `int_stay_duration_metrics` (4). 3 bugs fixed. Unit tests excluded from `deploy.yml` |
| H3 Reconciliation | 4 singular tests: 2 error level, 2 warn level (known data issues) |
| H4 Contracts | Enforced on dim_date, dim_property, fct_revpar_daily, fct_adr_daily, fct_bookings, fct_occupancy_daily. Negative test confirmed enforcement |
| H5 Occupancy | `occupancy_rate` between 0 and 1 is an error at property grain, with `store_failures` |
| H6 Money types | Decision: keep FLOAT, documented as a tradeoff (see Key Decisions) |
| H7 Tooling | pre-commit hook false positives fixed, `.gitattributes` added, Phase_4.md Challenge 3 corrected |

Final state: `dbt build` PASS=370, WARN=2, ERROR=0 (329 data tests, 9 unit tests).

## Why

Phase 5 (governance) and Phases 6 and 7 (RAG assistant, semantic layer) read from the marts. A wrong KPI would have been repeated confidently by an assistant built on top. The base had to be verified first.

## KPI impact of the fixes

| Metric | Before | After | Source of truth |
|---|---|---|---|
| Sold room-nights | 577,723 | 93,119 | 94,493 staged, of which 1,374 nights fall outside the availability calendar (2022-01-01 to 2024-12-31) |
| Room revenue (EUR) | 249.2M | 12.80M | 13.05M staged, same calendar effect |
| Occupancy range | -19 to 11.42 | 0 to 0.53 | n/a |
| Minimum available rooms | negative | 22 | n/a |

The two warn tests that were accepted as a "synthetic data limitation" in Phase 3 disappeared after the fix. They were symptoms of the model bugs, not of the data.

## Key Decisions

| # | Decision | Reason |
|---|---|---|
| H2-a | Property rooms = SUM of room type inventory per date (total minus out of order) | The calendar is the sellable inventory and out of order rooms are recorded per room type. The property master `total_rooms` differs for 45 of 50 properties |
| H2-b | A stay's room folio is spread evenly across its nights (amount / nights) `[AVENOIREL]` | RevPAR and ADR are per night metrics. The synthetic data holds one ROOM line per stay, so the even spread simulates nightly posting |
| H2-c | Test first: write failing unit tests, then fix the model | Proves each bug and prevents regressions |
| H2-d | ADR is NULL when no rooms are sold, rooms sold and revenue stay 0 | ADR is a ratio, 0/0 is undefined. A 0 would pull any later average down |
| H2-e | ALOS excludes CANCELLED bookings, test records and duplicates. The rows stay in the model | A cancelled booking never became a stay. Downstream marts still need the rows |
| H3-a | KPI models exclude reservations flagged `is_test_record` or `is_duplicate_reservation` (M7, M6). Flags are COALESCEd to FALSE | Accepted tradeoff: the flags are generator ground truth. Production would detect these cases with logic |
| H3-b | Reconciliation scope = CHECKED_IN, CHECKED_OUT, NO_SHOW, clean rows, inside the availability calendar. Tolerance EUR 1 for revenue | Same business rule as the KPI models |
| H4 | Contracts on the 6 marts Phase 7 consumes, key columns not_null. Types: varchar, number(p,s), date, boolean, float, timestamp_ltz | Contract spelling accepted by dbt-snowflake 1.8.4 and verified by a deliberate mismatch |
| H5 | Occupancy above 1 at property grain is an error | Overbooking is only valid at room type level. Old values of -19 to 11.42 were the fan-out bug |
| H6 | Money stays FLOAT in raw, staging and marts. Suffix standard `_eur` / `_local` unchanged (D6) | Tradeoff accepted for a synthetic portfolio dataset. Revenue reconciles within EUR 1. Follow-up in Phase 8: cast money to NUMBER(18,2) in staging, contracts will flag every mart column that changes |
| H7 | dbt-checkpoint `check-model-has-description` excludes macros, tests, snapshots and the pre-commit config | The hook only knows models. See Challenge 3 |

## Reconciliation rules (H3)

| Test | Level | Rule |
|---|---|---|
| assert_sold_room_nights_reconcile | error | Model sold room-nights equal clean staged room-nights inside the calendar |
| assert_room_revenue_reconciles | error | Model room revenue equals clean ROOM folio revenue spread per night, tolerance EUR 1 |
| assert_nights_match_stay_dates | warn | 86 sold reservations have a `nights` value that differs from check-out minus check-in (272 nights in total). Not fixed in staging |
| assert_property_rooms_match_inventory | warn | 45 of 50 properties have a master `total_rooms` that differs from the calendar inventory |

Duplicate flags: 225 sold reservations (494 nights) are duplicates and 130 sold reservations (300 nights) are test records. `confirmation_number` itself is unique in staging (60,300 rows, 60,300 distinct), so the M6 duplicates carry different confirmation numbers.

## Tradeoffs

- The M6 and M7 flags are generator ground truth. Using them in the models is a shortcut; a production pipeline would derive them.
- Money stays FLOAT (H6).
- Contract types are tied to the current build. A change of data type in a model now fails the build, which is the intent.
- CI and deploy still share one database secret, so the three environment story is not real yet. Resolved at Phase 5 kickoff (K2).

## Blockers

- None open. The pre-commit failures listed in Challenge 3 were resolved in this phase.

## Not done, moved on

- README rewrite and `tests/dags/test_dag_example.py` (Astro example test): Phase 8.
- SQLFluff cleanup and blocking lint in CI: Phase 8.
- Elementary: Phase 8 (D3).
- Money type change to NUMBER(18,2): Phase 8 candidate.

## Challenges

### Challenge 1: KPIs were 6x to 19x wrong while 325 data tests passed

**What Challenge:** While designing the first unit test for `int_revenue_by_property_daily`, the model read the availability table before it was rolled up. Room-nights were 577,723 against 94,493 real ones and revenue was 249.2M against 13.05M.

**Root Cause:** Three combined mistakes. (1) The availability table has 5 to 7 rows per property and date (one per room type) and every reservation joined to all of them. (2) `MAX(total_rooms)` was used as the property inventory, which is never right (0 matches in 54,800 property days). (3) The single ROOM folio line holds the whole stay, but it was booked on every night.

**Fix:** Roll availability up per property and date with SUM, divide each stay's room revenue by its nights, group by the availability keys. Written test first: 3 failing tests, then the fix, then 5 passing tests.

**Learning:** Data tests check the shape of the data, unit tests check the formula. Reconcile each layer to the source with a number. "Synthetic data" is not an explanation until the model is ruled out: the occupancy range of -19 to 11.42 and the 2 accepted warns were these bugs.

### Challenge 2: Test records and duplicate reservations counted as sold rooms

**What Challenge:** After the fan-out fix, 130 test records and 225 duplicates (about 0.84 percent of nights) still entered rooms sold, revenue and ALOS.

**Root Cause:** The models read all sold statuses and ignored the M6 and M7 ground truth flags.

**Fix:** Filter both flags with `COALESCE(flag, FALSE) = FALSE`. A plain `NOT flag` would drop rows whose flag is NULL, including every row of the earlier unit tests. One unit test per model.

**Learning:** NULL handling is part of the filter design. Decide explicitly which rows must reconcile before writing the reconciliation test.

### Challenge 3: pre-commit blocked commits, which had forced `--no-verify` in Phase 3

**What Challenge:** `check-model-has-description` failed on singular tests and then on `snap_hotel_properties.sql` although the snapshot has a description.

**Root Cause:** The hook definition runs on every staged yaml or sql file (`types_or: [yaml, sql]`) but only understands models. Staging a singular test, a snapshot properties file or `.pre-commit-config.yaml` made it report missing descriptions.

**Fix:** Excluded `macros`, `tests`, `snapshots` and `.pre-commit-config.yaml` from the hook. All later commits passed without `--no-verify`.

**Learning:** Read the hook definition in the pre-commit cache before guessing. Fix the hook configuration instead of bypassing the hook.

### Challenge 4: A replace-all ran in the wrong direction

**What Challenge:** The planned rename of 11 bare `tests:` keys in the loyalty schema showed 8 matches, and the pasted file showed 19 bare keys.

**Root Cause:** Find and replace were swapped, so the 8 correct `data_tests:` keys were turned into `tests:`.

**Fix:** The count mismatch was investigated before anything was committed. The file was rewritten with `data_tests:` everywhere, and `git diff --stat` was checked against the expected 27 changed lines plus 3 whitespace lines.

**Learning:** Count the matches before a replace-all and compare `git diff --stat` with the expected number.

### Challenge 5: Windows line endings can make dbt ignore tests

**What Challenge:** Git kept warning that LF would be replaced by CRLF in dbt yaml files.

**Root Cause:** `core.autocrlf` on Windows. CRLF in dbt yaml can silently drop tests.

**Fix:** Added `.gitattributes` with `eol=lf` for yml, yaml, sql, py, sh and md. The warning disappeared on the next commit. Unit test and data test counts were checked after each run.

**Learning:** Check the test count after every change to a yaml file.

### Challenge 6: dbt failed with a missing environment variable

**What Challenge:** `dbt parse` failed with `Env var required but not provided: SNOWFLAKE_ACCOUNT` although the virtualenv prompt was active.

**Root Cause:** The virtualenv was active but `activate.sh`, which also exports the Snowflake variables, had not been sourced in that terminal.

**Fix:** `source activate.sh` in a new terminal.

**Learning:** The `(.venv)` prompt does not prove that the environment variables are loaded.
