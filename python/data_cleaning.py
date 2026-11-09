"""
Healthcare data checks and preparation.

Reads the six sheets of data/Healthcare_Analytics_Clean_30000.xlsx, checks
each one, joins them into one visit-level table (the same joins as the
Power Query model), adds the calculated columns and prints the headline
figures used in the dashboard.

Run from the repository root:
    pip install -r python/requirements.txt
    python python/data_cleaning.py
"""
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "Healthcare_Analytics_Clean_30000.xlsx"
OUT = ROOT / "python" / "output"

SHEETS = {
    "Visits": "Visit_ID",
    "Billing": "Bill_ID",
    "Patients": "Patient_ID",
    "Providers": "Provider_ID",
    "Facilities": "Facility_ID",
    "Services": "Service_ID",
}


def load():
    return {name: pd.read_excel(DATA, sheet_name=name) for name in SHEETS}


def sheet_checks(tables):
    rows = []
    for name, key in SHEETS.items():
        t = tables[name]
        rows.append(
            {
                "sheet": name,
                "rows": len(t),
                "blank_cells": int(t.isna().sum().sum()),
                "duplicate_ids": int(t[key].duplicated().sum()),
            }
        )
    return pd.DataFrame(rows).set_index("sheet")


def relation_checks(tables):
    v, b = tables["Visits"], tables["Billing"]
    return pd.Series(
        {
            "Visits without a bill": int((~v["Visit_ID"].isin(b["Visit_ID"])).sum()),
            "Visits with more than one bill": int(b["Visit_ID"].duplicated().sum()),
            "Unknown patient": int((~v["Patient_ID"].isin(tables["Patients"]["Patient_ID"])).sum()),
            "Unknown facility": int((~v["Facility_ID"].isin(tables["Facilities"]["Facility_ID"])).sum()),
            "Unknown provider": int((~v["Provider_ID"].isin(tables["Providers"]["Provider_ID"])).sum()),
            "Unknown service": int((~v["Service_ID"].isin(tables["Services"]["Service_ID"])).sum()),
            "Collected more than charged": int((b["Collected_SAR"] > b["Charge_SAR"]).sum()),
            "Negative wait time": int((v["Wait_Minutes"] < 0).sum()),
        },
        name="Result",
    )


def build_visits(tables):
    """Join everything onto Visits and add the calculated columns."""
    patients = tables["Patients"].rename(columns={"City": "Patient_City"})
    facilities = tables["Facilities"].rename(columns={"City": "Facility_City"})
    df = (
        tables["Visits"]
        .merge(tables["Billing"][["Visit_ID", "Charge_SAR", "Collected_SAR"]], on="Visit_ID", how="left")
        .merge(patients[["Patient_ID", "Gender", "Age", "Patient_City", "Payment_Type"]], on="Patient_ID", how="left")
        .merge(tables["Services"][["Service_ID", "Service_Name"]], on="Service_ID", how="left")
        .merge(facilities[["Facility_ID", "Facility_Name", "Facility_City", "Beds"]], on="Facility_ID", how="left")
    )
    df["Visit_Date"] = pd.to_datetime(df["Visit_Date"])
    df["Year"] = df["Visit_Date"].dt.year
    df["Uncollected_SAR"] = df["Charge_SAR"] - df["Collected_SAR"]
    df["Wait_Band"] = pd.cut(
        df["Wait_Minutes"],
        bins=[-np.inf, 30, 60, 90, 120, np.inf],
        labels=["0-30 min", "31-60 min", "61-90 min", "91-120 min", "121-150 min"],
    )
    df["Age_Group"] = pd.cut(
        df["Age"], bins=[-np.inf, 17, 34, 49, 64, np.inf], labels=["0-17", "18-34", "35-49", "50-64", "65+"]
    )
    return df


def headline(df):
    billed = df["Charge_SAR"].sum()
    collected = df["Collected_SAR"].sum()
    er = df[df["Department"] == "Emergency"]
    return pd.Series(
        {
            "Visits": len(df),
            "Patients": df["Patient_ID"].nunique(),
            "Total billed (SAR)": round(billed, 0),
            "Collected (SAR)": round(collected, 0),
            "Collection rate %": round(100 * collected / billed, 1),
            "Uncollected (SAR)": round(billed - collected, 0),
            "Average bill (SAR)": round(billed / len(df), 0),
            "Average wait (min)": round(df["Wait_Minutes"].mean(), 1),
            "Visits waiting 90+ min %": round(100 * (df["Wait_Minutes"] > 90).mean(), 1),
            "ER seen within 30 min %": round(100 * (er["Wait_Minutes"] <= 30).mean(), 1),
            "Admission rate %": round(100 * (df["Outcome"] == "Admitted").mean(), 1),
        },
        name="Value",
    )


def main():
    tables = load()
    OUT.mkdir(parents=True, exist_ok=True)
    checks = sheet_checks(tables)
    relations = relation_checks(tables)
    checks.to_csv(OUT / "sheet_checks.csv")
    relations.to_csv(OUT / "relation_checks.csv", header=True)

    visits = build_visits(tables)
    visits.to_csv(OUT / "visits_model.csv", index=False)

    print("Sheet checks")
    print(checks.to_string())
    print()
    print("Relationship checks")
    print(relations.to_string())
    print()
    print("Headline figures")
    print(headline(visits).to_string())


if __name__ == "__main__":
    main()
