# Phase 2 — Intermediate Layer
**Status:** Complete  
**Date:** October 2026  
**Branch:** phase/2-intermediate

---

## What We Did

Built 7 intermediate models transforming staging data into business-ready analytics — joining tables, applying business rules, and calculating KPIs that marts layer will consume directly.

| Model | Description |
|---|---|
| `int_revenue_by_property_daily` | RevPAR, ADR, Occupancy per property per room type per date |
| `int_booking_cancellation_signals` | Cancellations enriched with booking details and last-minute flag |
| `int_loyalty_tier_movement` | Tier change history with LAG, LEAD, ROW_NUMBER window functions |
| `int_loyalty_points_validated` | Points transactions validated against checkout dates — M9 detection |
| `int_stay_duration_metrics` | ALOS, lead time, running revenue, booking rank, NTILE quartiles |
| `int_booking_channel_enriched` | Rate code enrichment from seed, guest channel shift analysis |
| `int_booking_payment_reconciliation` | Expected vs actual payment reconciliation with PERCENT_RANK, CUME_DIST |

---

## Why We Did It

Staging layer gave us clean, typed, consistently named data. But staging models have no business logic — they are 1:1 with source tables. Intermediate layer is where the real analytics engineering work happens:

- **Joins** — combining multiple staging tables that belong together
- **Business rules** — which booking statuses count as "rooms sold", what tolerance is acceptable for payment mismatch
- **KPI calculations** — RevPAR, ADR, Occupancy formulae
- **Window functions** — metrics that require context of other rows (running totals, rankings, tier history)

Without intermediate models, marts would need to re-implement this logic repeatedly. Intermediate layer ensures logic is written once, tested once, and reused everywhere.

**Real world equivalent:** In a real hotel group, this is the work of the Analytics Engineering team — transforming raw Opera data into metrics that Revenue Managers, Finance, and Loyalty teams can actually use.

---

## How It Works

### Materialization — View in Dev, Ephemeral in Prod

All intermediate models are materialised as **views** in dev environment for easy debugging and testing. In production, they would be **ephemeral** — compiled as CTEs inside downstream models, leaving no objects in Snowflake. This saves storage and credits.

```yaml
# dbt_project.yml
intermediate:
  +schema: intermediate
  +materialized: view  # dev only — prod would be ephemeral
```

### CTE Pattern — Every Model Follows This

```sql
WITH source_1 AS (
    SELECT * FROM {{ ref('staging_model') }}  -- source CTEs only
),
source_2 AS (
    SELECT * FROM {{ ref('another_model') }}
),
joined AS (
    -- JOINs happen here, no calculations
),
aggregated AS (
    -- GROUP BY, COUNT, SUM happen here
),
final AS (
    -- Derived columns, window functions, CASE statements
    SELECT * FROM aggregated
)

SELECT * FROM final
```

**Rules:**
- `ref()` only — never `source()` in intermediate
- Each CTE does one thing
- `final` is always the last CTE
- `SELECT * FROM final` is always the last line

### dbt_utils Package

`unique_combination_of_columns` test requires `dbt_utils` package — not built into dbt core.

```yaml
# packages.yml
packages:
  - package: dbt-labs/dbt_utils
    version: 1.4.1
```

Install with `dbt deps`.

### Window Functions Used

| Function | Model | Purpose |
|---|---|---|
| `LAG()` | int_loyalty_tier_movement | Previous tier change date |
| `LEAD()` | int_loyalty_tier_movement | Next tier member will reach |
| `ROW_NUMBER()` | int_loyalty_tier_movement | Latest tier record flag |
| `AVG() OVER` | int_stay_duration_metrics | ALOS by property and brand |
| `SUM() OVER` | int_stay_duration_metrics | Running revenue per guest |
| `RANK()` | int_stay_duration_metrics | Booking value rank within property |
| `NTILE(4)` | int_stay_duration_metrics | Lead time quartile |
| `FIRST_VALUE()` | int_booking_channel_enriched | Guest first booking channel |
| `COUNT() OVER` | int_booking_channel_enriched | Total bookings per guest |
| `PERCENT_RANK()` | int_booking_payment_reconciliation | Payment gap percentile |
| `CUME_DIST()` | int_booking_payment_reconciliation | Cumulative distribution for audit |

### Snowflake-Specific Features Used

