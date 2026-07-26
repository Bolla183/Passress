# PASSRESS MIS — Operations Manual

Phase 7 deliverable. For whoever runs the workbook day to day once
`DEPLOYMENT_GUIDE.md`'s setup is complete — not the setup process itself.

---

## 1. Daily tasks

1. **Refresh** (Data → Refresh All) — once per business day, ideally before
   anyone looks at `01_Home` or `RPT_ExecutiveBrief`. Expect a few minutes
   depending on order volume (see §5 for timing expectations).
2. **Check `01_Home`'s Data Quality card and `BI_HealthScore`.** If Data
   Quality drops noticeably or the Health Score flips to RED, open
   `14_Data_Quality` before doing anything else that day — see §6 for what
   each check means.
3. **Review `RPT_ExecutiveBrief`** (right-click any tab → Unhide, or the
   link on `01_Home`) — the one-page daily snapshot: today's Revenue/
   Orders/Gross Profit/Margin, Cash Position, Inventory Value, Revenue vs
   Yesterday, Top 5 Products/Collections, Critical Alerts, Business Health
   Score, Executive Commentary. Print or export to PDF if it needs to go to
   a partner (File → Print → the print area is already set — no extra
   configuration needed).
4. **Check `BI_Alerts`' two Critical rows** (Negative Margin, Missing
   Shopify Sync) — surfaced on `RPT_ExecutiveBrief` already; act on either
   immediately if TRIGGERED (Negative Margin: check for a Product Cost
   Master gap or an unusually large discount/refund; Missing Shopify Sync:
   confirm the last refresh actually ran — see §7's "refresh didn't run").
5. **Enter the day's manual data as it happens** (Expenses, Purchase
   Orders, Goods Receipts, Capital transactions) rather than batching —
   Possible Duplicate flags and PO/Receipt matching both work better
   against same-day entries than a backlog entered all at once weeks later.

## 2. Weekly tasks

1. **Review `RPT_Workflow`**: Open Orders, Pending Receipts, Inventory to
   Receive, Supplier Status. Chase any PO stuck in "Sent" or "Partially
   Received" status longer than its supplier's usual lead time.
2. **Review all 12 rows of `BI_Alerts`**, not just the two Critical ones —
   Warning/Info-severity alerts (Low Inventory, Slow Moving Inventory, Dead
   Stock, Products without Cost, Expenses without Category, Over Budget
   Expenses) are the kind of thing that's fine to triage weekly rather than
   same-day.
3. **Clear flagged duplicates**: any row on `10_Expenses` or `11_Capital`
   marked "Possible Duplicate" — confirm it's a real duplicate (delete one)
   or a legitimate coincidence (same date/amount/party, different expense)
   and leave both, understanding the flag will persist since the underlying
   COUNTIFS match doesn't distinguish the two cases.
4. **Reconcile Product Cost Master overlaps**: any row with a non-blank
   Overlap Warning — deactivate the stale row (Active Flag → Inactive) per
   the historical-costing rule documented on `05_Products`.
5. **Spot-check `dax/MEASURES.md` §9's Reconciliation measures** (Balance
   Sheet Check, Cash Variance, Net Sales Tie-Out, Refund Orphan Count,
   Lines Missing Cost) — put them on a small PivotTable or reference them
   via CUBEVALUE in an empty cell if not already visible somewhere; a
   material drift from ~0 in any of them is worth investigating before it
   compounds another week.

## 3. Monthly tasks

1. **Close the month**: confirm every Expense/Capital/PO/Receipt for the
   month is entered before treating MTD numbers as final — there's no
   formal "period close" lock in this workbook (a deliberate simplicity
   choice), so "closed" is a process discipline, not a system state.
