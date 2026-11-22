-- =====================================================================
-- AVENOIREL - Account bootstrap: databases, schemas, retention
-- =====================================================================
-- How to run: Snowsight worksheet, "Run all", FIRST, as ACCOUNTADMIN.
-- Safe to run more than once. Run order for a new account:
--   00 bootstrap, 01 roles and grants, 02 and 03 governance (dev),
--   04 governance (preprod, prod), 05 clone raw (after raw is loaded in dev).
-- Retention: dev 1 day, preprod 7 days, prod 90 days (Enterprise edition).
-- =====================================================================

USE ROLE ACCOUNTADMIN;

-- ---------- databases ----------
CREATE DATABASE IF NOT EXISTS avenoirel_dev DATA_RETENTION_TIME_IN_DAYS = 1;
CREATE DATABASE IF NOT EXISTS avenoirel_preprod DATA_RETENTION_TIME_IN_DAYS = 7;
CREATE DATABASE IF NOT EXISTS avenoirel_prod DATA_RETENTION_TIME_IN_DAYS = 90;

ALTER DATABASE avenoirel_dev SET DATA_RETENTION_TIME_IN_DAYS = 1;
ALTER DATABASE avenoirel_preprod SET DATA_RETENTION_TIME_IN_DAYS = 7;
ALTER DATABASE avenoirel_prod SET DATA_RETENTION_TIME_IN_DAYS = 90;

-- ---------- schemas (the 4 layers) ----------
CREATE SCHEMA IF NOT EXISTS avenoirel_dev.raw;
CREATE SCHEMA IF NOT EXISTS avenoirel_dev.staging;
CREATE SCHEMA IF NOT EXISTS avenoirel_dev.intermediate;
CREATE SCHEMA IF NOT EXISTS avenoirel_dev.marts;

CREATE SCHEMA IF NOT EXISTS avenoirel_preprod.raw;
CREATE SCHEMA IF NOT EXISTS avenoirel_preprod.staging;
CREATE SCHEMA IF NOT EXISTS avenoirel_preprod.intermediate;
CREATE SCHEMA IF NOT EXISTS avenoirel_preprod.marts;

CREATE SCHEMA IF NOT EXISTS avenoirel_prod.raw;
CREATE SCHEMA IF NOT EXISTS avenoirel_prod.staging;
CREATE SCHEMA IF NOT EXISTS avenoirel_prod.intermediate;
CREATE SCHEMA IF NOT EXISTS avenoirel_prod.marts;

-- ---------- warehouse ----------
CREATE WAREHOUSE IF NOT EXISTS avenoirel_wh
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    ENABLE_QUERY_ACCELERATION = FALSE
    COMMENT = 'Main warehouse for AVENOIREL. X-Small to preserve trial credits.';

ALTER WAREHOUSE avenoirel_wh SET ENABLE_QUERY_ACCELERATION = FALSE;

-- ---------- resource monitor ----------
-- Change the credit quota in the next statement when you move to a new account.
CREATE RESOURCE MONITOR IF NOT EXISTS avenoirel_monitor
    WITH CREDIT_QUOTA = 20
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS ON 80 PERCENT DO NOTIFY
             ON 100 PERCENT DO SUSPEND;

ALTER WAREHOUSE avenoirel_wh SET RESOURCE_MONITOR = avenoirel_monitor;
