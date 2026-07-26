# PASSRESS MIS — Phase 8 Reference: Completing the Placeholder Inventory

Your instruction: complete every remaining placeholder (KPI card, chart,
"PivotTable"/table, report section) using only the existing Power Query
layer, Data Model, DAX measures, and workbook tables — no new business
features, KPIs, dashboards, worksheets, or architecture. This file is both
the "what changed" record (matching every prior phase's own documentation
pattern) and the required deliverable from your instruction's item 5: a
scan confirming zero completable placeholders remain, plus the full list of
what genuinely can't be built from what already exists, and exactly why.

**Architecture unchanged**: same 15 visible + 43 hidden sheets, same tables,
same Power Query files, same DAX measures, same naming/color conventions.
Every addition below reads an *existing* measure/table through the *same*
CUBEVALUE/CUBESET/CUBERANKEDMEMBER mechanism Phase 5 established (still the
only way to get live Data Model numbers onto a cell without a real
PivotTable, which openpyxl still cannot write — unchanged since Phase 1),
or a plain worksheet formula that already exists verbatim elsewhere in the
workbook (e.g. `RPT_Workflow`'s own Active Supplier count).

---

## 1. What was implemented

### 1.1 Six generic dashboard sheets — full rebuild of their placeholder content

`04_Sales`, `05_Products` (dashboard half), `06_Customers`, `07_Inventory`,
`08_Finance` (dashboard half), `09_Profitability`, `13_Marketing` — every
KPI card, chart, and "PivotTable" placeholder that maps to an existing
measure now does real work:

| Sheet | KPI cards wired | Chart | "PivotTable" substitutes wired |
|---|---|---|---|
| `04_Sales` | Gross Sales, Discounts, Returns, Net Sales (all 4) | Net Sales trend (12mo) | Sales by Product, Sales by Collection (breakdown tables) |
| `05_Products` | Best Seller, Avg Margin %, Slow Movers (3 of 4) | Top 10 Products (bar chart) | Product Margin (breakdown table) |
| `06_Customers` | New Customers, Repeat Rate %, Avg LTV (3 of 4) | — (see §2) | Top Customers, Geography (breakdown tables) |
| `07_Inventory` | Inventory Value, Inventory Turns (2 of 4) | Average Inventory Value trend | Stock by Location, Low Stock List, Inventory Valuation (breakdown tables) |
| `08_Finance` | Net Sales, Total Expenses, Net Profit, Cash Balance (all 4) | P&L Trend (3-series: Net Sales/Opex/Net Profit) | P&L Statement, Cash Flow Statement (full measure-map statements) |
| `09_Profitability` | Gross Margin %, Best Margin Category, Worst Margin Category (3 of 4) | Gross Margin % trend | Margin by Product, Margin by Collection (breakdown tables) |
| `13_Marketing` | Total Discount Given (1 of 4) | Discounts trend | — (see §2) |

**Mechanism notes:**
- **Breakdown tables** (Sales by Product, Margin by Collection, Stock by
  Location, etc.) are a new small helper, `add_cube_breakdown_table` —
  a direct generalization of Phase 5's `add_cube_top_n` (same CUBESET +
  CUBERANKEDMEMBER + CUBEVALUE trio) to more than one measure column per
  row. Not a new mechanism, the same one applied more than once per table.
- **"Best/Worst" name-only cards** (Best Seller, Best/Worst Margin
  Category) use `add_cube_rank1_name`, the exact fix pattern Phase 7
  applied to `BI_Insights`' Best/Weakest Seller bug — a CUBESET helper cell
  (ordered by an existing measure) feeding CUBERANKEDMEMBER's rank 1.
- **P&L Statement / Cash Flow Statement** are `dax/MEASURES.md` §1 and §3's
  own documented measure-to-line maps, turned into working CUBEVALUE
  formulas — literally transcribing prose that already existed, not new
  logic.
- **Charts** are native openpyxl `LineChart`/`BarChart` objects (both fully
  writable, unlike a PivotChart) referencing CUBEVALUE-populated helper
  cells — the same pattern every dashboard chart has used since Phase 5.
- **`Stock Trend` deliberately uses `[Average Inventory Value]`, not
  `[Inventory Value]`**: `dax/MEASURES.md` §6 documents that `[Inventory
  Value]` always returns the most recent snapshot regardless of any date
  filter — charting it by month would repeat the same "today" figure 12
  times. `[Average Inventory Value]` is the measure documented as
  date-filter-aware, so it's the one that produces a real trend. Caught
  during this phase's own review, not shipped as a misleading flat line.

### 1.2 Three manual-entry sheets — KPI cards completed too

