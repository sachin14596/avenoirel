-- =====================================================================
-- AVENOIREL - RBAC test 1: analyst_role cannot read raw
-- =====================================================================
-- How to run: Snowsight worksheet. Run each part SEPARATELY (select the
-- lines of one part, then Ctrl+Enter). Do NOT use "Run all": it stops at
-- the first error and shows only the last result.
-- Why USE SECONDARY ROLES NONE: a user who holds several roles gets the
-- privileges of ALL of them when secondary roles are ALL, so the test
-- would not prove what analyst_role alone can do.
-- =====================================================================

-- PART 1: control, the object exists (expected: 60300)
USE ROLE PROD_ROLE;
USE SECONDARY ROLES NONE;
USE WAREHOUSE AVENOIREL_WH;
SELECT COUNT(*) AS reservations_rows FROM avenoirel_prod.raw.reservations;

-- PART 2: control, analyst_role and the warehouse work (expected: 60300)
USE ROLE ANALYST_ROLE;
USE SECONDARY ROLES NONE;
USE WAREHOUSE AVENOIREL_WH;
SELECT COUNT(*) AS fct_bookings_rows FROM avenoirel_prod.marts.fct_bookings;

-- PART 3A: check that analyst_role really runs alone (expected: secondary roles empty)
USE ROLE ANALYST_ROLE;
USE SECONDARY ROLES NONE;
SELECT CURRENT_ROLE() AS primary_role, CURRENT_SECONDARY_ROLES() AS secondary_roles;

-- PART 3B: the test (expected: an ERROR "does not exist or not authorized")
-- If this returns a row, the test FAILED and raw is exposed.
USE ROLE ANALYST_ROLE;
USE SECONDARY ROLES NONE;
USE WAREHOUSE AVENOIREL_WH;
SELECT * FROM avenoirel_prod.raw.reservations LIMIT 1;
