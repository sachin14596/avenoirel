#!/usr/bin/env bash
# AVENOIREL rebuild runner. Full story and manual steps: docs/rebuild_runbook.md
# Usage: source activate.sh && bash scripts/rebuild_account.sh [step ...]
# Steps, in this order (default: all): data sql load clone dbt smoke
#   data  : get the 10 frozen CSVs (raw-v1) if missing, verify the checksums
#   sql   : scripts 00, 01, 02, 03, 04, 06 through the connector
#   load  : load the CSVs into avenoirel_dev.raw as DEV_ROLE
#   clone : script 05, clone raw into preprod and prod
#   dbt   : dbt deps, then dbt build for dev, preprod, prod
#   smoke : scripts/smoke_test.py (state checks and the 4 RBAC tests)
# Stops at the first failure.
set -euo pipefail

if [ -z "${SNOWFLAKE_ACCOUNT:-}" ]; then
  echo "Run 'source activate.sh' first (it loads .env)"
  exit 1
fi

RELEASE_URL="https://github.com/sachin14596/avenoirel/releases/download/raw-v1/avenoirel-raw-v1.zip"
EXPECTED_BUILD="PASS=368 WARN=2 ERROR=0 SKIP=0 TOTAL=370"
DBT_ARGS="--project-dir dags/dbt --profiles-dir dags/dbt"
SQL=scripts/snowflake
DEV_ENV="SNOWFLAKE_ROLE=DEV_ROLE SNOWFLAKE_DATABASE=AVENOIREL_DEV SNOWFLAKE_WAREHOUSE=AVENOIREL_WH"

step_data() {
  if [ "$(ls data/raw/*.csv 2>/dev/null | wc -l)" -ne 10 ]; then
    echo "Downloading raw-v1 from the GitHub Release"
    tmp="$(mktemp -d)"
    curl -fL -o "$tmp/raw-v1.zip" "$RELEASE_URL"
    python -m zipfile -e "$tmp/raw-v1.zip" .
  fi
  md5sum -c docs/raw_checksums.txt
}

step_sql() {
  python scripts/run_sql.py "$SQL/00_bootstrap_account.sql" "$SQL/01_roles_and_grants.sql" \
    "$SQL/02_masking_policies.sql" "$SQL/03_classification_tags.sql" \
    "$SQL/04_governance_preprod_prod.sql" "$SQL/06_userland_schemas.sql"
}

step_load() {
  env $DEV_ENV SNOWFLAKE_SCHEMA=RAW python scripts/load_to_snowflake.py
}

step_clone() {
  python scripts/run_sql.py "$SQL/05_clone_raw_to_preprod_prod.sql"
}

step_dbt() {
  if [ ! -f dags/dbt/profiles.yml ]; then
    cp dags/dbt/profiles.yml.example dags/dbt/profiles.yml
  fi
  dbt deps $DBT_ARGS
  for target in dev preprod prod; do
    log="$(mktemp)"
    env $DEV_ENV dbt --no-use-colors build --target "$target" --exclude-resource-type unit_test $DBT_ARGS | tee "$log"
    echo "RESULT $target: $(grep -E 'Done\. PASS=' "$log" | tail -1)"
    if [ "$target" != "dev" ] && ! grep -q "$EXPECTED_BUILD" "$log"; then
      echo "Expected for $target: $EXPECTED_BUILD"
      exit 1
    fi
  done
}

step_smoke() {
  python scripts/smoke_test.py
}

steps=("$@")
if [ ${#steps[@]} -eq 0 ]; then
  steps=(data sql load clone dbt smoke)
fi
for s in "${steps[@]}"; do
  echo
  echo "=== step: $s ==="
  "step_$s"
done
echo
echo "Finished steps: ${steps[*]}"
