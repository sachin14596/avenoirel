-- =====================================================================
-- AVENOIREL - Zero-copy clone of raw tables into preprod and prod
-- =====================================================================
-- How to run: Snowsight worksheet, "Run all". The script switches to PROD_ROLE.
-- Safe to run more than once: it refreshes raw from avenoirel_dev.raw.
-- Prerequisite: 01_roles_and_grants.sql has been run, avenoirel_dev.raw is loaded.
--
-- Tables are cloned one by one (not the whole schema) so the schema keeps
-- its grants. No masking policy is attached to raw, so OR REPLACE is safe here.
-- =====================================================================

USE ROLE PROD_ROLE;

-- ---------- preprod ----------
CREATE OR REPLACE TABLE avenoirel_preprod.raw.properties CLONE avenoirel_dev.raw.properties;
CREATE OR REPLACE TABLE avenoirel_preprod.raw.room_types CLONE avenoirel_dev.raw.room_types;
CREATE OR REPLACE TABLE avenoirel_preprod.raw.guests CLONE avenoirel_dev.raw.guests;
CREATE OR REPLACE TABLE avenoirel_preprod.raw.avenir_members CLONE avenoirel_dev.raw.avenir_members;
CREATE OR REPLACE TABLE avenoirel_preprod.raw.reservations CLONE avenoirel_dev.raw.reservations;
CREATE OR REPLACE TABLE avenoirel_preprod.raw.folios CLONE avenoirel_dev.raw.folios;
CREATE OR REPLACE TABLE avenoirel_preprod.raw.cancellations CLONE avenoirel_dev.raw.cancellations;
CREATE OR REPLACE TABLE avenoirel_preprod.raw.room_availability CLONE avenoirel_dev.raw.room_availability;
CREATE OR REPLACE TABLE avenoirel_preprod.raw.avenir_points_transactions
    CLONE avenoirel_dev.raw.avenir_points_transactions;
CREATE OR REPLACE TABLE avenoirel_preprod.raw.avenir_tier_history CLONE avenoirel_dev.raw.avenir_tier_history;

-- ---------- prod ----------
CREATE OR REPLACE TABLE avenoirel_prod.raw.properties CLONE avenoirel_dev.raw.properties;
CREATE OR REPLACE TABLE avenoirel_prod.raw.room_types CLONE avenoirel_dev.raw.room_types;
CREATE OR REPLACE TABLE avenoirel_prod.raw.guests CLONE avenoirel_dev.raw.guests;
CREATE OR REPLACE TABLE avenoirel_prod.raw.avenir_members CLONE avenoirel_dev.raw.avenir_members;
CREATE OR REPLACE TABLE avenoirel_prod.raw.reservations CLONE avenoirel_dev.raw.reservations;
CREATE OR REPLACE TABLE avenoirel_prod.raw.folios CLONE avenoirel_dev.raw.folios;
CREATE OR REPLACE TABLE avenoirel_prod.raw.cancellations CLONE avenoirel_dev.raw.cancellations;
CREATE OR REPLACE TABLE avenoirel_prod.raw.room_availability CLONE avenoirel_dev.raw.room_availability;
CREATE OR REPLACE TABLE avenoirel_prod.raw.avenir_points_transactions
    CLONE avenoirel_dev.raw.avenir_points_transactions;
CREATE OR REPLACE TABLE avenoirel_prod.raw.avenir_tier_history CLONE avenoirel_dev.raw.avenir_tier_history;