**Boolean window expression** — Snowflake allows this directly, SQL Server does not:
```sql
ROW_NUMBER() OVER (PARTITION BY member_number ORDER BY effective_date DESC) = 1 AS is_latest_record
```
In SQL Server, this would require a CTE with the window function first, then CASE WHEN in the next CTE.

**QUALIFY** — Snowflake specific — filter on window function result without subquery:
```sql
QUALIFY ROW_NUMBER() OVER (PARTITION BY member_number ORDER BY effective_date DESC) = 1
```

---

## Key Decisions

| Decision | Reason |
|---|---|
| View materialization in dev | Ephemeral models cannot be directly queried or tested — views allow debugging |
| LEFT JOIN for reservations on availability | Dates with zero bookings must appear — rooms_sold = 0 is valid data for RevPAR |
| Booking statuses for rooms_sold: CHECKED_IN, CHECKED_OUT, NO_SHOW | NO_SHOW rooms were committed — hotel could not resell them — industry standard |
| €1 tolerance for payment mismatch | FX rounding creates sub-€1 gaps — these are not real mismatches |
| Static FX rates for EUR conversion | Portfolio context — production would use dim_exchange_rates with date-specific rates |
| COALESCE(SUM(amount_eur), 0) for room revenue | Dates with no bookings return NULL from LEFT JOIN — zero revenue is correct |
| Granular channel_shift values | SHIFTED is not enough — OTA_TO_DIRECT vs DIRECT_TO_OTA tell different stories for Revenue Management |
| severity: warn for M10 range tests | rooms_available = -1 is deliberate messiness — should warn not block pipeline |

---

## Test Plan — int_revenue_by_property_daily

| Column | Tests |
|---|---|
| `property_code` + `room_type_id` + `stay_date` | `unique_combination_of_columns` — dbt_utils |
| `property_code` | `not_null`, `relationships → stg_hotel_properties` |
| `room_type_id` | `not_null`, `relationships → stg_hotel_room_types` |
| `stay_date` | `not_null` |
| `rooms_available` | `not_null`, range `>= 0` (severity: warn — M10) |
| `rooms_sold` | `not_null`, range `>= 0` |
| `room_revenue_eur` | `not_null`, range `>= 0` |
| `occupancy_rate` | range `>= 0 AND <= 1` (severity: warn — M10 effect) |
| `revpar_eur` | range `>= 0` (severity: warn — M10 effect) |

---

## SQL Journey — Key Learnings Per Model

### int_revenue_by_property_daily

**Challenge: Spine selection**
Tumne pehle `stg_hotel_properties` ko spine banaya. Correct spine `stg_ops_room_availability` hai — kyunki har date ki row wahan pehle se hai. Properties ko join karna optional enrichment tha, core data nahi.

**Challenge: Cartesian product**
Pehle sirf `property_code` pe join kiya — `room_type_id` aur `stay_date` missing the. Ek room type ki availability row se property ki saari reservations match ho rahi thi — wrong data.
Fix: `AND a.room_type_id = r.room_type_id AND r.check_in_date <= a.stay_date AND r.check_out_date > a.stay_date`

**Challenge: INNER JOIN vs LEFT JOIN**
INNER JOIN use kiya tha — dates jahan koi booking nahi thi woh rows result se gayab ho gayi. RevPAR ke liye zero-booking dates zaroori hain — denominator mein woh rooms count hote hain.
Fix: LEFT JOIN on reservations with booking_status filter in ON clause, not WHERE clause.

**Challenge: WHERE clause kills LEFT JOIN**
`WHERE booking_status IN (...)` lagaya tha LEFT JOIN ke baad — NULL rows filter out ho gayi. Booking status filter ON clause mein daala.

**Challenge: rooms_sold calculation**
`total_rooms - ooo_rooms - rooms_available` try kiya — hamesha 0 aata. `rooms_available` pehle se `total_rooms - ooo_rooms` hai.
Fix: `COUNT(booking_status)` from reservations join.

---

### int_loyalty_tier_movement

**Challenge: SQLFluff ne CASE WHEN ko COALESCE mein convert kiya**
`sqlfluff fix` ne automatically `CASE WHEN rn = 1 THEN TRUE ELSE FALSE` ko `COALESCE(rn = 1, FALSE)` mein rewrite kar diya — Snowflake mein COALESCE ke andar boolean expression invalid hai. Manually revert kiya.
Learning: `sqlfluff fix` blindly trust mat karo — especially window function expressions pe.

