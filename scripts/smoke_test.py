"""
AVENOIREL smoke test: proves that a (re)built Snowflake account matches the expected state.

Run:  source activate.sh && python scripts/smoke_test.py
Needs SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER and SNOWFLAKE_PASSWORD in the environment (.env).
The 3 RBAC test files in scripts/snowflake/tests/ run part by part with secondary roles off.
The expected ERROR of test 1 (part 3B) and test 4 (part 4C) counts as a PASS.
Exit code 1 if any check fails. Expected numbers: docs/rebuild_runbook.md, smoke test section.
"""
import json
import os
import re
import sys
from pathlib import Path

import snowflake.connector
from dotenv import load_dotenv
from snowflake.connector.errors import ProgrammingError

load_dotenv()

TESTS = Path(__file__).parent / "snowflake" / "tests"
RETENTION = {"AVENOIREL_DEV": 1, "AVENOIREL_PREPROD": 7, "AVENOIREL_PROD": 90}
OWNER = {"AVENOIREL_DEV": "DEV_ROLE", "AVENOIREL_PREPROD": "PROD_ROLE", "AVENOIREL_PROD": "PROD_ROLE"}
RAW_ROWS = {
    "properties": 50, "room_types": 305, "guests": 45000, "avenir_members": 29173,
    "reservations": 60300, "folios": 78241, "cancellations": 14034,
    "room_availability": 334280, "avenir_points_transactions": 30343, "avenir_tier_history": 45190,
}
SCHEMA_OBJECTS = {"RAW": 10, "STAGING": 15, "INTERMEDIATE": 7, "MARTS": 12, "SNAPSHOT": 1, "DBT_TEST__AUDIT": 2}
EXPECT = {
    "rbac_test_1_analyst_cannot_read_raw.sql": {
        "1": ("value", 60300), "2": ("value", 60300), "3A": ("secondary_empty", None), "3B": ("error", None)},
    "rbac_test_2_and_3_pii_masking.sql": {
        "2A": ("value", 45000), "2B": ("masked", None), "3": ("real", None)},
    "rbac_test_4_dev_cannot_write_prod.sql": {
        "4A": ("value", 1), "4B": ("value", 60300), "4C": ("error", None)},
}
failures = []


def report(name, ok, detail=""):
    print(("PASS  " if ok else "FAIL  ") + name + ("" if ok else f"  ({detail})"))
    if not ok:
        failures.append(name)


conn = snowflake.connector.connect(
    account=os.environ["SNOWFLAKE_ACCOUNT"],
    user=os.environ["SNOWFLAKE_USER"],
    password=os.environ["SNOWFLAKE_PASSWORD"],
    warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "AVENOIREL_WH"),
)
cur = conn.cursor()


def use(role):
    cur.execute(f"USE ROLE {role}")
    cur.execute("USE SECONDARY ROLES NONE")
    cur.execute("USE WAREHOUSE AVENOIREL_WH")


