# PASSRESS MIS — Phase 5 Reference: BI Application Layer

Extends Phases 1-4 — nothing in the existing architecture was changed.
New hidden-sheet prefixes: `BI_` (Insights/Alerts/Forecast — system-
generated, dashboard-facing) and `FUTURE_` (reserved, unimplemented),
alongside the existing `RAW_`/`DIM_`/`FACT_`/`LOG_`.

---

## The mechanism: CUBEVALUE instead of PivotTables

Real Excel Slicers need a PivotTable/PivotCache to attach to, and openpyxl
has no reliable way to write either. Instead, every live number on
`02_Partner_Dashboard` and `03_CEO_Dashboard` uses `CUBEVALUE` (a single
measure), `CUBESET`+`CUBERANKEDMEMBER` (a ranked Top-N list), or a plain
formula reading a DAX measure into a cell — all standard Excel functions
that read the Data Model directly, no PivotTable required. Combined with
native openpyxl line charts (which *are* well-supported — a chart
referencing a plain cell range, unlike a PivotChart), this means the
dashboards actually work once the Data Model is wired (`power-query/
README.md` + `dax/README.md`), not just structurally present.

**Until that wiring is done, every card shows 0 and the chart is flat** —
expected, not an error, the same "resolves once wired" caveat as Phase 2's
M code and Phase 4's DAX.

**Two classes of formula, two confidence levels:**
- Unfiltered `CUBEVALUE("ThisWorkbookDataModel","[Measures].[X]")` — the
  simplest, most standard CUBE-function pattern, used for every KPI card.
  High confidence.
- Filtered CUBEVALUE (the trend tables' Year+Month member expressions,
  e.g. `"[DIM_Date].[Year].&["&YEAR(...)&"]"`) and `CUBESET`/
  `CUBERANKEDMEMBER` — more advanced MDX-over-Tabular patterns that
  **could not be execution-tested** in this environment (no Excel/Power
  Pivot engine available, same limitation noted for every prior phase's
  M/DAX). Spot-check these first once the Data Model is live — Excel's
  formula-bar autocomplete for CUBE functions is the fastest way to
  confirm exact member-expression syntax interactively if one doesn't
  resolve as expected.

---

## 1. Executive Commentary Engine — `BI_Insights`

Hidden sheet, 8 auto-generated insights (`INS-01`..`INS-08`), each a
CUBEVALUE-built sentence: Sales vs. last year, Margin vs. target, Retention
rate, Inventory turnover vs. target, Cash position health, Best/weakest
seller, AOV vs. target. `02_Partner_Dashboard` shows a curated 4 (`INS-01`,
`02`, `05`, `06`); `03_CEO_Dashboard` shows all 8. Both dashboards reference
`BI_Insights`' cells directly (`='BI_Insights'!D15`, etc.) rather than
re-deriving the CUBE formulas — the sentence is computed once, displayed
twice.

## 2. KPI Target Management — `tbl_KPITargets` (15_Settings)

10 rows (green `Target Value` editable, everything else reference/locked):
Sales, Margin, Orders, Inventory, Inventory Turnover, AOV, CAC, ROAS,
Repeat Customer %, Conversion Rate. `dax/PHASE5_MEASURES_ADDENDUM.md` has
`LOOKUPVALUE`-based `[<KPI> Target]` measures reading this table, plus
Variance/Attainment measures for every target that has a real Actual
measure. **CAC, ROAS, and Conversion Rate targets exist and are editable
now, but have no Actual counterpart yet** — CAC/ROAS need ad spend data
(Marketing-Ready Layer, unconnected) and Conversion Rate needs storefront
traffic data the Shopify Admin API doesn't expose. Documented on the table
itself (Notes column), not silently missing.

## 3. Alerts Engine — `BI_Alerts`

12 alerts (`ALT-01`..`ALT-12`), covering every type requested: Low
Inventory, Negative Margin, Products without Cost, Products without SKU,
Expenses without Category, Duplicate Expenses, Inactive Products, Slow
Moving Inventory, Dead Stock, Missing Shopify Sync, Refresh Errors, Over
Budget Expenses. **Reuses, doesn't duplicate**, existing checks: "Products
without Cost" reads `[Lines Missing Cost]` (Phase 4's own reconciliation
measure), "Duplicate Expenses" reads Phase 3's `Possible Duplicate` flag
column directly, "Refresh Errors" reads Phase 2's `LOG_DataQuality`
`Status` column. `14_Data_Quality` and `03_CEO_Dashboard` both surface
these.

## 4. Budget Module — `tbl_Budget` (08_Finance)

Below 08_Finance's Phase 1 placeholders, same append pattern as Phase 3's
Product Cost Master on 05_Products. One table, two grains: a row with
`Month` blank is a **yearly** budget line for that Year+Category; a row
with `Month` filled is **monthly**. Categories: Revenue, Expense,
Marketing, Purchasing, Profit (editable lookup, 15_Settings). DAX
(`PHASE5_MEASURES_ADDENDUM.md`): `[<Category> Budget (Period)]`,
`[<Category> Actual vs Budget]` for Revenue/Expense/Purchasing/Profit, and
`[Revenue Forecast vs Budget]`. **Marketing Actual vs Budget doesn't
exist** — same gap as CAC/ROAS: no Actual Marketing Spend measure until
`FACT_MarketingSpend` is connected.

