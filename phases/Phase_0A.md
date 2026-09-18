# Phase 0A — Environment Setup
**Status:** Complete  
**Date:** September 2026

---

## What We Did

Set up the complete local development environment for AVENOIREL from scratch.

- Snowflake trial account created — AWS EU Frankfurt, Enterprise edition
- 3 databases: avenoirel_dev, avenoirel_preprod, avenoirel_prod
- 4 schemas per database: raw, staging, intermediate, marts
- Data retention: 90/7/1 days per environment
- Warehouse: AVENOIREL_WH — X-SMALL, auto-suspend 60s
- Roles: dev_role, analyst_role, prod_role with hierarchy
- GitHub repo created — sachin14596/avenoirel — public
- Python 3.12 virtual environment — isolated from system Python
- All dependencies installed via requirements.txt
- dbt project initialised in dags/dbt/ — Accor/Cosmos pattern
- dbt debug passing — Snowflake connection verified
- SQLFluff configured — Snowflake dialect
- pre-commit hooks — SQLFluff + dbt-checkpoint
- activate.sh — one command environment activation

---

## Why We Did It

Phase 0A exists because Fenzo Bank had scattered environment setup —
tools installed mid-project, assumptions made about credentials.
AVENOIREL locks everything before a single line of SQL is written.

Key decisions:
- AWS EU Frankfurt — mirrors Accor's Opera Cloud region, GDPR story
- Enterprise edition — required for Dynamic Data Masking in Phase 5
- dags/dbt/ nesting — Accor's exact Cosmos pattern for Phase 4
- Python 3.12 over 3.14 — dependency compatibility (dbt-checkpoint)
- X-SMALL warehouse + auto-suspend 60s — credits preserved

---

## Key Decisions

| Decision | Reason |
|---|---|
| AWS EU Frankfurt | Accor Opera Cloud runs on same region |
| Enterprise Snowflake | Dynamic Data Masking needs Enterprise |
| dags/dbt/ structure | Astronomer Cosmos scans dags/ folder |
| Python 3.12 | 3.14 had dbt-checkpoint compatibility issues |
| profiles.yml in project | Self-contained, works in CI/CD |
| activate.sh helper | One command for venv + env vars |

---

## Challenges

### Challenge 1 — Python 3.14 Dependency Incompatibility
**Situation:** Virtual environment created with system Python 3.14  
**Problem:** dbt-checkpoint and other packages not available for Python 3.14  
**Options Considered:** Stay on 3.14 and skip packages, or switch Python version  
**Decision:** Created new venv with Python 3.12 which was already installed  
**Result:** All packages installed successfully  
**Learning:** Always use a stable LTS Python version for production projects, not bleeding edge

### Challenge 2 — dbt-checkpoint Not on PyPI
**Situation:** requirements.txt had dbt-checkpoint==2.0.0  
**Problem:** Package not available on PyPI — it is a pre-commit hook, not a pip package  
**Options Considered:** Find alternative, skip it, use GitHub source directly  
**Decision:** Removed from requirements.txt, added to .pre-commit-config.yaml via GitHub URL  
**Result:** dbt-checkpoint working correctly as pre-commit hook  
**Learning:** Not all tools in the AE ecosystem are pip packages — some are pre-commit hooks installed via their GitHub repo

### Challenge 3 — elementary-data Dependency Conflict
**Situation:** elementary-data conflicted with dbt-snowflake via snowflake-connector-python  
**Problem:** elementary-data pulled old pyarrow version incompatible with modern cryptography  
**Options Considered:** Pin specific versions, remove elementary-data from pip  
**Decision:** Removed from requirements.txt — will be added as dbt package in packages.yml in Phase 1  
**Result:** All other packages installed cleanly  
**Learning:** Elementary is designed as a dbt package, not a pip dependency — correct installation method is packages.yml

### Challenge 4 — dbt init Project Structure
**Situation:** dbt init dbt created project in wrong location  
**Problem:** dbt uses project name for folder name, not the command argument  
**Options Considered:** Reinitialise, manually move files  
**Decision:** Renamed folder from avenoirel/ to dbt/ after init  
**Result:** Correct structure — dags/dbt/ with dbt_project.yml inside  
**Learning:** dbt init [name] creates a folder named after the project, not the argument — plan folder structure before running init