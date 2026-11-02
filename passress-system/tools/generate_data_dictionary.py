"""Generates docs/DATA_DICTIONARY.md from schemas/tables.json (single source of truth)."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
s = json.load(open(os.path.join(ROOT, "schemas", "tables.json"), encoding="utf-8"))
out = ["# PASSRESS - Data Dictionary", "", f"Generated from `schemas/tables.json` (schema version {s['version']}). "
       "**INPUT** tables are typed by the operator in Excel; **OUTPUT** tables are produced by the engine and loaded by Power Query (read-only).", ""]
for wb, w in s["workbooks"].items():
    out += [f"## {wb}  (`{w['file']}`)", ""]
    for t in w["tables"]:
        out += [f"### {t['name']} - {t['kind'].upper()}", "", t["purpose"], "", "| Column | Type | Meaning |", "|---|---|---|"]
        out += [f"| {c[0]} | {c[1]} | {c[2].replace('|', '/')} |" for c in t["columns"]]
        out.append("")
open(os.path.join(ROOT, "docs", "DATA_DICTIONARY.md"), "w", encoding="utf-8").write("\n".join(out))
print("tables:", sum(len(w["tables"]) for w in s["workbooks"].values()))
