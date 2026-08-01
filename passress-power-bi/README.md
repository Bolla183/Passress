# PASSRESS Power BI Dashboard

This project **replaces** the `passress-mis/` Excel workbook as PASSRESS's
BI solution. The Excel project is left in the repository unchanged (in
case anything in it is still useful for reference — the DAX measure
patterns and Shopify GraphQL knowledge it built up are what this project
is based on) but is no longer the active deliverable.

## What's here so far (Phase 1 of this project — Data Model + Sales page)

| File | What it is |
|---|---|
| `DATA_MODEL.md` | The star schema: 5 tables this phase, what's planned later, why it's simpler than the Excel version |
| `power-query/*.pq` | 11 Power Query M files — parameters, shared functions, and every table in this phase's data model |
| `dax/SALES_MEASURES.md` | The 7 DAX measures the Sales page needs |
| `pages/SALES_PAGE.md` | Exact build spec for the Sales report page — layout, visuals, colors |

Everything else in the brief (Executive Dashboard, Products, Customers,
Marketing, Inventory, Finance, Settings pages) is deliberately **not**
built yet — this phase exists to validate the approach on one real page
before committing to all eight.

## Why there's no `.pbix` file in this repo

I can't generate a working Power BI file directly — there's no tool that
creates `.pbix` files outside Power BI Desktop itself (this is a harder
version of the same limitation the Excel project had with Power Query/
Data Model/PivotTables — for Power BI, there's no partial workaround at
all). Everything above is the complete "recipe": paste-ready M code,
paste-ready DAX, and a build spec precise enough to follow visual by
visual. Someone needs to actually assemble it inside Power BI Desktop,
following the steps below.

## Setup — building this phase in Power BI Desktop

1. **Get Power BI Desktop** (free) if you don't have it — Microsoft Store
   or powerbi.microsoft.com.

2. **Create the parameters first.** Home → Transform Data → Manage
   Parameters → New Parameter, once for each:
   - `Param_ShopifyStoreDomain` (Text) — your real `*.myshopify.com` domain
   - `Param_ShopifyAPIVersion` (Text) — `2025-01` (or current)
   - `Param_HistoricalStartDate` (Date) — how far back to pull orders from

3. **Create the two shared functions.** Home → Transform Data → New Source
   → Blank Query → Advanced Editor → paste `fn_ShopifyGraphQL.pq`'s
   contents → Done → rename the query to `fn_ShopifyGraphQL` (exactly).
   Repeat for `fn_ShopifyPagedConnection.pq`.

4. **Create `Orders_Source`** the same way (Blank Query → Advanced Editor
   → paste → rename to `Orders_Source`). Right-click it in the Queries
   pane → uncheck **Enable load** — this one is connection-only, shared by
   two other queries, not meant to appear as its own table.

5. **Create the 4 remaining tables** (`FACT_OrderLines`, `FACT_Returns`,
   `DIM_Product`, `DIM_Customer`, `DIM_Date`) the same way — Blank Query,
   paste, rename to match the filename exactly. Leave these loaded
   (default).

6. **First refresh will prompt for credentials.** Choose **Web API**,
   paste your Shopify Admin API access token (same kind of custom app,
   read-only scoped, as the Excel project used — see that project's
   `DEPLOYMENT_GUIDE.md` §3 if you need the Shopify-side steps again,
   they're identical here).

7. **Close & Apply.**

8. **Build the relationships.** Model view — drag to connect:
   - `DIM_Date[DateKey]` → `FACT_OrderLines[DateKey]`
   - `DIM_Date[DateKey]` → `FACT_Returns[DateKey]`
   - `DIM_Product[ProductKey]` → `FACT_OrderLines[ProductKey]`
   - `DIM_Product[ProductKey]` → `FACT_Returns[ProductKey]`
   - `DIM_Customer[CustomerKey]` → `FACT_OrderLines[CustomerKey]`

   All single-direction, one-to-many (Power BI defaults to this — don't
   change the cross-filter direction to "Both" unless you have a specific
   reason to; "Both" is the most common cause of slow, confusing reports).

9. **Mark the date table.** Right-click `DIM_Date` → Mark as date table →
   column `Date`.

10. **Hide technical columns** per `DATA_MODEL.md`'s per-table notes
    (`OrderID`, `ProductID`, `CustomerID`, `Email`, etc.) — right-click
    each column in the Fields pane → Hide in report view. Keeps the field
    list clean for whoever's building visuals, without deleting the data.

11. **Enter the 7 DAX measures** from `dax/SALES_MEASURES.md`, in order —
    right-click `FACT_OrderLines` → New Measure.

12. **Build the Sales page** following `pages/SALES_PAGE.md` step by step.

13. **Refresh** — if numbers look wrong or a query errors, check the
    "UNVERIFIED" notes in `Orders_Source.pq` and `DIM_Product.pq` first
    (`Channel`/`sourceName` and `UnitCost` specifically) — those two are
    flagged as needing a live-schema check that wasn't possible to do
    while writing this.

## Maintaining it (the part that matters most)

**Refreshing data**: Home → Refresh. That's it — pulls everything from
`Param_HistoricalStartDate` forward, every time.

**Entering an expense**: not part of this phase yet (Finance page isn't
built) — when it is, it'll be exactly what the brief asked for: one
Excel sheet, one row per expense, no multi-sheet complexity.

**Adding a new page later**: follow the same pattern as this one — a
`pages/<NAME>_PAGE.md` spec, a `dax/<NAME>_MEASURES.md` file if new
measures are genuinely needed (check `dax/SALES_MEASURES.md`'s measures
first — many pages will reuse `[Revenue]`, `[Orders]`, etc. rather than
needing anything new), and new `power-query/*.pq` files only for tables
that don't already exist.

## Known gaps, honestly disclosed

- **`Channel`/`sourceName`** and **`DIM_Product[UnitCost]`**: flagged
  above, not yet verified against a live Shopify schema (no store was
  connected in the session this was built in).
- **Marketing page's Campaign/ad-spend data**: Shopify's Admin API doesn't
  expose it — will need a separate source when that page is built, same
  gap the Excel project's "Marketing-Ready Layer" always had.
- **Field Parameters (Daily/Weekly/Monthly/Quarterly/Yearly switcher)**:
  designed for, not yet built — comes with the Executive Dashboard phase,
  since that's the page it matters most on.
