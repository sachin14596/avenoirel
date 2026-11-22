-- =====================================================================
-- AVENOIREL - Classification tag for sensitive columns
-- =====================================================================
-- How to run: Snowsight worksheet, "Run all", as DEV_ROLE.
-- Safe to run more than once.
-- Prerequisite: 02_masking_policies.sql has been run (governance schema).
-- =====================================================================

USE ROLE DEV_ROLE;

CREATE TAG IF NOT EXISTS avenoirel_dev.governance.data_classification
    ALLOWED_VALUES 'PII'
    COMMENT = 'Marks columns that hold personal data';
