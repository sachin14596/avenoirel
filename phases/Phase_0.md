# Phase 0 — Foundation
**Status:** Complete  
**Date:** September 2026

---

## What We Did

Built the complete data foundation for AVENOIREL from scratch.

- Designed domain model — 10 entities based on real Opera PMS structure
- Built Python data generator — 60,000 reservations, 10 tables
- Generated clean data — all 5 validation queries passed
- Injected deliberate messiness — 11 problem types with ground truth flags
- Locked schema — docs/schema_lock.md committed
- Loaded raw data into Snowflake avenoirel_dev.raw

---

## Key Decisions

| Decision | Reason |
|---|---|
| Opera-grounded data model | Real field names, rate codes, cancellation reasons from Opera |
| generator_config.yaml | Configuration as code — scale and messiness params separate from logic |
| Clean data validated before messiness | Fenzo Bank lesson — validate foundation before building |
| 11 deliberate messiness types | Each has ground truth flag — dbt detection accuracy measurable |
| pandas + snowflake-connector for load | Simple, reliable, no extra tooling needed |
| Same day booking allowed | VQ4 fix — check_in_date >= booking_date is valid in Opera |

---

## Data Scale

| Table | Rows |
|---|---|
| properties | 50 |
| room_types | 305 |
| guests | 45,000 |
| avenir_members | 29,173 |
| reservations | 60,300 (incl. 300 duplicates) |
| folios | 78,241 |
| cancellations | 14,034 |
| room_availability | 334,280 |
| avenir_points_transactions | 30,343 |
| avenir_tier_history | 45,190 |

---

## Challenges

### Challenge 1 — VQ4 Same Day Booking
**Situation:** Running validation on 100 rows  
**Problem:** 10 violations in VQ4 — check_in_date == booking_date flagged as error  
**Options Considered:** Fix generator to enforce lead_days >= 1, or fix validation logic  
**Decision:** Fixed validation query — same day booking is valid in Opera (walk-in guests)  
**Result:** VQ4 passed with 0 violations  
**Learning:** Business rules must reflect real-world operations — Opera allows same-day bookings

### Challenge 2 — Snowflake DEV_ROLE Permissions
**Situation:** Running load_to_snowflake.py  
**Problem:** DEV_ROLE had no CREATE TABLE permission on raw schema  
**Options Considered:** Use ACCOUNTADMIN for loading, or grant proper permissions  
**Decision:** Granted CREATE TABLE and CREATE STAGE to dev_role on raw schema  
**Result:** All 10 tables loaded successfully  
**Learning:** Snowflake RBAC requires explicit grants — USAGE alone is not enough for writes

### Challenge 3 — snowflake-connector pandas dependency
**Situation:** Running load_to_snowflake.py  
**Problem:** MissingDependencyError for pandas despite pandas being installed  
**Options Considered:** Downgrade connector, install pandas extra  
**Decision:** pip install snowflake-connector-python[pandas] — installed pyarrow  
**Result:** write_pandas worked correctly  
**Learning:** Snowflake connector needs pyarrow for pandas integration — always install with [pandas] extra