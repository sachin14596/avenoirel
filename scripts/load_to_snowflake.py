"""
AVENOIREL — Snowflake Raw Data Loader
======================================
Loads raw CSVs into Snowflake avenoirel_dev.raw schema.
Uses snowflake-connector-python with pandas for bulk load.

Usage:
    python scripts/load_to_snowflake.py
"""

import os
import pandas as pd
from pathlib import Path
from dotenv import load_dotenv
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas

# Load environment variables
load_dotenv()

RAW_DIR = Path("data/raw")

# Tables to load — in dependency order
TABLES = [
    "properties",
    "room_types",
    "guests",
    "avenir_members",
    "reservations",
    "folios",
    "cancellations",
    "room_availability",
    "avenir_points_transactions",
    "avenir_tier_history",
]

def get_connection():
    """Create Snowflake connection from environment variables."""
    return snowflake.connector.connect(
        account=os.environ['SNOWFLAKE_ACCOUNT'],
        user=os.environ['SNOWFLAKE_USER'],
        password=os.environ['SNOWFLAKE_PASSWORD'],
        warehouse=os.environ['SNOWFLAKE_WAREHOUSE'],
        database=os.environ['SNOWFLAKE_DATABASE'],
        schema=os.environ['SNOWFLAKE_SCHEMA'],
        role=os.environ['SNOWFLAKE_ROLE'],
    )

def load_table(conn, table_name: str):
    """Load a single CSV into Snowflake raw schema."""
    csv_path = RAW_DIR / f"{table_name}.csv"

    if not csv_path.exists():
        print(f"  SKIP: {csv_path} not found")
        return

    print(f"  Loading {table_name}...", end=" ")
    df = pd.read_csv(csv_path)

    # Snowflake column names must be uppercase
    df.columns = [c.upper() for c in df.columns]

    success, nchunks, nrows, _ = write_pandas(
        conn=conn,
        df=df,
        table_name=table_name.upper(),
        database=os.environ['SNOWFLAKE_DATABASE'],
        schema=os.environ['SNOWFLAKE_SCHEMA'],
        auto_create_table=True,
        overwrite=True,
    )

    if success:
        print(f"✅ {nrows:,} rows loaded")
    else:
        print(f"❌ Failed")

def main():
    print("\nAVENOIREL — Snowflake Raw Data Loader")
    print("=" * 45)
    print(f"Target: {os.environ['SNOWFLAKE_DATABASE']}.{os.environ['SNOWFLAKE_SCHEMA']}")
    print("=" * 45 + "\n")

    conn = get_connection()
    print("✅ Snowflake connection established\n")

    for table in TABLES:
        load_table(conn, table)

    conn.close()
    print("\n✅ All tables loaded successfully")
    print("Raw data ready for dbt transformations.\n")

if __name__ == "__main__":
    main()