def rows(sql):
    cur.execute(sql)
    cols = [d[0].lower() for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def scalar(sql):
    cur.execute(sql)
    return cur.fetchone()[0]


def evaluate(kind, want, row):
    if kind == "value":
        return row[0] == want
    if kind == "secondary_empty":
        return json.loads(row[1])["roles"] == ""
    if kind == "masked":
        return row[0] == 1 and row[1] > 0
    if kind == "real":
        return row[0] > 1 and row[1] == 0
    return False  # kind is "error" but the query ran without an error


print("\n== Account level (ACCOUNTADMIN) ==")
use("ACCOUNTADMIN")
dbs = {r["name"]: int(r["retention_time"]) for r in rows("SHOW DATABASES LIKE 'AVENOIREL%'")}
report("3 databases with retention 1 / 7 / 90", dbs == RETENTION, str(dbs))
wh = rows("SHOW WAREHOUSES LIKE 'AVENOIREL_WH'")
w = wh[0] if wh else {}
w_view = {k: w.get(k) for k in ("size", "auto_suspend", "enable_query_acceleration", "resource_monitor")}
report(
    "warehouse X-Small, auto-suspend 60, acceleration off, monitor attached",
    bool(w) and w["size"] == "X-Small" and int(w["auto_suspend"]) == 60
    and str(w["enable_query_acceleration"]).lower() == "false" and w["resource_monitor"] == "AVENOIREL_MONITOR",
    str(w_view),
)
for role in ("DEV_ROLE", "ANALYST_ROLE"):
    held_by = [x["grantee_name"] for x in rows(f"SHOW GRANTS OF ROLE {role}") if x["granted_to"] == "ROLE"]
    report(f"{role} is granted to PROD_ROLE", "PROD_ROLE" in held_by, str(held_by))
me = scalar("SELECT CURRENT_USER()")
held = {x["name"] for x in rows(f'SHOW GRANTS TO USER "{me}"') if x["granted_on"] == "ROLE"}
report("admin user holds the 3 roles", {"DEV_ROLE", "ANALYST_ROLE", "PROD_ROLE"} <= held, str(held))
ag = rows("SHOW GRANTS TO ROLE ANALYST_ROLE")
n_select = sum(1 for x in ag if x["privilege"] == "SELECT" and x["granted_on"] == "TABLE")
usage = {(x["granted_on"], x["name"]) for x in ag if x["privilege"] == "USAGE"}
report("analyst_role has 12 SELECT on prod marts", n_select == 12, str(n_select))
report(
    "analyst_role has USAGE on prod and prod.marts",
    {("DATABASE", "AVENOIREL_PROD"), ("SCHEMA", "AVENOIREL_PROD.MARTS")} <= usage,
    str(usage),
)

print("\n== Governance and data, per database (PROD_ROLE) ==")
use("PROD_ROLE")
for kind, wanted in (("MASKING POLICIES", "MASK_PII_STRING"), ("TAGS", "DATA_CLASSIFICATION")):
    found = {
        (x["database_name"], x["name"]): x["owner"]
        for x in rows(f"SHOW {kind} IN ACCOUNT") if x["database_name"].startswith("AVENOIREL")
    }
    report(
        f"{wanted} in all 3 databases with the right owner",
        all(found.get((db, wanted)) == OWNER[db] for db in OWNER),
        str(found),
    )
schema_list = ",".join(f"'{s}'" for s in SCHEMA_OBJECTS)
for db in OWNER:
    got = {t: scalar(f"SELECT COUNT(*) FROM {db}.raw.{t}") for t in RAW_ROWS}
    report(f"{db}: 10 raw tables with the expected rows", got == RAW_ROWS,
           str({t: v for t, v in got.items() if v != RAW_ROWS[t]}))
    objs = {r["table_schema"]: r["n"] for r in rows(
        f"SELECT table_schema, COUNT(*) AS n FROM {db}.information_schema.tables "
        f"WHERE table_schema IN ({schema_list}) GROUP BY 1")}
    report(f"{db}: objects per schema", objs == SCHEMA_OBJECTS, str(objs))
    report(f"{db}: dim_guest has 45000 rows", scalar(f"SELECT COUNT(*) FROM {db}.marts.dim_guest") == 45000)
    n_pol = scalar(
        f"SELECT COUNT(*) FROM TABLE({db}.information_schema.policy_references("
        f"ref_entity_name => '{db}.marts.dim_guest', ref_entity_domain => 'TABLE')) "
        f"WHERE policy_status = 'ACTIVE'")
    n_tag = scalar(
        f"SELECT COUNT(*) FROM TABLE({db}.information_schema.tag_references_all_columns("
        f"'{db}.marts.dim_guest', 'TABLE')) WHERE tag_name = 'DATA_CLASSIFICATION' AND tag_value = 'PII'")
    report(f"{db}: dim_guest has 5 columns masked and tagged", n_pol == 5 and n_tag == 5,
           f"policies={n_pol} tags={n_tag}")

print("\n== RBAC tests (secondary roles off) ==")
for fname, parts in EXPECT.items():
    chunks = re.split(r"(?m)^-- PART (\w+):", (TESTS / fname).read_text(encoding="utf-8"))
    found_parts = dict(zip(chunks[1::2], chunks[2::2]))
    for label, (kind, want) in parts.items():
        name = f"{fname} part {label}"
        if label not in found_parts:
            report(name, False, "part not found in the file")
            continue
        body = "\n".join(l for l in found_parts[label].splitlines()[1:] if not l.strip().startswith("--"))
        stmts = [s.strip() for s in body.split(";") if s.strip()]
        for s in stmts[:-1]:
            cur.execute(s)
        try:
            cur.execute(stmts[-1])
            row = cur.fetchone()
        except ProgrammingError as e:
            report(name, kind == "error" and "does not exist or not authorized" in str(e), str(e)[:150])
            continue
        report(name, evaluate(kind, want, row), f"result={row}")

conn.close()
print(f"\n{len(failures)} check(s) failed" if failures else "\nAll checks passed")
sys.exit(1 if failures else 0)
