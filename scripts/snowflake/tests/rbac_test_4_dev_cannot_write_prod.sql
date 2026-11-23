-- =====================================================================
-- AVENOIREL - RBAC test 4: dev_role cannot write to prod
-- =====================================================================
-- How to run: Snowsight worksheet. Run each part SEPARATELY (select the
-- lines of one part, then Ctrl+Enter). Secondary roles are switched off
-- so that each role is tested alone.
-- The test uses an INSERT of ZERO rows (WHERE 1 = 0): the privilege is
-- checked before any row is written, and if the test ever fails, prod
-- data is not changed.
-- =====================================================================

-- PART 4A: control, dev_role can write in its own sandbox (expected: 1)
USE ROLE DEV_ROLE;
USE SECONDARY ROLES NONE;
USE WAREHOUSE AVENOIREL_WH;
CREATE OR REPLACE TEMPORARY TABLE avenoirel_dev.dev_sachin.rbac_test_4_control (id NUMBER);
INSERT INTO avenoirel_dev.dev_sachin.rbac_test_4_control VALUES (1);
SELECT COUNT(*) AS sandbox_rows FROM avenoirel_dev.dev_sachin.rbac_test_4_control;

-- PART 4B: control, the prod table exists (expected: 60300)
USE ROLE PROD_ROLE;
USE SECONDARY ROLES NONE;
USE WAREHOUSE AVENOIREL_WH;
SELECT COUNT(*) AS fct_bookings_rows FROM avenoirel_prod.marts.fct_bookings;

-- PART 4C: the test (expected: an ERROR, no privilege on prod)
-- If this runs without an error, the test FAILED (prod stays unchanged
-- because zero rows are inserted).
USE ROLE DEV_ROLE;
USE SECONDARY ROLES NONE;
USE WAREHOUSE AVENOIREL_WH;
INSERT INTO avenoirel_prod.marts.fct_bookings
SELECT * FROM avenoirel_prod.marts.fct_bookings WHERE 1 = 0;
