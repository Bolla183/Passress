"""Static consistency checks for the PASSRESS code base (runs anywhere with Python 3; no PowerShell needed).

Checks
 1. schemas/tables.json parses; no duplicate tables/columns; valid types.
 2. Every key written in an [ordered]@{...} row literal in the engine exists as a column in the schema.
 3. Every engine output table in the schema is produced by a stage (named in the stage code).
 4. Every Table[Column] structured reference in workbook formulas (Build script) exists in the schema.
 5. Every table/column used by test assertions exists in the schema.
 6. Brackets ( ) { } [ ] balance in every .ps1/.psm1 file (string/comment/here-string aware).
 7. No credential-looking literal (shpss_/shpat_ + 10 chars) anywhere in the code base.
Exit code 1 if any check fails.
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
fails, notes = [], []

def read(p):
    with open(os.path.join(ROOT, p), encoding="utf-8") as fh:
        return fh.read()

# 1 ---------------------------------------------------------------- schema
schema = json.loads(read("schemas/tables.json"))
cols_by_table, all_cols, kinds = {}, set(), {}
for wb, w in schema["workbooks"].items():
    names = [t["name"] for t in w["tables"]]
    if len(names) != len(set(names)):
        fails.append(f"schema: duplicate table in {wb}")
    for t in w["tables"]:
        cs = [c[0] for c in t["columns"]]
        if len(cs) != len(set(cs)):
            fails.append(f"schema: duplicate column in {wb}.{t['name']}")
        for c in t["columns"]:
            if c[1] not in ("text", "number", "int", "date", "datetime", "bool"):
                fails.append(f"schema: bad type {c[1]} in {wb}.{t['name']}.{c[0]}")
        cols_by_table.setdefault(t["name"], set()).update(cs)
        all_cols.update(cs)
        kinds[(wb, t["name"])] = t["kind"]
n_tables = sum(len(w["tables"]) for w in schema["workbooks"].values())
notes.append(f"schema: {len(schema['workbooks'])} workbooks, {n_tables} tables, {sum(len(c) for c in cols_by_table.values())} distinct table/column pairs")

# 2 ---------------------------------------------------------------- engine row keys
engine_files = [f"src/engine/{f}" for f in ("DataSource.ps1", "Operations.ps1", "Finance.ps1", "Management.ps1")]
key_re = re.compile(r"(?:^[ \t]*|[;{][ \t]*)([A-Z][A-Za-z0-9]+)[ \t]*=[ \t]*", re.M)
checked = 0
for f in engine_files:
    src = read(f)
    for m in re.finditer(r"\[ordered\]@\{", src):
        depth, i = 0, m.end() - 1
        while i < len(src):
            ch = src[i]
            if ch == "{": depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0: break
            i += 1
        body = src[m.end():i]
        # only top-level keys of this literal (skip nested scriptblocks/hashtables)
        flat, d = [], 0
        for ch in body:
            if ch in "{(": d += 1
            elif ch in "})": d -= 1
            flat.append(ch if d == 0 else " ")
        for k in key_re.findall("".join(flat)):
            checked += 1
            if k not in all_cols:
                line = src[:m.start()].count("\n") + 1
                fails.append(f"engine key not in schema: {k} ({f}:{line})")
notes.append(f"engine: {checked} row keys checked against schema")

# 3 ---------------------------------------------------------------- outputs produced
stage_code = "".join(read(f) for f in engine_files) + read("src/Passress.Engine.psm1")
for (wb, t), kind in kinds.items():
    if kind == "output" and t != "LOG_REFRESH" and t not in stage_code:
        fails.append(f"output table never produced: {wb}.{t}")

# 4 ---------------------------------------------------------------- structured references in formulas
build = read("scripts/Build-PassressSystem.ps1")
refs = set(re.findall(r"([A-Z_]{3,})\[([A-Za-z]+)\]", build))
# UPSTREAM_STATUS is the freshness query built from the upstream LOG_REFRESH (not an engine table)
cols_by_table.setdefault("UPSTREAM_STATUS", set()).update({"RunId", "Stage", "Status", "EndedAt"})
for t, c in sorted(refs):
    if t not in cols_by_table:
        fails.append(f"formula references unknown table {t}[{c}]")
    elif c not in cols_by_table[t]:
        fails.append(f"formula references unknown column {t}[{c}]")
notes.append(f"formulas: {len(refs)} structured references checked")

# 5 ---------------------------------------------------------------- test assertions
scen = read("tests/scenarios/Scenarios.ps1")
n = 0
for m in re.finditer(r"\(A '([^']+)' '[^']*' '([A-Z_]+)' @\{([^}]*)\} '(count|sum|value)'(?: '([A-Za-z]+)')?", scen):
    aid, table, where, agg, col = m.groups()
    n += 1
    if table not in cols_by_table:
        fails.append(f"assertion {aid}: unknown table {table}"); continue
    for k in re.findall(r"([A-Za-z]+)\s*=", where):
        if k not in cols_by_table[table]:
            fails.append(f"assertion {aid}: unknown filter column {table}.{k}")
    if col and col not in cols_by_table[table]:
        fails.append(f"assertion {aid}: unknown column {table}.{col}")
for m in re.finditer(r"\(ASum '([^']+)' '[^']*' '([A-Z_]+)' '([A-Za-z]+)' '([A-Za-z]+)'\)", scen):
    n += 1
    aid, table, a, b = m.groups()
    for c in (a, b):
        if c not in cols_by_table.get(table, set()):
            fails.append(f"assertion {aid}: unknown column {table}.{c}")
notes.append(f"tests: {n} assertions checked against schema")

# 6 ---------------------------------------------------------------- bracket balance (PowerShell lexing light)
def balance(text):
    stack, i, n = [], 0, len(text)
    pairs = {")": "(", "}": "{", "]": "["}
    line = 1
    while i < n:
        ch = text[i]
        if ch == "\n": line += 1
        if text.startswith("<#", i):
            j = text.find("#>", i + 2); line += text.count("\n", i, j); i = j + 2; continue
        if ch == "#":
            j = text.find("\n", i); i = n if j < 0 else j; continue
        if text.startswith("@'", i) or text.startswith('@"', i):
            q = text[i + 1]; j = text.find("\n" + q + "@", i + 2); line += text.count("\n", i, j); i = j + 3; continue
        if ch == "'":
            j = i + 1
            while j < n:
                if text[j] == "'" and j + 1 < n and text[j + 1] == "'": j += 2; continue
                if text[j] == "'": break
                j += 1
            line += text.count("\n", i, j); i = j + 1; continue
        if ch == '"':
            j = i + 1; depth = 0
            while j < n:
                if text[j] == "`": j += 2; continue
                if text.startswith("$(", j): depth += 1; j += 2; continue
                if depth and text[j] == ")": depth -= 1; j += 1; continue
                if text[j] == '"' and depth == 0:
                    if j + 1 < n and text[j + 1] == '"': j += 2; continue
                    break
                j += 1
            line += text.count("\n", i, j); i = j + 1; continue
        if ch == "`": i += 2; continue
        if ch in "({[": stack.append((ch, line))
        elif ch in ")}]":
            if not stack or stack[-1][0] != pairs[ch]:
                return f"unexpected '{ch}' at line {line}"
            stack.pop()
        i += 1
    return f"unclosed '{stack[-1][0]}' from line {stack[-1][1]}" if stack else None

ps_files = []
for d in ("src", "src/engine", "scripts", "tests", "tests/scenarios"):
    for f in sorted(os.listdir(os.path.join(ROOT, d))):
        if f.endswith((".ps1", ".psm1")): ps_files.append(f"{d}/{f}")
for f in ps_files:
    err = balance(read(f))
    if err: fails.append(f"brackets: {f}: {err}")
notes.append(f"syntax: bracket balance checked in {len(ps_files)} PowerShell files")

# 7 ---------------------------------------------------------------- secrets
for d, _, files in os.walk(ROOT):
    if "/." in d or "/results" in d: continue
    for f in files:
        if f.endswith((".ps1", ".psm1", ".json", ".md", ".py", ".m")):
            if re.search(r"shp(ss|at|ca|pa)_[A-Za-z0-9]{10,}", open(os.path.join(d, f), encoding="utf-8", errors="ignore").read()):
                fails.append(f"possible credential literal in {os.path.relpath(os.path.join(d, f), ROOT)}")

for n_ in notes: print("INFO ", n_)
for f in fails: print("FAIL ", f)
print(f"\nSTATIC CHECKS: {'PASS' if not fails else 'FAIL'} ({len(fails)} problem(s))")
sys.exit(1 if fails else 0)