`10_Expenses`, `11_Capital`, `12_Suppliers` shipped with static "—"
placeholder KPI cards since Phase 3 (outside the generic dashboard loop,
so Phase 7's own sweep missed them — caught in this phase's fuller scan):

| Sheet | Wired | Source |
|---|---|---|
| `10_Expenses` | Budget Variance | `[Expense Actual vs Budget]` (existing measure) |
| `11_Capital` | Capital Invested, Owner Withdrawals, Net Owner Equity | `[Capital Invested (Cumulative)]`, `[Capital Withdrawals (Period)]`, `[Equity]` (existing measures) |
| `12_Suppliers` | Active Suppliers, Open POs, Outstanding Receipts | Reuses `RPT_Workflow`'s own existing formulas verbatim (`COUNTIFS(tbl_SupplierMaster[Status],"Active")`, `SUM(tbl_GoodsReceipt[Remaining Quantity])`) and the same "not Closed, not Cancelled" filter `[Accounts Payable (Proxy)]` already defines for open commitments |

### 1.3 Row-level "detail" placeholders — link-based, not recomputed

`Order List` (04_Sales) and `Variant Detail` (05_Products) asked for
row-level, non-aggregated data (individual orders; individual SKU
attributes). CUBE functions rank/aggregate dimension members by a measure
— they can't display raw per-row columns the way a PivotTable's row area
can, and there's no Order-level dimension in the Data Model to browse in
the first place. Rather than leave a placeholder or fabricate a workaround,
both now carry a real hyperlink (`add_drill_link`, the same mechanism
Phase 6 built for dashboard drill-through) straight to the real underlying
table (`RAW_Orders`, `DIM_Product`) — the actual full data, one click away,
not duplicated onto a second sheet.

---

## 2. Remaining placeholders — full list with the exact technical reason

Every one of these was evaluated against `dax/MEASURES.md` and both
addenda, `dax/README.md`'s relationship list, and every existing worksheet
formula elsewhere in the workbook, looking specifically for something
*already existing* to reuse. None were found. Each reason below is visible
in the workbook itself (a comment-style "Not implementable: ..." box for
charts/pivots, a "Known Gaps on this sheet" note for KPI cards) — not only
in this file.

### 2.1 No existing DAX measure covers this concept (13 KPI cards)

