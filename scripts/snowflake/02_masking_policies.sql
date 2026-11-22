-- =====================================================================
-- AVENOIREL - Masking policies for guest personal info (PII)
-- =====================================================================
-- How to run: Snowsight worksheet, "Run all", as DEV_ROLE.
-- Safe to run more than once while the policy is not attached to a column.
-- Prerequisite: 01_roles_and_grants.sql has been run.
--
-- Rule: builders (dev_role, prod_role) see real values, everyone else
-- sees ***MASKED***. IS_ROLE_IN_SESSION respects role inheritance,
-- CURRENT_ROLE does not.
-- =====================================================================

USE ROLE DEV_ROLE;

CREATE SCHEMA IF NOT EXISTS avenoirel_dev.governance
    COMMENT = 'Governance objects: masking policies and tags';

CREATE OR REPLACE MASKING POLICY avenoirel_dev.governance.mask_pii_string
    AS (val VARCHAR) RETURNS VARCHAR ->
    CASE
        WHEN IS_ROLE_IN_SESSION('PROD_ROLE') THEN val
        WHEN IS_ROLE_IN_SESSION('DEV_ROLE') THEN val
        ELSE '***MASKED***'
    END
    COMMENT = 'Masks guest PII for every role except the builder roles';
