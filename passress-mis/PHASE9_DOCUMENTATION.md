# PASSRESS MIS — Phase 9 Reference: File-Corruption Hotfix

Triggered by real user testing, not a scheduled phase — the first time this
workbook was actually opened in Windows Excel, it needed a repair just to
load. This file documents the root cause, the fix, and the one new manual
step it adds to setup. Nothing in the workbook's structure, sheets, tables,
Power Query files, or DAX measures changed — this is a targeted correction
to which table name a set of existing formulas/named ranges point at.

---

## 1. The symptom

Opening `PASSRESS_MIS.xlsx` in Excel triggered: *"We found a problem with
some content in 'PASSRESS_MIS.xlsx'. Do you want us to try to recover as
much as we can?"* Clicking Yes, Excel's repair log read:

```
Excel was able to open the file by repairing or removing the unreadable content.
Removed Records: Named range from /xl/workbook.xml part (Workbook)
Removed Records: Formula from /xl/worksheets/sheet5.xml part
Removed Records: Formula from /xl/worksheets/sheet10.xml part
Removed Records: Formula from /xl/worksheets/sheet12.xml part
```

`sheet5.xml`/`sheet10.xml`/`sheet12.xml` correspond (confirmed against
`xl/_rels/workbook.xml.rels`) to `05_Products`, `10_Expenses`, and
`12_Suppliers` — exactly the three sheets whose SKU/Collection Data
Validation dropdowns are sourced from the `SKUList`/`CollectionTitleList`
named ranges.

## 2. Root cause

`SKUList` was defined as `=RAW_Variants[SKU]` and `CollectionTitleList` as
`=RAW_Collections[Title]` — pointing at the table names Power Query
creates *after* you delete the Phase 1 placeholder and wire the real query
(`DEPLOYMENT_GUIDE.md` §5). **Before that wiring happens, neither
`RAW_Variants` nor `RAW_Collections` exists anywhere in the file** — only
their placeholders, `tbl_RAW_Variants` and `tbl_RAW_Collections`, do.

This was a deliberate Phase 6 design choice, reasoned through at the time:
DAX measures already used the no-prefix, post-wiring convention, and
pointing worksheet formulas/named ranges at the same convention meant
nothing would need updating once Power Query was wired. The documented
risk was that these two named ranges (and a handful of worksheet formulas
sharing the same pattern) would resolve to a broken reference **until**
wiring was done — treated as an acceptable, disclosed "resolves once
wired" gap, the same category as every CUBEVALUE formula waiting on the
Data Model.

**What Phase 6 got wrong, only discoverable by testing in real Excel (this
sandbox has none):** a workbook-scoped *defined name* whose formula
references a table that doesn't exist **anywhere in the file** is not
merely "unresolved until refresh" the way a cell formula can be — Excel's
loader validates defined names against the file's actual table list at
*load time*, and a name it can't resolve gets silently stripped, along
with anything structurally dependent on it — in this case, the three
sheets' Data Validation dropdowns whose list source is that name. The
result is a file that needs a repair just to open, not a formula that
shows `#REF!` after a failed refresh — a categorically worse outcome that
the original "resolves once wired" framing didn't anticipate.

## 3. The fix

Every workbook-scoped named range and worksheet formula that reads a
`RAW_`/`DIM_`/`FACT_`/`LOG_` table now points at the **`tbl_`-prefixed
placeholder name** — guaranteed to exist in the file from the moment it's
generated, before any Power Query wiring happens. **DAX measures are
unaffected and unchanged** — they're evaluated inside the Data Model, a
separate object model that doesn't reference Excel Table objects the way
worksheet formulas and named ranges do, so this class of bug never applied
to them.

