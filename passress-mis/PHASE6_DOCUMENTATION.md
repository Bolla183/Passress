# PASSRESS MIS — Phase 6 Reference: Operational Excellence & Production Readiness

Extends Phases 1-5 — nothing in the existing architecture, folder structure,
or repository paths changed. New hidden-sheet prefix: `RPT_` (printable
report pages, placed per your explicit choice: hidden, linked from
`01_Home`, right-click-Unhide as the guaranteed fallback).

---

## 1 & 2. Daily Executive Brief + Automated Daily Report — `RPT_ExecutiveBrief`

One sheet serves both requests rather than duplicating the same 13 metrics
onto two pages. Built print-ready from the start: A4 portrait, fit-to-page,
an explicit print area, no dropdowns or interactive elements anywhere in
the printable region.

| Item | Source |
|---|---|
| Revenue/Orders/Gross Profit/Margin Today | CUBEVALUE filtered to today (Year+Month+Day member intersection) |
| Cash Position, Inventory Value | Unfiltered (both are current-state measures already) |
| Revenue vs Yesterday | Today's Net Sales minus yesterday's, same filtering technique |
| Top 5 Products/Collections | The same CUBESET/CUBERANKEDMEMBER call `02_Partner_Dashboard` uses — called again here, not re-derived differently |
| Critical Alerts | Direct references to `BI_Alerts`' two Severity="Critical" rows (Negative Margin, Missing Shopify Sync) |
| Business Health Score | `=BusinessHealthScore` / `=BusinessHealthStatus` named ranges |
| Executive Commentary | Same curated 4 `BI_Insights` rows `02_Partner_Dashboard` shows |

