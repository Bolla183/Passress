# PASSRESS MIS — Phase 7 Final Architecture Review

Phase 7 deliverable, item 13. Scope per your instruction: identify remaining
technical debt, performance bottlenecks, scalability limits, security
improvements, and a future migration path to SQL Server and Power BI. No
architecture redesign, no new features beyond fixing genuine production
issues found during review (catalogued in §1.1).

This review builds on, and does not repeat, `PHASE6_PRODUCTION_READINESS_
REVIEW.md`'s own architectural review — where a Phase 6 finding still
stands unchanged, it's referenced, not re-argued.

---

## 1. Remaining Technical Debt

### 1.1 Bugs found and fixed this phase

A full line-by-line re-read of `scripts/build_workbook.py` (2,300+ lines),
every Power Query shared function and a representative sample of staging/
star-schema queries, and both DAX measure files, surfaced five real defects
— all fixed, none requiring a new feature or architectural change:

| # | Defect | Impact if left unfixed |
|---|---|---|
| 1 | `BI_Alerts` ALT-10's formula contained a literal, non-functional placeholder token (`COUNTROWS_PLACEHOLDER`) that a later code block silently overwrote with the real formula — functionally correct in the final output, but fragile and confusing (a formula that reads as broken until you find the override 15 lines later). | Not a live bug (the override always ran), but a maintenance trap — a future edit to the override block, or its accidental removal, would have shipped a genuinely broken alert with no obvious sign. Simplified to a single correct formula, no override. |
| 2 | `14_Data_Quality`'s Historical Refresh Trend chart referenced `LOG_RefreshHistory` starting at row 13, but that table's first real data row is row 12 (header on row 11, per every hidden sheet's standard `doc_block` layout). | The chart silently dropped the very first logged refresh from its trend line — a genuine, if minor, off-by-one. Fixed. |
| 3 | `BI_Insights`' INS-06 ("Best seller") and INS-07 ("Weakest seller") both called `CUBERANKEDMEMBER` against a **raw, unordered** MDX set expression (`{[DIM_Product].[Title].Children}`) instead of a `CUBESET`-defined ranked set. An unordered set has no defined "rank 1," and both insights used the *identical* expression — so once the Data Model is wired, "Best seller" and "Weakest seller" would have displayed the exact same (arbitrary) product every time. | Two of eight executive insights silently non-functional (duplicate, not derived from sales data at all) from the moment Phase 5 shipped through today. Fixed using the same `CUBESET` + `CUBERANKEDMEMBER` pattern already used correctly everywhere else in the workbook (`add_cube_top_n`) — a `BDESC`-by-`[Net Sales]` set for Best, `BASC` for Weakest. |
| 4 | `01_Home`'s "Last Refresh" and "Data Quality" KPI cards were left as static Phase 1 "—" placeholders through every subsequent phase, despite that sheet's own `doc_block` explicitly promising since Phase 1 that they "read workbook status from LOG_RefreshHistory and LOG_DataQuality." | The single most-viewed page in the workbook permanently showed two non-functional cards, contradicting its own documentation — a direct hit on "every KPI matches its source" (this phase's own validation charge, item 7). Wired to `MAX(LOG_RefreshHistory[Timestamp])` and the existing `OverallDataQualityPct` named range respectively — no new measures, reuses what Phase 6 already built. |
| 5 | `14_Data_Quality`'s own KPI row (Last Refresh, Rows Loaded, Errors Found, Data Freshness) had the identical gap — static placeholders on the one sheet that exists specifically to surface refresh health. | Same root cause and same fix pattern as #4 — wired to `LOG_RefreshHistory`/`LOG_DataQuality`, reusing the same WARNING-status check `BI_Alerts` (ALT-11) and `tbl_DataQualityChecks`' Refresh Failures row already use. |

All five fixes are in `scripts/build_workbook.py`, each with an inline
comment explaining the defect and the fix, consistent with how Phase 6's
own five-bug finding was documented in place rather than only in prose.

### 1.2 Known, deliberately unbuilt scope: six generic dashboard sheets

`04_Sales`, `06_Customers`, `07_Inventory`, `09_Profitability`,
`13_Marketing`, and the dashboard (non-Product-Cost-Master /
non-Budget) portions of `05_Products` and `08_Finance` still show static
Phase 1 KPI-card placeholders ("—") and chart/PivotTable placeholder boxes.

**This was considered and deliberately left alone this phase**, for three
reasons:

1. **No phase ever commissioned it.** Phase 4's own brief explicitly said
   "do not build dashboards, PivotCharts, or KPI cards yet." Phase 5 named
   only `02_Partner_Dashboard` and `03_CEO_Dashboard` for a bespoke rebuild.
   Phase 6 named specific new deliverables (Executive Brief, Health Score,
   Workflow Dashboard, Data Quality expansion) but not these six sheets.
   This is unbuilt scope, not a regression.
2. **Wiring their KPI cards properly would require inventing new DAX
   measures** that don't exist anywhere in `dax/MEASURES.md` or its
   addenda — "Active SKUs," "Contribution Margin %," "Stockout Risk,"
   "Active Campaigns," "Discount Rate %," and others have no defined
   measure today. Your Phase 7 instruction was explicit: "Do not add new
   features... unless they are required to fix a production issue." A
   dashboard nobody built is not, on its own, a production issue in the
   same sense as a broken formula — it's disclosed missing scope, and
   inventing new business logic to fill it in would be exactly the kind of
   unrequested feature addition you asked me not to do.
3. **A half-fix would be worse than the honest placeholder.** Wiring only
   the KPI labels that happen to map cleanly to an existing measure
   (`04_Sales`'s four cards all map directly — Gross Sales, Discounts,
   Returns, Net Sales) while leaving others static would produce an
   inconsistent page that looks finished but isn't, which is a worse
   production-readiness state than a page that's honestly, uniformly
   unbuilt.

**What I did fix**: the placeholder box label text previously read
"Placeholder, built in Phase 4" — accurate when Phase 4 was still upcoming,
actively wrong now that Phase 4 (and 5 and 6) have all already happened
without building it. Changed to a phase-neutral, accurate label pointing at
`dax/README.md` for the manual PivotTable/chart build steps once someone
does take this on (see §5 for why openpyxl can't build the PivotTable
itself, unchanged since Phase 1).

**Recommendation**: if these six sheets need to go live, that's squarely a
"Phase 8" scope decision for you to make explicitly — not something to
infer from a "production readiness" instruction, given how clearly every
prior phase's brief scoped it out on purpose.

### 1.3 Circular dependencies — reconfirmed, none found

Re-verified this phase, not just carried forward from Phase 6: traced every
reference direction across `BI_HealthScore` (the most interconnected
sheet — reads the Data Model, `14_Data_Quality`, and `BI_Alerts`) and
confirmed nothing reads back into it from any of its own inputs. This
remains structurally impossible, not just untested, because the Data Model
has no mechanism to read worksheet cells — a CUBEVALUE formula can only
flow one direction (Data Model → worksheet).

### 1.4 Other known limitations (carried forward, still accurate)

Everything `PHASE6_PRODUCTION_READINESS_REVIEW.md`'s "Known limitations"
list already disclosed remains accurate and is not re-verified line by line
here: Mac Power Pivot incompatibility, no multi-currency support, no
multi-location dashboard filtering, CAC/ROAS/Conversion Rate/Marketing
Budget Actuals blocked on unconnected ad-platform data, link-based (not
OLAP) drill-through, `FACT_InventoryMovements`/`LOG_*` unbounded growth
(revisited with more detail in §2.3), untested filtered-CUBEVALUE/CUBESET
formulas, and the N/A "Products without Images" check.

---

## 2. Performance Bottlenecks & Testing

### 2.1 What could and couldn't be tested here

No Excel or Power Pivot engine exists in this environment — true at every
phase since Phase 2, still true now. Nothing in this review is a timed
benchmark; it's a static analysis of formula/query shape. First real
refresh against production data remains the actual performance test — see
`OPERATIONS_MANUAL.md` §5 for what to watch for when that happens.

### 2.2 Power Query layer — this phase's audit

Reviewed all five shared functions in full and a representative cross-
section of staging queries (`RAW_Orders`, `RAW_Products`, `Orders_Source`,
`RAW_Transactions`, `RAW_Refunds`, `LOG_RefreshHistory`) plus
`fn_GetEffectiveCost`.

**Solid, no changes needed:**
- `fn_ShopifyGraphQL` — retries transient 5xx with exponential backoff
  (2s/4s/8s/16s), retries 429 using Shopify's own `Retry-After` header,
  handles Shopify's cost-based throttle by waiting for the point bucket to
  refill, raises three distinct, actionably-worded error types
  (`Shopify.AuthError`/`GraphQLError`/`HttpError`).
- `fn_ShopifyPagedConnection` — automatic pagination with a hard
  `Param_MaxPages` termination guarantee; correctly handles an empty
  connection (zero orders/products) as an empty list, not an error.
- `fn_IncrementalWindow` — correct first-run-vs-subsequent-run branching,
  a defensible "always re-check the last N days" design over a fragile
  stored high-watermark.
- `fn_AppendLog` — the append-only log pattern, with its real limitations
  (no partial-write recovery, full-history recombine on every refresh)
  already disclosed in its own header rather than hidden.

**One documented, low-severity finding — not fixed this phase:** several
staging queries (`RAW_Orders`, `RAW_OrderLines`, `RAW_Refunds`,
`RAW_Transactions`) extract Shopify `MoneyBag` fields
(`totalPriceSet.shopMoney.amount` and similar) without a `try...otherwise`
wrapper, while other fields on the same queries (`customer.id`,
`retailLocation.id`) are defensively wrapped. If a specific order somehow
returned a null `MoneyBag` — which Shopify's schema documents these fields
as non-nullable, so this should not happen in practice — that one row would
fail to load rather than the whole refresh silently succeeding with wrong
data. **Left unfixed by design**: wrapping five files' worth of nested
field access in defensive code I cannot execution-test, against a failure
mode Shopify's own schema says shouldn't occur, risks introducing an
unverified change for a theoretical benefit. Documented here and in
`OPERATIONS_MANUAL.md`'s troubleshooting guide instead, with a concrete
symptom to look for ("N rows failed to load" banner) if it's ever actually
hit — a targeted fix at that point, informed by the real error, beats a
speculative one now.

**Two O(n²)-shaped worksheet formulas, not Power Query, flagged for
awareness**: `14_Data_Quality`'s "Duplicate Orders" and "Missing Payment"
checks use `SUMPRODUCT(COUNTIF(...))` / anti-join patterns that scale
quadratically with row count. At the current safety cap (~125,000 rows per
query per refresh, `15_Settings`' Max Pages parameter), this is a sheet-
recalculation cost, not a refresh-time cost, and only affects two of eleven
Data Quality checks. Not rewritten this phase — a genuine fix needs either
a Power Query-side dedup column (touching Phase 2 files, which every phase
including this one has treated as off-limits absent a specific reason
scoped to that phase) or accepting slower recalculation at high volume.
Flagged as a concrete Phase 8+ candidate if order volume grows large enough
for this to be felt.

### 2.3 CUBE function load

No new CUBEVALUE/CUBESET call sites were added this phase beyond the KPI-
card wiring in §1.1 (6 new formulas: `01_Home` ×2, `14_Data_Quality` ×4 —
all simple worksheet formulas against `LOG_`/named ranges, not CUBE
functions at all, so this phase added **zero** new CUBE-function load).
Total CUBE-function count across the workbook is unchanged from Phase 6's
own count (`PHASE6_PRODUCTION_READINESS_REVIEW.md` §10.8) — no duplicate
calls were introduced, and no consolidation opportunity was found beyond
what Phase 6 already achieved (helper-cell reuse in `add_cube_trend_table`/
`add_cube_top_n`, direct cell references instead of re-deriving CUBE
formulas for dashboard "Insights"/"Alerts"/"Forecast" sections).

### 2.4 Growth-driven scaling risk (restated with a concrete threshold)

`FACT_InventoryMovements` and both `LOG_` tables are append-only snapshots
with no archival mechanism. Rough guidance for when this stops being
theoretical: `fn_AppendLog`'s full-history recombine on every refresh
starts adding *noticeable* (seconds, not minutes) refresh time once a log
table crosses roughly 5,000-10,000 rows — at one refresh per business day,
that's 15-30 years for `LOG_RefreshHistory` alone, but `FACT_
InventoryMovements` (potentially one row per SKU per refresh, not per day)
could reach that range in months at a large SKU count and frequent
refreshing. `OPERATIONS_MANUAL.md` §3's monthly archive-check task exists
specifically to catch this before it becomes a real slowdown.

---

## 3. DAX Correctness Audit & Scalability Limits

### 3.1 Correctness review (this phase)

Read `dax/MEASURES.md` and both addenda in full against the specific
criteria you asked to validate:

- **Division-by-zero protection**: every ratio measure uses `DIVIDE()`
  (which returns blank on a zero/blank denominator rather than erroring),
  with zero exceptions found — `Gross Margin %`, `Net Profit Margin %`,
  `Average Order Value`, `Inventory Turnover`, every `*Attainment %`/
  `*Variance %`, `Return Rate %`, `Customer Growth % (YoY)`, all consistent.
- **Blank handling**: `SUMX`/`DISTINCTCOUNT`-based measures naturally
  return blank on an empty filter context (no special-casing needed — this
  is correct DAX idiom, not a gap). `Accounts Receivable` explicitly wraps
  its result in `MAX(0, ...)` to prevent a negative AR from a rounding/
  timing edge case — a deliberate, documented choice, not an oversight.
- **Grand totals / correct aggregation at any grain**: no measure hardcodes
  a grain-specific filter that would break at the grand-total level — the
  "cumulative to selected date" pattern (`Cash Position`, `Capital
  Invested`, `Retained Earnings`) explicitly uses `FILTER(ALL(DIM_Date),
  ...)` specifically so it's correct whether evaluated for a day, a month,
  or the whole table.
- **Time intelligence**: `§8`'s pattern (`TOTALMTD`/`TOTALQTD`/`TOTALYTD`/
  `DATEADD`/`SAMEPERIODLASTYEAR`/`DATESINPERIOD`) is applied consistently
  to the four measures it covers, with an explicit, correct extension
  recipe documented for applying it to any other measure — this is the
  right design (one documented pattern beats N inconsistent copies) and
  was not something to "fix," only confirm.
- **No duplicated calculations**: composite measures reference simpler ones
  by name throughout (`[Gross Profit]` used inside `[Assets]`, `[Net
  Profit]` used inside `[Retained Earnings]`, etc.) — verified no measure
  re-derives another's formula independently.

**No DAX defects found.** This is text (not executable in this
environment), so "correctness" here means logical/syntactic review, not
execution verification — `dax/README.md`'s own reconciliation-check
verification step (§9 measures should read ~0 after a real refresh) remains
the actual test, unchanged guidance from Phase 4 onward.

### 3.2 Scalability limits

| Limit | Threshold | Consequence |
|---|---|---|
| `Param_MaxPages` safety cap | ~125,000 rows/query/refresh (500 pages × 250) | A store exceeding this in one incremental window would silently truncate that refresh's data for the affected resource — raise the cap in `15_Settings` if a single-day order volume ever approaches it (extremely unlikely for this brand's stated scale). |
| `FACT_InventoryMovements` snapshot grain | Grows with refresh frequency × SKU count, unbounded | See §2.4. |
| Excel workbook size / Data Model size | No hard limit encountered at documented scale; Power Pivot compresses well | Multi-million-row fact tables would eventually strain in-memory Excel (32-bit Excel especially) — see §5 for the point at which this argues for a real database backend. |
| Single-writer, single-file design | No concurrent multi-user editing | Two people editing manual-entry tables in the same workbook simultaneously will conflict (last save wins) — inherent to a single `.xlsx` file, not fixable within this architecture; see §5. |
| `DIM_Date` range | 2023-01-01 to 2030-12-31 | Needs a one-line `EndDate` extension + re-wire (`OPERATIONS_MANUAL.md` §4) as the business approaches 2031 — flagged, not urgent. |

---

## 4. Security Improvements

Reviewed against the same standard as every prior phase (no hardcoded
credentials, least-privilege API scope, no write access from a read-only
tool):

**Already correct, reconfirmed this phase:**
- No Shopify access token appears anywhere in any `.pq` file, the workbook,
  or this repository — grepped fresh this phase, zero matches beyond the
  documented `Extension.CurrentCredential()` retrieval pattern.
- Every GraphQL query sent is a `query`, never a `mutation` — read-only by
  construction, reinforced by the recommendation (unchanged since Phase 2)
  to scope the custom app's token to `read_*` permissions only.
- Sheet protection (`PROTECT_PASSWORD`) locks every formula cell and every
  technical sheet is hidden — reduces accidental (not malicious) formula
  tampering.

**Improvements worth making, none urgent enough to block production use:**

1. **The workbook protection password (`Passress2026`) is stored in plain
   text in `scripts/build_workbook.py`** and is therefore visible to
   anyone with repository access. This protects against accidental
   structural changes (a user fat-fingering a locked cell), not against a
   determined bad actor — Excel sheet/workbook passwords are not strong
   encryption and this was never the intended threat model. **Recommendation**:
   if the business wants this password to mean something security-wise
   (not just "prevent accidents"), change it to a real secret not committed
   to source control, and treat the generated `.xlsx` itself — not this
   script — as the place the real password lives.
2. **No row-level or sheet-level access control beyond the single shared
   password.** Everyone who can open the file with the protection password
   can see and edit every manual-entry table — there's no "Finance can see
   Expenses but not Capital" separation. This is an inherent limitation of
   single-file Excel, not something fixable by this architecture — see §5
   for where a real access-control layer (SQL Server row-level security,
   or Power BI's row-level security) becomes available.
3. **The `.xlsx` file itself is unencrypted at rest** beyond Excel's own
   optional "Encrypt with Password" (not currently applied — sheet/
   structure protection is different from file encryption). If the file
   will ever be stored somewhere without its own encryption-at-rest
   (a shared drive, a non-encrypting backup destination), consider adding
   File → Info → Protect Workbook → Encrypt with Password as a deployment-
   time step, layered on top of the existing backup strategy.
4. **Credential rotation has no enforced cadence.** Nothing in Shopify or
   this workbook prompts for periodic token rotation — `DEPLOYMENT_GUIDE.md`
   §3 documents how to rotate, but doing so is a manual process discipline,
   not an enforced control. Reasonable for this scale; worth a calendar
   reminder if the business's own security policy expects periodic rotation.

None of these four are production blockers — they're the honest gap
between "a single-user Excel workbook with a shared password" and
"enterprise-grade access control," which is a category difference in tooling
(§5), not a defect in this implementation.

---

## 5. Future Migration Path: SQL Server + Power BI

Not a recommendation to migrate now — Passress's current scale (a single
Shopify store, one brand, the volumes implied by the existing `Param_
MaxPages` cap) is comfortably within what this Excel-based architecture
handles well. This section exists so the migration path is understood in
advance, not designed under pressure later.

### 5.1 What would trigger a migration

- Order/SKU volume regularly approaching or exceeding the `Param_MaxPages`
  safety cap.
- A genuine need for concurrent multi-user editing of manual-entry data
  (Purchase Orders, Expenses) rather than one person at a time.
- A need for real row-level security (different people seeing different
  slices of financial data) beyond a single shared workbook password.
- Multiple Shopify stores, brands, or currencies — this workbook's
  single-currency (EGP), single-store design would need real
  re-architecture, not just more rows, to support that.
- A desire for sub-second dashboard interactivity at a much larger data
  volume than Excel's Data Model comfortably holds in memory.

### 5.2 The migration shape, in order

1. **RAW_ / staging layer → SQL Server (or Azure SQL) tables.** The
   Power Query M logic in `power-query/staging/` already does the real
   work (pagination, incremental windowing, error handling) — it maps
   naturally onto a scheduled ETL job (Azure Data Factory, a scripted
   pipeline, or Power Query in a Dataflow) writing to SQL Server tables
   with the same column shapes already documented in
   `power-query/DOCUMENTATION.md`. The incremental-refresh logic
   (`fn_IncrementalWindow`'s pattern) translates directly to a SQL
   `MERGE`/upsert keyed on `updated_at`.
2. **Star schema (DIM_/FACT_) → SQL Server views or materialized tables.**
   `power-query/star-schema/*.pq`'s transformation logic (joins, the
   `fn_GetEffectiveCost` date-range cost resolution) becomes SQL views or
   a scheduled transformation job — the *logic* carries over even though
   the *language* changes from M to SQL.
3. **Manual-entry tables (Purchase Orders, Expenses, Capital, Product Cost
   Master, Budget) → SQL Server tables with a real front-end form**, or
   initially just linked Excel tables writing to SQL via Power Query
   (a valid, lower-effort intermediate step that keeps the familiar Excel
   entry experience while gaining a real concurrent-access backend).
4. **DAX measure library → Power BI, near-verbatim.** This is the
   lowest-friction part of the whole migration: `dax/MEASURES.md` and both
   addenda are already standard DAX, written against a star schema
   designed the same way Power BI expects one. The relationships in
   `dax/README.md` §Step 4 map directly onto Power BI's own relationship
   model. Expect copy-paste-with-minor-adjustment, not a rewrite.
5. **Dashboards → Power BI reports.** The CUBEVALUE/CUBESET workaround
   this entire BI layer exists because of (Excel can't script real
   PivotTables/Slicers) disappears entirely in Power BI — native visuals,
   real slicers, and native drill-through replace `add_cube_kpi_row`/
   `add_cube_top_n`/the link-based drill-through from Phase 6 in one step,
   arguably the single biggest quality upgrade available on the far side of
   this migration.
6. **Alerts/Insights/Forecast (`BI_Alerts`/`BI_Insights`/`BI_Forecast`) →
   Power BI + Power Automate, or a small scheduled service.** The rule-based
   logic in each (CUBEVALUE-driven thresholds) translates to DAX measures
   plus a Power Automate flow (or equivalent) for the "alert fires → notify
   someone" step this Excel version doesn't have (Excel can compute
   "TRIGGERED" but can't push a notification on its own).

### 5.3 What does NOT need to change

The **business logic** — every DAX measure's definition, every documented
business rule (historical costing via effective-dated rows, the Accounts
Payable proxy's documented limitation, EBITDA=Net Profit's stated
simplification, Returns including the tax portion) — carries forward
unchanged. This phased architecture was deliberately built so the thinking
survives a platform change even where the tooling doesn't; migrating is
substantially a re-platforming exercise, not a re-design of what the
numbers mean.

---

## 6. Overall Verdict

**PASSRESS MIS is production-ready for live daily business use on Windows
Excel**, subject to completing the one-time setup in `DEPLOYMENT_GUIDE.md`
(credentials, Power Query wiring, Data Model/DAX entry) — none of which is
optional infrastructure, all of which is disclosed, documented, and
achievable in a single sitting by someone following that guide in order.

**What "production-ready" means precisely here, stated without
overclaiming:**
- Every number that resolves is correct by design (DAX audited this phase,
  no defects found) and traceable to its source (drill-through links,
  documented measure definitions).
- Every known gap is disclosed, not hidden — six dashboard sheets remain
  intentionally unbuilt (§1.2), a handful of KPI targets have no Actual
  counterpart yet (Marketing-Ready Layer unconnected, unchanged since
  Phase 5), and the Power Query robustness finding in §2.2 is a real,
  documented, low-probability risk rather than a silent one.
- Five real defects were found and fixed this phase through genuine review,
  not a rubber-stamp — the same discipline Phase 6 established and this
  phase continued rather than merely repeated.
- The one hard platform constraint (Mac Power Pivot) is unresolvable within
  Excel itself and is clearly flagged as a deployment decision, not a bug.

**What would make it more than "production-ready"** — genuinely better,
not just more complete — is exactly what §5 describes: a SQL Server +
Power BI migration once/if the business outgrows single-file Excel's
concurrency and scale ceiling. That is future work you would need to
explicitly commission; nothing about today's state requires it.