## 5. Forecast Module — `BI_Forecast`

Five metrics (Sales, Expenses, Profit, Inventory, Cash), each: a
CUBEVALUE-pulled trailing-12-month actuals row, then a `FORECAST.LINEAR`
projection one period ahead. Deliberately simple (linear trend, no
seasonality) so it's auditable. The `Method` column
(`"Linear Trend (FORECAST.LINEAR)"`) is the one thing "allow future
replacement with AI forecasting" asked for structurally — a future phase
swaps that column's formula for an external forecasting call; `Metric`,
`ForecastPeriod`, `ForecastValue` stay the same shape so nothing downstream
(03_CEO_Dashboard's Forecast section reads `BI_Forecast!E37`..`E41`
directly) has to change.

## 6. Marketing-Ready Layer

6 reserved, **unconnected** hidden tables — `RAW_MetaAds`,
`RAW_GoogleAnalytics`, `RAW_GoogleAds`, `RAW_TikTokAds`,
`RAW_EmailMarketing`, `RAW_InfluencerCampaigns` — each `[DateKey,
CampaignID, CampaignName, Spend, Impressions, Clicks, Conversions,
Currency]`, plus a unified `FACT_MarketingSpend` they'd roll into. No API
calls, no credentials, no scheduled refresh — structurally identical to
how Phase 1 first sketched the Shopify `RAW_` tables before Phase 2
connected them for real. Connecting any of these later should follow
`power-query/README.md`'s exact pattern (`Extension.CurrentCredential`,
paginated fetch, incremental refresh).

## 7. Dashboard Navigation

`01_Home`'s clickable nav-card grid (Phase 1) was already there. New this
phase: `title_bar()` (used by every sheet) now makes the breadcrumb row
itself a hyperlink back to `01_Home` — one small, low-risk change to a
shared helper rather than touching all 15 visible sheets individually. The
breadcrumb text ("PASSRESS MIS | Home ▸ *SheetName*") doubles as the "Back
to Home" button the brief asked for.

## 8. Dashboard Filters — `01_Home`'s Global Filters panel

7 named, orange (editable) cells: `FilterDateFrom`, `FilterDateTo`,
`FilterCollection`, `FilterSKU`, `FilterSupplier`, `FilterLocation`,
`FilterCampaign` (the last marked reserved — no Campaign dimension exists
until Marketing-Ready connects). Three have live dropdown validation
against real Data Model lists (`CollectionTitleList`, `SKUList`,
`SupplierNameList`). **Deliberate scoping call:** the dashboards' own KPI
cards do NOT read these filter cells yet — they use robust unfiltered
CUBEVALUE instead, since building filtered member expressions into every
card risked making the core numbers fragile on formulas that couldn't be
tested. The cells exist, named and ready, for either manual CUBEVALUE
filtering today or native Slicers once real PivotTables exist (Phase 6) —
that's the intended upgrade path, not a redesign.

## 9 & 10. Partner Dashboard & CEO Dashboard

Both fully rebuilt (their Phase 1 generic placeholder content is gone,
replaced — the two sheets this phase's brief explicitly asked to design).

**Partner** (`02_Partner_Dashboard`): 5 KPI cards (Revenue, Net Profit,
Margin %, Cash Position, Orders), one native line chart (12-month Net Sales
trend), a live Top 5 Products list (CUBESET/CUBERANKEDMEMBER by Net Sales),
4 curated Key Insights. Nothing else — no operational detail, per the
brief.

**CEO** (`03_CEO_Dashboard`): 6 KPI-card sections (Financial, Sales,
Customer, Inventory, Profitability, Expense Analysis — 4 cards each) plus
reference tables for Budget (Actual/Budget/Variance, 4 categories), Forecast
(5 metrics from `BI_Forecast`), Alerts (all 12 from `BI_Alerts`), and all 8
Business Insights.

## 11. Dashboard Design

Reuses Phase 1's established system rather than inventing a new one: black/
white/gray chrome, dark-gray KPI cards, Segoe UI throughout, the five
input-standard colors for anything editable. Both dashboards are landscape,
fit-to-width, with an explicit print area (`set_print_friendly()`) so PDF
export doesn't spill columns or cut off mid-card.

## 12. AI-Ready Architecture — `FUTURE_AI_Insights`

One hidden table, 4 columns (`FeatureName`, `Status` = "Not Implemented"
for every row, `Description`, `WouldReplaceOrEnrich`), one example row
(Executive Summary). Inventories the 7 features the brief named (Executive
Summary, Daily/Weekly/Monthly Summary, Recommendations, Anomaly Detection,
Natural Language Q&A) as a checklist, not a working feature — deliberately
the thinnest table in the workbook, matching "No implementation yet."

---

## What's still deliberately missing

Native Excel Slicers (need real PivotTables — Phase 6). Actual/Marketing
comparisons for CAC/ROAS/Conversion Rate/Marketing Budget (need connected
ad-platform data — Marketing-Ready Layer is reserved, not live). AI
features of any kind (Phase 12's own scope: architecture only). A true
running-balance Remaining Quantity on Goods Receipt (carried over from
Phase 3, unchanged). Everything else requested this phase is built and
either live now (once the Data Model is wired) or clearly labeled as a
documented, reasoned gap — never silently assumed.