**Scoped down from the literal brief:** "Biggest Increase/Biggest Decrease"
is a single Revenue-vs-Yesterday delta, not a per-product "biggest mover"
ranking — CUBESET can't cleanly cross a date filter with a ranking measure
without an MDX pattern too advanced to verify in this environment (see
`dax/README.md`'s note on filtered-CUBEVALUE confidence levels).

## 3. Business Health Score — `BI_HealthScore`

10 components, each a worksheet formula (not a DAX measure — two inputs,
Data Quality % and Alerts, live in worksheet tables outside the Data Model,
so a pure-DAX measure couldn't reach them cleanly):

| Component | Formula basis | Weight (default) |
|---|---|---|
| Revenue Growth | `[Revenue Growth % (YoY)]`, 0%→50, ±20%→0/100 | 15 |
| Gross Margin | `[Gross Margin %]` / `[Margin Target]` | 15 |
| Cash Position | `[Cash Position]` / `[Expense Budget (Period)]` (months of runway) | 15 |
| Inventory Health | `[Inventory Turnover]` / `[Inventory Turnover Target]` | 10 |
| Customer Growth | `[Customer Growth % (YoY)]` — new measure, same scaling as Revenue Growth | 10 |
| Repeat Customers | `[Repeat Customer % Actual]` / `[Repeat Customer % Target]` | 10 |
| Return Rate | `[Return Rate %]` — new measure, inverted (lower is better) | 10 |
| Budget Performance | `100 - \|[Expense Actual vs Budget]\| / [Expense Budget]` | 5 |
| Data Quality | `14_Data_Quality`'s `OverallDataQualityPct` named range | 5 |
| Alerts | `100 - (triggered count in BI_Alerts) × (100/12)` | 5 |

Total = weighted average (weights don't need to sum to 100 — the formula
divides by their actual sum). Status: Green > 75, Amber 50-75, Red < 50 —
adjust the thresholds directly in `BI_HealthScore`'s status formula if the
business wants different bands. Two new DAX measures
(`dax/PHASE6_MEASURES_ADDENDUM.md`): `Customer Growth % (YoY)` and
`Return Rate %`, both reused, not single-purpose.

## 4. Data Quality Dashboard — `14_Data_Quality` (expanded)

11 quantifiable checks + 1 marked N/A, appended below the sheet's existing
Phase 2 content. Prefers plain `COUNTIFS`/`SUMPRODUCT` against the live
`RAW_`/`DIM_`/`FACT_` tables over CUBEVALUE wherever possible — data
quality should be checkable as soon as Power Query refreshes, without
needing the full DAX layer wired first.

**Reused, not recomputed:** Missing Cost (`[Lines Missing Cost]`, Phase 4),
Duplicate Expenses (Phase 3's flag column), Refresh Failures
(`LOG_DataQuality`, Phase 2) — same checks `BI_Alerts` already surfaces,
referenced directly.

**Genuinely new:** Missing SKU, Missing Supplier (via `DIM_Product`'s
`PrimarySupplierID`), Duplicate Orders (an integrity check that should
always read 0), Products without Collection, Negative Inventory, Missing
Customer (expected nonzero for guest checkouts — the *rate* is the signal,
not any nonzero count), Missing Payment (an anti-join between `RAW_Orders`
and `RAW_Transactions`).

**Honestly marked N/A:** Products without Images. `RAW_Products.pq` never
fetched image data — it wasn't in Phase 2's original 10-resource scope, and
Phase 6 was told not to modify Phase 2's files. Adding an `images` field to
that GraphQL query is a clean, isolated future addition (documented as
such), not something to fake with a wrong answer today.

**Overall Data Quality %** = passing checks / quantifiable checks (excludes
the N/A row), registered as a named range so `BI_HealthScore` reads it
directly. **Historical Refresh Trend**: a native chart against
`LOG_RefreshHistory`'s own growing append-only log.

## 5. Workflow Dashboard — `RPT_Workflow`

One operational page spanning territory that doesn't belong to any single
existing sheet (Purchasing lives on 12_Suppliers, Capital on 11_Capital,
Expenses on 10_Expenses) — hence its own sheet rather than an append.
Purchase Orders/Open Orders/Pending Receipts/Inventory to Receive (reuses
Phase 3's own Remaining Quantity column), Supplier Status breakdown,
Capital Remaining and Outstanding Expenses (explicitly labeled reuses of
`[Cash Position]` and `[Accounts Payable (Proxy)]` — not new concepts under
new names), and a 12-month Monthly Purchasing trend chart.

## 6. Financial Calendar — `DIM_Date.pq` (extended)

Three new columns only — `IsWorkingDay`, `IsHoliday`, `HolidayName` — every
existing column from Phase 4 unchanged. Holidays come from a new, **empty
by default** table (`tbl_Holidays`, 15_Settings) — no holidays are assumed
or fabricated; populate it with the business's actual closure dates.
`IsWorkingDay` defaults to Mon-Fri minus any listed holiday.

**Fiscal Year, Calendar Year, MTD, QTD, YTD, Rolling 12 Months, Previous
Year, Same Period Last Year all needed zero new work** — Phase 4's DAX
time-intelligence layer (`TOTALMTD`/`TOTALQTD`/`TOTALYTD`/
`DATESINPERIOD`/`SAMEPERIODLASTYEAR`) and `DIM_Date`'s existing
`FiscalYear`/`FiscalQuarter` columns already cover every one of these —
documented here explicitly so nobody rebuilds what already exists.

## 7. Drill-through Experience

Real hyperlinks (`add_drill_link()`), not simulated: Partner Dashboard's
Revenue card links to `04_Sales`; CEO Dashboard's Sales/Customer/Inventory/
Profitability/Expense sections link to their matching detail sheets.
**Honestly scoped:** this is link-based navigation between summary pages,
not interactive OLAP drill-through (right-click a PivotTable cell → Show
Details) — that needs real PivotTables, which don't exist yet. The
documented full path (Revenue Card → Monthly Sales → Order Details → Order
Lines → Customer → Product) is the intended eventual experience once
Phase 7+ builds those PivotTables against this same Data Model; the target
sheets already exist and won't need to change, only how you reach them
does.

## 8. Dashboard Performance

See `PHASE6_PRODUCTION_READINESS_REVIEW.md` §3 for the full pass — summary:
five real bugs found and fixed (wrong table names in dropdown/alert
formulas), no unnecessary duplicate CUBE calls introduced this phase
(`fn_GetEffectiveCost`-style single-resolution discipline maintained
throughout: `BI_HealthScore`'s alert count reads `BI_Alerts` once per
formula, trend tables compute each month's value once), and one specific,
documented scaling concern (`FACT_InventoryMovements`' snapshot-append
pattern grows unbounded — flagged, not silently left).
