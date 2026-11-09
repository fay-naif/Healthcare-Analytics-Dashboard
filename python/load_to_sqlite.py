"""
Load the six sheets of data/Healthcare_Analytics_Clean_30000.xlsx into a SQLite
database (python/output/healthcare.db) and run every query in sql/analysis.sql.

    python python/load_to_sqlite.py
"""
import sqlite3
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "Healthcare_Analytics_Clean_30000.xlsx"
SQL = ROOT / "sql" / "analysis.sql"
DB = ROOT / "python" / "output" / "healthcare.db"
SHEETS = ["Visits", "Billing", "Patients", "Providers", "Facilities", "Services"]


def main():
    DB.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(DB) as con:
        for sheet in SHEETS:
            df = pd.read_excel(DATA, sheet_name=sheet)
            if "Visit_Date" in df:
                df["Visit_Date"] = pd.to_datetime(df["Visit_Date"]).dt.strftime("%Y-%m-%d")
            df.to_sql(sheet.lower(), con, if_exists="replace", index=False)

        queries = [q.strip() for q in SQL.read_text(encoding="utf-8").split(";") if q.strip()]
        for q in queries:
            title = next((l for l in q.splitlines() if l.startswith("-- ") and l[3:4].isdigit()), "")
            print(title)
            body = "\n".join(l for l in q.splitlines() if not l.startswith("--"))
            print(pd.read_sql_query(body, con).to_string(index=False))
            print()


if __name__ == "__main__":
    main()
