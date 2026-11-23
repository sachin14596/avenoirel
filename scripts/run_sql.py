"""
Runs the numbered Snowflake scripts through the connector, statement by statement.

Usage: python scripts/run_sql.py [--dry-run] scripts/snowflake/00_bootstrap_account.sql ...
All files run in ONE session, in the order given. Stops at the first error.
After every USE ROLE the session switches secondary roles off, so each role runs alone.
--dry-run only parses the files and prints the statements, it does not connect.
Needs SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER and SNOWFLAKE_PASSWORD in the environment (.env).
"""
import os
import sys
from pathlib import Path


def split_statements(text):
    """Split SQL text on ';', ignoring comments and semicolons inside single quotes."""
    out, buf, in_quote, i = [], [], False, 0
    while i < len(text):
        c = text[i]
        if not in_quote and text.startswith("--", i):
            j = text.find("\n", i)
            i = len(text) if j == -1 else j
            continue
        if c == "'":
            in_quote = not in_quote
        if c == ";" and not in_quote:
            stmt = "".join(buf).strip()
            if stmt:
                out.append(stmt)
            buf = []
        else:
            buf.append(c)
        i += 1
    stmt = "".join(buf).strip()
    if stmt:
        out.append(stmt)
    return out


def main():
    args = sys.argv[1:]
    dry = "--dry-run" in args
    files = [Path(a) for a in args if a != "--dry-run"]
    if not files:
        sys.exit("usage: python scripts/run_sql.py [--dry-run] file.sql [file.sql ...]")
    plan = [(f, split_statements(f.read_text(encoding="utf-8"))) for f in files]

    if dry:
        for f, stmts in plan:
            print(f"{f.name}: {len(stmts)} statements")
            for s in stmts:
                print("    " + " ".join(s.split())[:90])
        return

    import snowflake.connector
    from dotenv import load_dotenv

    load_dotenv()
    conn = snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
    )
    cur = conn.cursor()
    for f, stmts in plan:
        print(f"\n== {f.name} ==")
        for n, s in enumerate(stmts, 1):
            label = " ".join(s.split())[:80]
            try:
                cur.execute(s)
            except Exception as e:
                print(f"  FAIL [{n}/{len(stmts)}] {label}\n  {e}")
                sys.exit(1)
            print(f"  ok [{n}/{len(stmts)}] {label}")
            if s.upper().startswith("USE ROLE"):
                cur.execute("USE SECONDARY ROLES NONE")
    conn.close()


if __name__ == "__main__":
    main()