| Sheet | Card | Why no existing measure fits |
|---|---|---|
| `05_Products` | Active SKUs | No `DISTINCTCOUNT(DIM_Product[SKU])`-style measure exists — Product Profitability (§4) covers profit *per* SKU via PivotTable context, never a SKU-count aggregate. |
| `06_Customers` | Total Customers | `[Customers Active (Current Period)]` is period-filtered, `[New Customers]` is first-order-in-period — neither is an all-time roster count, and mapping to either would misrepresent what it measures. |
| `07_Inventory` | Units on Hand | Every Inventory Metrics (§6) measure is value- or ratio-based; none sums `FACT_InventoryMovements[ResultingOnHand]` as a plain unit count. |
| `07_Inventory` | Stockout Risk | No measure or business-rule threshold exists for "high sales velocity vs. low remaining stock" — the inverse of the existing Slow Moving/Dead Stock logic, but never built. |
| `09_Profitability` | Contribution Margin % | Distinct concept from `[Gross Margin %]` (variable-cost-only vs. COGS-only) — this model doesn't split Operating Expenses into fixed/variable, so there's no correct way to compute it from what exists. |
| `10_Expenses` | Expenses MTD | Time-intelligence pattern (§8) was only instantiated for Net Sales/Gross Profit/Net Profit/Order Count — never extended to Operating Expenses, though the pattern to do so is documented. |
| `10_Expenses` | Expenses YTD | Same as above. |
| `10_Expenses` | Largest Category | Expense Category is a plain text column on `FACT_ManualExpenses`, not a Data Model dimension with its own hierarchy — CUBESET/CUBERANKEDMEMBER can only rank an actual dimension's members. |
| `11_Capital` | YTD Movement | `[Capital Invested (Cumulative)]` is all-time since inception; no YTD-filtered variant of `[Net Capital (Period)]` exists. |
| `12_Suppliers` | Purchases YTD | No YTD variant of `[Cash Paid for Purchases]` exists — reimplementing one as a raw worksheet SUMIFS would be new logic, not reuse. |
| `13_Marketing` | Active Campaigns | No Campaign dimension exists — the Marketing-Ready Layer is deliberately unconnected (Phase 5's own explicit scope). |
| `13_Marketing` | Discount Rate % | `[Discounts]` and `[Gross Sales]` both exist individually, but their ratio was never defined as a named, reusable measure. |
| `13_Marketing` | ROAS (future) | Self-documented as future since Phase 1 — needs ad spend data from the same unconnected Marketing-Ready Layer. |

### 2.2 No Data Model dimension exists for this breakdown (2 items)

| Sheet | Item | Reason |
|---|---|---|
| `13_Marketing` | Campaign Performance (PivotTable) | No Campaign dimension — same root cause as Active Campaigns above. |
| `13_Marketing` | Discount Code Usage (PivotTable) | `RAW_Discounts` (Power Query staging) holds the raw data, but was never built into the star schema in Phase 4 — no `DIM_`/`FACT_` table, no Data Model relationship, no DAX measure reads it. Linked directly (`add_drill_link` to `RAW_Discounts`) as the closest honest substitute. |

### 2.3 Row-level detail — not expressible via CUBE functions (2 items)

| Sheet | Item | Reason |
|---|---|---|
| `04_Sales` | Order List (Table) | No Order-level dimension in the Data Model — CUBE functions browse dimension *members* (Product/Collection/Customer/Location/Date), never individual fact rows. Linked to `RAW_Orders` instead. |
| `05_Products` | Variant Detail (PivotTable) | SKU/variant attributes (Price, Compare-at Price, Unit Cost, Status) are row-level data, not aggregate measures. Linked to `DIM_Product` instead. |

### 2.4 Tooling/verification limitation, not missing data (1 item, 2 placeholders)

| Sheet | Item | Reason |
|---|---|---|
| `06_Customers` | Cohort Trend (Chart) + Cohort Table (PivotTable) | `dax/MEASURES.md` §5 explicitly documents Customer Cohorts as a **PivotTable layout** (`DIM_Customer[CohortMonth]` × `DIM_Date[MonthName]/[Year]`), not a single measure — the underlying data (`CohortMonth`) *does* exist, but reproducing a true 2-dimensional matrix via CUBE functions would need nested CUBESET/CUBEVALUE expressions per cohort-month × calendar-month intersection, the same class of advanced, execution-untestable MDX pattern already flagged as a confidence risk in `dax/README.md` and Phase 5/6's documentation. Not attempted rather than shipped unverified — this is the one case in this phase where the blocker is tooling risk, not missing data or a missing measure. |

### 2.5 Reserved, unconnected by earlier phases' own explicit scope (unchanged, not re-litigated)

`RAW_MetaAds`/`RAW_GoogleAnalytics`/`RAW_GoogleAds`/`RAW_TikTokAds`/
`RAW_EmailMarketing`/`RAW_InfluencerCampaigns`/`FACT_MarketingSpend`
(Marketing-Ready Layer) and `FUTURE_AI_Insights` remain exactly as Phase 5
built them: reserved, empty, no API calls. Connecting them requires new
external credentials and a new ETL/AI integration — categorically a new
feature, not a placeholder completable from what already exists. Not
touched this phase, consistent with every prior phase's treatment of them.

---

## 3. Second full workbook scan — confirmation

Ran after all fixes, against the rebuilt workbook:

- Grep for `"placeholder"`, `"not yet built"`, `"coming soon"`, `"built in
  phase"` across every cell value in all 58 sheets: **21 hits, all
  legitimate** — 3 are Version Log narrative text (describing what past
  phases built, not a live gap), 5 are `DIM_*` sheets' routine "built in
  Phase 2" doc-block prose (descriptive, not a marker of missing work), 13
  are the Marketing-Ready Layer / `FUTURE_AI_Insights` sheets' own
  "RESERVED, NOT CONNECTED" / "RESERVED, NOT IMPLEMENTED" headers (§2.5,
  unchanged, deliberately out of scope). **Zero hits point at a completable
  gap that was missed.**
- Static `"—"` em-dash placeholder cells (the Phase 1 unwired-KPI-card
  marker): **0 remaining** (was 12 before this phase's second pass caught
  `10_Expenses`/`11_Capital`/`12_Suppliers`).
- `add_placeholder_box(` call sites (the old generic "Placeholder, built in
  Phase X" box): **0 remaining** — every call site was replaced with either
  a real implementation or `add_gap_box` (which states the specific reason,
  not a phase number).
- Structural validation: zip integrity OK, 0 XML errors, 72/72 tables in
  bounds, 0 named-range issues, 0 formula bracket-balance issues, 9 native
  charts present (up from 3 before this phase).

**Zero placeholders remain that could have been implemented with the
existing architecture.** Everything still showing "N/A" or a "Not
implementable" box is listed in §2 above with its specific technical
reason, visible both in this file and directly in the workbook.