| Location | Reverted to |
|---|---|
| `SKUList` (named range) | `tbl_RAW_Variants[SKU]` |
| `CollectionTitleList` (named range) | `tbl_RAW_Collections[Title]` |
| `01_Home` Last Refresh / Data Quality cards | `tbl_LOG_RefreshHistory`, `OverallDataQualityPct` (unaffected) |
| `14_Data_Quality` KPI row (4 cards) | `tbl_LOG_RefreshHistory`, `tbl_LOG_DataQuality` |
| `14_Data_Quality`'s Data Quality Checks table (7 of 11 checks) | `tbl_RAW_Variants`, `tbl_RAW_Orders`, `tbl_RAW_Products`, `tbl_RAW_InventoryLevels`, `tbl_RAW_Transactions`, `tbl_LOG_DataQuality`, and **`tbl_DIM_Product`** (see §4 — a second, related finding) |
| `BI_Alerts` ALT-04, ALT-10, ALT-11 | `tbl_RAW_Variants`, `tbl_LOG_RefreshHistory`, `tbl_LOG_DataQuality` |
| `RPT_Workflow` Open Orders | `tbl_RAW_Orders` |

**Verification added to the build's own validation pass**: every workbook-
scoped defined name and every cell formula using `Table[Column]` syntax is
now checked against the actual list of tables that exist in the generated
file — zero mismatches confirmed after this fix (previously this specific
check didn't exist; the bracket-balance/XML-well-formedness checks run
since Phase 1 don't catch a *semantically* invalid table reference, only a
*syntactically* broken formula).

## 4. A second finding from the same check

The stricter validation also caught that `14_Data_Quality`'s "Missing
Supplier" check referenced `DIM_Product[PrimarySupplierID]` — and
`DIM_Product`, too, goes through the exact same placeholder-until-wired
lifecycle as `RAW_`/`LOG_` tables (`dax/README.md` Step 1: `tbl_DIM_Product`
is deleted and replaced by a live `DIM_Product` table once the Data Model
is built). This wasn't part of the original repair-log symptom (`DIM_`
tables weren't involved in the three flagged sheets), but is the same root
cause and was fixed the same way: `tbl_DIM_Product[PrimarySupplierID]`.

## 5. New required manual step

Because `SKUList`/`CollectionTitleList` now point at the placeholder name,
**you must manually repoint them once you actually wire `RAW_Variants`/
`RAW_Collections`** in Power Query — otherwise every SKU/Collection
dropdown keeps reading the (by-then-stale) placeholder table forever. Full
steps in `DEPLOYMENT_GUIDE.md` §5.4 (Name Manager → edit each name's
"Refers to" to drop the `tbl_` prefix, only after the real table exists).
This is the direct tradeoff for the file being valid and openable from the
moment it's generated: two named ranges need a one-time manual edit at the
right point in setup, clearly documented, instead of the file needing an
automatic repair before anyone can even open it.

No other formula in the workbook needs this manual step — every other
`RAW_`/`DIM_`/`FACT_`/`LOG_`-reading worksheet formula reads the
placeholder table directly by name (not through an intermediate named
range), so it simply keeps working, unchanged, once Power Query is wired
and the live table takes over the same name.

---

## 6. What this changes about "production-ready"

`PHASE7_FINAL_ARCHITECTURE_REVIEW.md` and `PHASE8_DOCUMENTATION.md` both
stand as written — this is a targeted correction, not a reversal of either
phase's findings. One addition worth carrying forward: **the "resolves
once wired" framing used throughout this workbook's documentation (Phases
2, 4, 5, 6) describes two genuinely different runtime behaviors that look
the same on paper but aren't**:

- A **cell formula** referencing an unwired table (CUBEVALUE waiting on
  the Data Model, or a worksheet `COUNTIFS` against a `tbl_`-prefixed
  placeholder) resolves to `0`/blank/an in-cell error — inert until wiring,
  never a file-integrity problem.
- A **defined name** referencing a table that doesn't exist anywhere in
  the file is a file-structure problem from the moment the file is
  generated, not from the moment someone calculates it.

Every defined name in this workbook has now been re-audited against this
distinction (§3's table); none remain in the second category.
