-- =====================================================================
-- AVENOIREL - Userland (personal sandbox) schema for development
-- =====================================================================
-- How to run: Snowsight worksheet, "Run all", as DEV_ROLE.
-- Safe to run more than once.
-- Prerequisite: 00_bootstrap_account.sql and 01_roles_and_grants.sql
-- have been run (database avenoirel_dev and DEV_ROLE exist).
-- Note: preprod and prod are separate databases, so they get no
-- userland schema (decision D27).
-- =====================================================================

USE ROLE DEV_ROLE;

CREATE SCHEMA IF NOT EXISTS avenoirel_dev.dev_sachin
    COMMENT = 'Personal sandbox for experiments, not used by shared pipelines';

-- Verify: one row DEV_SACHIN, owner DEV_ROLE
SHOW SCHEMAS LIKE 'DEV_SACHIN' IN DATABASE avenoirel_dev;