**Challenge: Alias scope in CTEs**
`result` CTE mein `h.history_id` likha tha — `h` alias sirf original query mein valid tha, CTE ke baad nahi. CTE mein column names bina alias ke use karo.

---

### int_loyalty_points_validated

**Challenge: INNER JOIN removes non-STAY transactions**
DINING aur PARTNER transactions ka `confirmation_number` reservations mein nahi hoga. INNER JOIN se yeh rows gayab ho jaati.
Fix: LEFT JOIN with NULL check in `is_valid_transaction` CASE.

---

### int_stay_duration_metrics

**Challenge: GROUP BY se avg_los galat tha**
`AVG(nights) GROUP BY property_code` try kiya — har row ka apna average aata. Window function chahiye tha.
Fix: `AVG(nights) OVER (PARTITION BY property_code)`

**Challenge: running_revenue_by_guest mein ORDER BY missing**
`SUM() OVER (PARTITION BY guest_profile_id)` bina ORDER BY ke running total nahi deta — sirf total deta hai. ORDER BY booking_date zaroori hai.

---

### int_booking_channel_enriched

**Challenge: Same SELECT mein window function result reference**
`channel_shift` CASE mein `first_booking_channel` use kiya — lekin woh same SELECT mein define ho raha tha. SQL mein same SELECT ke columns reference nahi kar sakte.
Fix: Alag CTE banaya — `joined` mein window functions, `enriched` mein `channel_shift`.

---

### int_booking_payment_reconciliation

**Challenge: FX conversion**
`total_cost` local currency mein hai — EUR mein convert karna tha. Production mein `dim_exchange_rates` table hoti hai date-specific rates ke saath. Portfolio mein static CASE WHEN use kiya.

**Challenge: ABS missing in mismatch flag**
`amount - cost <= 1` check kiya tha — negative gap (-5) bhi pass ho jaata. `ABS()` zaroori tha.

**Challenge: total_paid NULL for non-stayed reservations**
CONFIRMED aur CANCELLED reservations ke folios nahi hote — `SUM(amount_eur)` NULL return karta. `COALESCE` nahi lagaya yahan kyunki NULL meaningful hai — yeh reservations actually paid nahi huin.

---

## Challenges

### Challenge 1 — SQLFluff Rewrites Window Functions Incorrectly
**Situation:** Running sqlfluff fix on int_loyalty_tier_movement.sql  
**Problem:** SQLFluff converted `CASE WHEN rn = 1 THEN TRUE ELSE FALSE END` to `COALESCE(rn = 1, FALSE)` — invalid Snowflake syntax  
**Options Considered:** Disable rule, manually revert, add noqa comment  
**Decision:** Manually reverted — kept original CASE WHEN syntax  
**Result:** Model ran successfully  
**Learning:** sqlfluff fix is not always safe on window function expressions — review changes before committing

### Challenge 2 — Intermediate Models Felt Too Simple
**Situation:** Building models 2.2 through 2.4  
**Problem:** Generator pre-computed many fields (has_early_points, change_type, reason_group) that would normally be derived in intermediate layer from raw events  
**Decision:** Accepted this as portfolio tradeoff — added advanced window functions (NTILE, CUME_DIST, PERCENT_RANK, FIRST_VALUE) to compensate  
**Learning:** Next project — generate truly raw events, derive all business fields in dbt

### Challenge 3 — Snowflake Boolean Expression in SELECT
**Situation:** Writing is_first_booking column  
**Problem:** Unsure if `ROW_NUMBER() OVER (...) = 1` directly returns boolean in Snowflake  
**Result:** Yes — Snowflake allows boolean expressions directly in SELECT. SQL Server requires CASE WHEN wrapper. This is a Snowflake-specific feature worth documenting.

### Challenge 4 — Resource Monitor Quota Exceeded
**Situation:** Mid-session during Step 2.5  
**Problem:** Snowflake trial resource monitor blocked warehouse resume despite $393 of $400 credits remaining  
**Fix:** ALTER RESOURCE MONITOR to increase quota  
**Learning:** Resource monitors are separate from credit balance — set them on Day 1 to avoid interruption