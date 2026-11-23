-- =====================================================================
-- AVENOIREL - Snowflake roles, role hierarchy and grants (RBAC as code)
-- =====================================================================
-- How to run: Snowsight worksheet, "Run all".
-- Safe to run more than once: every statement can be repeated.
-- Prerequisite: script 00 ran (the three databases, their schemas and the warehouse exist).
--
-- Access model
--   dev_role      builds in avenoirel_dev only
--   prod_role     builds in avenoirel_preprod and avenoirel_prod,
--                 and inherits dev_role and analyst_role
--   analyst_role  reads only the marts schema of avenoirel_prod
-- =====================================================================

USE ROLE ACCOUNTADMIN;

-- 1. Roles
CREATE ROLE IF NOT EXISTS dev_role COMMENT = 'Builds the dbt project in avenoirel_dev';
CREATE ROLE IF NOT EXISTS analyst_role COMMENT = 'Reads the marts of avenoirel_prod, sees masked PII';
CREATE ROLE IF NOT EXISTS prod_role COMMENT = 'Deploys to avenoirel_preprod and avenoirel_prod, sees full PII';

-- 2. Role hierarchy: prod_role inherits the powers of the two roles below it
GRANT ROLE dev_role TO ROLE prod_role;
GRANT ROLE analyst_role TO ROLE prod_role;

-- 3. Warehouse: every role needs compute to run queries
GRANT USAGE ON WAREHOUSE avenoirel_wh TO ROLE dev_role;
GRANT USAGE ON WAREHOUSE avenoirel_wh TO ROLE analyst_role;
GRANT USAGE ON WAREHOUSE avenoirel_wh TO ROLE prod_role;

-- 4. Database level
GRANT USAGE, CREATE SCHEMA ON DATABASE avenoirel_dev TO ROLE dev_role;
GRANT ALL PRIVILEGES ON DATABASE avenoirel_preprod TO ROLE prod_role;
GRANT ALL PRIVILEGES ON DATABASE avenoirel_prod TO ROLE prod_role;
GRANT USAGE ON DATABASE avenoirel_prod TO ROLE analyst_role;

-- 5. Schema level for the builders
GRANT ALL PRIVILEGES ON SCHEMA avenoirel_dev.raw TO ROLE dev_role;
GRANT ALL PRIVILEGES ON SCHEMA avenoirel_dev.staging TO ROLE dev_role;
GRANT ALL PRIVILEGES ON SCHEMA avenoirel_dev.intermediate TO ROLE dev_role;
GRANT ALL PRIVILEGES ON SCHEMA avenoirel_dev.marts TO ROLE dev_role;

GRANT ALL PRIVILEGES ON SCHEMA avenoirel_preprod.raw TO ROLE prod_role;
GRANT ALL PRIVILEGES ON SCHEMA avenoirel_preprod.staging TO ROLE prod_role;
GRANT ALL PRIVILEGES ON SCHEMA avenoirel_preprod.intermediate TO ROLE prod_role;
GRANT ALL PRIVILEGES ON SCHEMA avenoirel_preprod.marts TO ROLE prod_role;

GRANT ALL PRIVILEGES ON SCHEMA avenoirel_prod.raw TO ROLE prod_role;
GRANT ALL PRIVILEGES ON SCHEMA avenoirel_prod.staging TO ROLE prod_role;
GRANT ALL PRIVILEGES ON SCHEMA avenoirel_prod.intermediate TO ROLE prod_role;
GRANT ALL PRIVILEGES ON SCHEMA avenoirel_prod.marts TO ROLE prod_role;

-- 6. Analyst: read-only access to the prod marts, nothing else
GRANT USAGE ON SCHEMA avenoirel_prod.marts TO ROLE analyst_role;
GRANT SELECT ON ALL TABLES IN SCHEMA avenoirel_prod.marts TO ROLE analyst_role;
GRANT SELECT ON FUTURE TABLES IN SCHEMA avenoirel_prod.marts TO ROLE analyst_role;

-- 7. Give the three roles to the user who runs this script (the admin created at signup).
-- CURRENT_USER() means no user name is hard coded, so the script works in any account.
SET admin_user = CURRENT_USER();
GRANT ROLE dev_role TO USER IDENTIFIER($admin_user);
GRANT ROLE analyst_role TO USER IDENTIFIER($admin_user);
GRANT ROLE prod_role TO USER IDENTIFIER($admin_user);

-- 8. Verification (run by hand after the script)
-- SHOW GRANTS TO ROLE analyst_role;
-- SHOW FUTURE GRANTS IN SCHEMA avenoirel_prod.marts;
-- SHOW GRANTS TO ROLE prod_role;
-- SHOW GRANTS TO ROLE dev_role;
-- SHOW GRANTS TO USER IDENTIFIER($admin_user);