2. **Review Budget vs. Actual** (`03_CEO_Dashboard`'s Budget section, or
   `08_Finance`'s `tbl_Budget` table directly) — true up next month's
   budget line if this month's variance points at a planning gap rather
   than an operational one.
3. **Review KPI Targets** (`15_Settings` `tbl_KPITargets`) — adjust any
   target that's chronically over- or under-shot in a way that suggests the
   target itself, not performance, is the issue.
4. **Review `tbl_HealthScoreWeights`** — rebalance if one component has
   been dominating the Business Health Score's swings in a way that doesn't
   match the business's actual priorities that month.
5. **Archive check**: if `LOG_RefreshHistory` or `LOG_DataQuality` is
   growing past a few thousand rows, copy older rows to a plain (non-Table)
   archive sheet by hand — `fn_AppendLog.pq`'s own header comment flags
   this as the expected maintenance point (see §8's performance note too).
6. **Take a dated backup copy** even if the automated cloud backup is
   running (`DEPLOYMENT_GUIDE.md` §8) — a clean month-end snapshot is worth
   having independent of the rolling daily versions.

## 4. Year-end tasks

1. **Confirm `DIM_Date.pq`'s date range still covers the new year** — it's
   generated through 2030-12-31 as shipped; if the business is still
   running near that boundary, extend `EndDate` in `DIM_Date.pq` and
   re-wire that one query (no other change needed).
2. **Review Fiscal Year Start Month** (`15_Settings`) if the business's
   fiscal calendar is changing — every FY/FQ-based measure and `DIM_Date`
   column recalculates from this one parameter.
3. **Populate next year's Holidays** (`15_Settings` `tbl_Holidays`) if the
   business tracks business-day-aware reporting via `IsWorkingDay`.
4. **Full annual backup**, kept separately from the rolling daily/monthly
   rotation, retained per the business's own record-keeping requirements
   (this workbook has no built-in retention policy beyond what §8 of the
   Deployment Guide recommends).
5. **Re-baseline Budget** for the new year (`tbl_Budget`, new Year rows) —
   old-year rows should stay (Actual-vs-Budget reporting for prior years
   still reads them), not be deleted.
6. **Review the whole Version Log** (`15_Settings` `tbl_VersionLog`) and
   this repository's own commit history together — a good moment to decide
   whether a new phase of work is warranted for the coming year.

---

## 5. Expected performance / refresh timing

No live Excel session was available to benchmark this workbook against real
data (disclosed consistently since Phase 2 — see
`PHASE6_PRODUCTION_READINESS_REVIEW.md`'s "Testing NOT performed" section
and `PHASE7_FINAL_ARCHITECTURE_REVIEW.md` §2 for the same caveat applied to
this phase). As a general rule of thumb for a workbook of this shape:

- A few hundred to a few thousand orders: refresh should complete in well
  under a minute for the Power Query layer, DAX/CUBEVALUE recalculation
  near-instant.
- Tens of thousands of orders (`Max Pages Per Refresh` on `15_Settings`
  caps growth at ~125,000 rows per query per refresh as a safety net):
  expect refresh to take minutes, dominated by Shopify API pagination
  (250-row pages) rather than Excel's own processing.
- If a refresh takes materially longer than the previous one for a similar
  data volume, check `LOG_RefreshHistory` for a spike in `RowsLoaded`
  (unexpected full-history re-pull — see §7) before assuming it's a Shopify
  API slowdown.

---

## 6. What each Data Quality check means (14_Data_Quality)

| Check | A nonzero/failing result usually means |
|---|---|
| Missing SKU | A Shopify variant has no SKU set — fix in Shopify Admin, not this workbook. |
| Missing Cost | An order line has no matching Product Cost Master row for its SKU/date — add a Product Cost Master entry (`05_Products`). |
| Missing Supplier | A SKU has never had a Goods Receipt recorded, so `DIM_Product.PrimarySupplierID` has nothing to infer from — expected for SKUs never purchased through this system yet. |
| Duplicate Orders | Should always be 0. If not, the Power Query incremental window logic appended the same order twice — check `RAW_Orders.pq`'s incremental filter, or re-run a full refresh after clearing the table. |
| Duplicate Expenses | A same-date/supplier/amount match on `10_Expenses` — confirm real duplicate vs. coincidence (§2). |
| Products without Collection | A Shopify product isn't assigned to any collection — a merchandising gap, not a workbook bug. |
| Products without Images | Always shows N/A — `RAW_Products.pq` doesn't fetch image data (documented, deliberate scope gap). |
| Negative Inventory | Should always be 0. A negative Available count usually means an oversell or inventory-sync issue in Shopify itself. |
| Missing Customer | Expected nonzero (guest checkouts). Watch the *rate*, not the raw count. |
| Missing Payment | An order with no matching transaction — investigate in Shopify Admin (pending/failed payment) rather than assuming a workbook fault. |
| Refresh Failures | `LOG_DataQuality` recorded a WARNING status on the last refresh — see §7. |

---

## 7. Troubleshooting guide / common errors

**"Refresh All" throws an error dialog citing `Shopify.AuthError`.**
The access token expired, was revoked, or lacks a required scope. Fix:
`DEPLOYMENT_GUIDE.md` §3 step 4 — re-enter the token via Data Source
Settings. If it keeps happening, the token may have been revoked when the
custom app was reinstalled in Shopify Admin; generate a fresh one.

**"Refresh All" throws `Shopify.HttpError` after several attempts.**
The shared `fn_ShopifyGraphQL` function already retries transient 5xx
errors with exponential backoff (2s/4s/8s/16s) and 429 rate-limits using
Shopify's own `Retry-After` header — if it still failed after 5 attempts,
Shopify's API was down or unreachable for longer than that backoff window.
Wait a few minutes and refresh again; check Shopify's status page if it
persists.

**A CUBEVALUE-based KPI card shows 0 or blank everywhere.**
Almost always means the Data Model isn't fully wired yet — either a
`DIM_`/`FACT_` table isn't added to the Data Model, `DIM_Date` isn't marked
as the Date Table, or a referenced DAX measure hasn't been entered yet. Not
a formula bug in the workbook itself; see `DEPLOYMENT_GUIDE.md` §6.

**A CUBEVALUE-based KPI card shows `#REF!` or `#NAME?`.** Usually a typo'd
measure name when it was entered into Power Pivot, or a measure that
references another measure not yet created — enter measures in the
documented order (`dax/README.md`).

**A dropdown (SKU, Collection, Supplier, PO Number) is empty.** The
underlying `RAW_`/manual table it sources from isn't populated yet — for
`RAW_Variants`/`RAW_Collections`-sourced dropdowns, confirm that query is
wired (`DEPLOYMENT_GUIDE.md` §5); for Supplier/PO Number, confirm at least
one row exists in `tbl_SupplierMaster`/`tbl_POHeader`.

**`14_Data_Quality`'s Overall Data Quality % shows 0% or an error right
after first refresh.** Confirm every `RAW_`/`LOG_` query was wired (§5.3 of
the Deployment Guide) — a single un-wired table feeding one of the 11
checks can make the percentage compute incorrectly or error out entirely
depending on which check it is.

**"Missing Shopify Sync" alert (ALT-10 / BI_Alerts) is TRIGGERED even
though a refresh just succeeded.** The check looks for at least one
`LOG_RefreshHistory` row timestamped within the last 2 days — if
`LOG_RefreshHistory` itself isn't wired yet (§5.3), or its append pattern
was interrupted mid-refresh (`fn_AppendLog.pq`'s documented "no partial
write" limitation), this alert stays TRIGGERED until a refresh completes
cleanly with that query included.

**A row silently failed to load after refresh ("N rows failed to load"
banner in Excel).** Most likely a single record from Shopify had an
unexpected null in a field the query assumes is always present (e.g. a
MoneyBag field) — see `PHASE7_FINAL_ARCHITECTURE_REVIEW.md` §2 for the
specific fields flagged as a documented, low-probability robustness gap.
Check the erroring row in Power Query's own load-error detail (click the
banner) to identify which field.

**Workbook won't open / opens corrupted.** Restore from backup
(`DEPLOYMENT_GUIDE.md` §9, Scenario B) — do not attempt to repair a
corrupted `.xlsx` by hand.

**Forgot the sheet-protection/workbook password.** See
`DEPLOYMENT_GUIDE.md` §9, Scenario D.

**A number on a dashboard doesn't match what's expected.** Work backward
using the drill-through links (Partner/CEO Dashboard KPI sections → their
detail sheets) to the underlying `RAW_`/`FACT_` data, then check
`dax/MEASURES.md`'s definition of that specific measure for a business
rule that might explain the difference (e.g. Returns includes the tax
portion of a refund — see that measure's own documented simplification).

---

## 8. Recovery steps (operational, not disaster-level)

These are lighter-weight than `DEPLOYMENT_GUIDE.md` §9's full recovery
scenarios — day-to-day slips rather than file loss:

- **Accidentally deleted a row from a manual-entry table**: Ctrl+Z
  immediately if caught right away; otherwise restore from the most recent
  backup and re-enter anything added since (§8 of the Deployment Guide sets
  the backup cadence this depends on).
- **Entered a Purchase Order line against the wrong PO Number**: correct
  the PO Number cell directly on `tbl_POLines` — Goods Receipt's Remaining
  Quantity/Variance formulas recalculate automatically, no other cleanup
  needed.
- **Deactivated the wrong Product Cost Master row**: flip Active Flag back
  to Active; if a second row was already added for the "new" cost, deactivate
  that one instead so only one Active row per SKU remains (the Overlap
  Warning column will flag it if both are left Active).
- **A refresh ran with the wrong Lookback Days / Historical Backfill
  Start Date** (`15_Settings`): correct the parameter, refresh again — the
  incremental-window logic re-derives its filter from current parameter
  values every time, nothing "sticky" needs resetting.
