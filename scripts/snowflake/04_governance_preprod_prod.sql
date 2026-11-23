-- =====================================================================
-- AVENOIREL - Governance objects for preprod and prod
-- =====================================================================
-- How to run: Snowsight worksheet, "Run all". The script switches to PROD_ROLE.
-- Safe to run more than once (IF NOT EXISTS everywhere).
-- Prerequisite: 01_roles_and_grants.sql has been run.
--
-- To change the policy later, do NOT use CREATE OR REPLACE (it fails once the
-- policy is attached to columns). Use:
--   ALTER MASKING POLICY <db>.governance.mask_pii_string SET BODY -> ...
-- =====================================================================

USE ROLE PROD_ROLE;

-- ---------- preprod ----------
CREATE SCHEMA IF NOT EXISTS avenoirel_preprod.governance
    COMMENT = 'Governance objects: masking policies and tags';

CREATE MASKING POLICY IF NOT EXISTS avenoirel_preprod.governance.mask_pii_string
    AS (val VARCHAR) RETURNS VARCHAR ->
    CASE
        WHEN IS_ROLE_IN_SESSION('PROD_ROLE') THEN val
        WHEN IS_ROLE_IN_SESSION('DEV_ROLE') THEN val
        ELSE '***MASKED***'
    END
    COMMENT = 'Masks guest PII for every role except the builder roles';

CREATE TAG IF NOT EXISTS avenoirel_preprod.governance.data_classification
    ALLOWED_VALUES 'PII'
    COMMENT = 'Marks columns that hold personal data';

-- ---------- prod ----------
CREATE SCHEMA IF NOT EXISTS avenoirel_prod.governance
    COMMENT = 'Governance objects: masking policies and tags';

CREATE MASKING POLICY IF NOT EXISTS avenoirel_prod.governance.mask_pii_string
    AS (val VARCHAR) RETURNS VARCHAR ->
    CASE
        WHEN IS_ROLE_IN_SESSION('PROD_ROLE') THEN val
        WHEN IS_ROLE_IN_SESSION('DEV_ROLE') THEN val
        ELSE '***MASKED***'
    END
    COMMENT = 'Masks guest PII for every role except the builder roles';

CREATE TAG IF NOT EXISTS avenoirel_prod.governance.data_classification
    ALLOWED_VALUES 'PII'
    COMMENT = 'Marks columns that hold personal data';
