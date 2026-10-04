# Phase 1 — Staging Layer
**Status:** Complete  
**Date:** October 2026  
**Branch:** phase/1-staging

---

## What We Did

Built the complete staging layer for AVENOIREL — 10 models transforming raw Opera data into clean, typed, consistently named records ready for business logic in Phase 2.

- Registered 10 raw source tables via sources.yml
- Created 4 seed tables — brands, countries, rate_codes, cancellation_reasons
- Built generate_schema_name macro — fixed Snowflake schema naming
- Built 10 staging models — one per raw table
- Wrote 129 data tests across all models
- All SQLFluff checks passing
- dbt docs generated — manifest.json and catalog.json produced

---

## Why We Did It

Staging layer is the contract between raw data and business logic. Without it:
- Raw column names (PROPERTY_CODE uppercase) would bleed into business models
- Type mismatches would cause silent failures downstream
- Source changes would break every model instead of just staging

Every downstream model (intermediate, marts) references staging via ref() — never raw directly.

---

## How It Works

**Pattern for every staging model:**
```sql
WITH source AS (
    SELECT * FROM {{ source('avenoirel_raw', 'table_name') }}
),
renamed AS (
    SELECT
        column_name::TYPE AS column_name
    FROM source
    WHERE primary_key IS NOT NULL
)
SELECT * FROM renamed
```

Three things happen in staging:
1. Rename — raw uppercase columns to snake_case lowercase
2. Cast — explicit Snowflake :: casting for type safety
3. Filter — NULL primary keys removed

Nothing else. No joins, no calculations, no business logic.

**Seeds** — static reference data committed to Git, loaded via dbt seed:
- rate_codes — 55 Opera rate codes with channel, flexibility, breakfast flag
- cancellation_reasons — 41 Opera reason codes with reason group
- brands — 4 hotel brand definitions
- countries — 8 countries with currency and GDPR flag

**generate_schema_name macro** — overrides dbt default which appends target schema prefix (RAW_staging). With macro, custom schema name is used directly (staging).

---

## Key Decisions

| Decision | Reason |
|---|---|
| guest_ prefix on PII columns | title, email, phone, address are Snowflake reserved words — SQLFluff RF04 violation |
| data_tests not tests | dbt 1.8 renamed tests to data_tests — forward compatible |
| Python heredoc for schema.yml | Windows CRLF line endings caused dbt to silently ignore tests — LF required |
| Seeds in staging schema | Reference data belongs with staging layer, not raw |
| One schema.yml for all staging models | 10 models manageable in one file — easier cross-model review |

---

## Challenges

### Challenge 1 — Windows CRLF Line Endings in schema.yml
**Situation:** Writing schema.yml via VS Code on Windows  
**Problem:** VS Code saves YAML files with CRLF endings. dbt YAML parser silently ignores tests when CRLF present — no error, just "Nothing to do" on dbt test  
**Options Considered:** VS Code settings (read-only), .editorconfig, Python rewrite  
**Decision:** Python heredoc with newline='\n' — guaranteed LF endings on write  
**Result:** All 129 tests registered and passing  
**Learning:** Never write dbt YAML files on Windows via VS Code without explicitly enforcing LF. Python write with newline='\n' is the reliable fix

### Challenge 2 — Snowflake Reserved Words as Column Aliases
**Situation:** Writing stg_guests.sql  
**Problem:** SQLFluff RF04 — title, email, phone, address, first_name are Snowflake reserved words. Cannot use as column aliases  
**Options Considered:** Quote identifiers, rename with prefix  
**Decision:** guest_ prefix — guest_email, guest_phone, guest_address, guest_title, guest_first_name, guest_last_name  
**Result:** SQLFluff passing, schema.yml updated to match  
**Learning:** Always check SQLFluff output before dbt run — catches reserved word issues early

### Challenge 3 — Schema Naming RAW_staging Instead of staging
**Situation:** Running dbt seed after adding +schema: staging to dbt_project.yml  
**Problem:** dbt default generate_schema_name appends target schema prefix — produced RAW_staging instead of staging  
**Options Considered:** Change target schema, override macro  
**Decision:** generate_schema_name macro override — standard dbt pattern  
**Result:** Seeds and models land in correct staging schema  
**Learning:** Any multi-environment dbt project needs generate_schema_name macro — document this in Phase 0A next time

### Challenge 4 — stg_hotel_reservations unique test on confirmation_number
**Situation:** Running dbt test on stg_hotel_reservations  
**Problem:** confirmation_number has duplicates — M6 messiness intentionally injected 300 duplicates  
**Options Considered:** Remove unique test, add where clause to exclude duplicates  
**Decision:** Keep unique test — it should fail on raw data. This is the test doing its job. Deduplication logic goes in intermediate layer  
**Result:** unique test will fail — documented as expected, intentional  
**Learning:** Tests that fail on messy data are valuable — they confirm the messiness is detectable