-- =====================================================================
-- AVENOIREL - RBAC tests 2 and 3: PII masking on dim_guest.guest_email
-- =====================================================================
-- How to run: Snowsight worksheet. Run each part SEPARATELY (select the
-- lines of one part, then Ctrl+Enter). Secondary roles are switched off
-- so that each role is tested alone.
-- =====================================================================

-- PART 2A: control, analyst_role can read dim_guest (expected: 45000)
USE ROLE ANALYST_ROLE;
USE SECONDARY ROLES NONE;
USE WAREHOUSE AVENOIREL_WH;
SELECT COUNT(*) AS guest_rows FROM avenoirel_prod.marts.dim_guest;

-- PART 2B: TEST 2, analyst_role sees masked emails
-- expected: distinct_emails = 1, masked_values above 0
USE ROLE ANALYST_ROLE;
USE SECONDARY ROLES NONE;
USE WAREHOUSE AVENOIREL_WH;
SELECT
    COUNT(DISTINCT guest_email) AS distinct_emails,
    COUNT_IF(guest_email = '***MASKED***') AS masked_values
FROM avenoirel_prod.marts.dim_guest;

-- PART 3: TEST 3, prod_role sees real emails
-- expected: distinct_emails far above 1, masked_values = 0
USE ROLE PROD_ROLE;
USE SECONDARY ROLES NONE;
USE WAREHOUSE AVENOIREL_WH;
SELECT
    COUNT(DISTINCT guest_email) AS distinct_emails,
    COUNT_IF(guest_email = '***MASKED***') AS masked_values
FROM avenoirel_prod.marts.dim_guest;
