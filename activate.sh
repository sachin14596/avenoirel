#!/bin/bash
# AVENOIREL — activate environment
# Run: source activate.sh

source .venv/Scripts/activate
set -a && source .env && set +a

echo "AVENOIREL environment activated"
echo "Snowflake account: $SNOWFLAKE_ACCOUNT"