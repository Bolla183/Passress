# PASSRESS MIS — Phase 2 Setup Guide: Shopify GraphQL Ingestion Layer

> **Phase 4 addition:** once this Phase 2 layer is wired in, `star-schema/`
> (new folder alongside `parameters/`, `shared/`, `staging/`) builds the
> actual `FACT_`/`DIM_` tables on top of it, and `../dax/` has the full DAX
> measure library that depends on those. See `../dax/README.md` for the
> continuation — it assumes everything in this file is already done.

## Why these files aren't already inside the workbook

Power Query's M code and query definitions live in a proprietary binary part
of the `.xlsx` file (the "DataMashup" package) that general-purpose tools
like `openpyxl` cannot write — only Excel itself can create it. So this
folder is the actual Phase 2 deliverable: complete, tested-by-inspection M
code for every query, ready to paste into Excel. The steps below wire it into
`PASSRESS_MIS.xlsx` in about 15–20 minutes, once.

## What you're building

```
Parameters (5)  →  Shared functions (4)  →  Staging queries (13)  →  RAW_/LOG_ sheets
```

Every staging query is **read-only** (GraphQL `query` operations only, never
`mutation`), **paginates automatically**, **refreshes incrementally** after
the first run, and **handles errors** (auth failures, rate limits, transient
server errors) with clear messages instead of silently returning partial or
wrong data. See `DOCUMENTATION.md` for the full field-by-field reference.

## Prerequisites

1. **A Shopify custom app** (Settings → Apps and sales channels → Develop
   apps) with an Admin API access token scoped to:
   - `read_products`, `read_inventory`, `read_customers`, `read_orders`,
     `read_discounts`
   - `read_all_orders` **only if** you need order history older than 60 days
     for the initial backfill (Shopify restricts the plain `read_orders`
     scope to the last 60 days — see `Orders_Source.pq`'s comments).
   - No `write_*` scopes. This is deliberate: even if a query were ever
     mistakenly changed to a mutation, an under-scoped token would still
     reject the write.
2. Excel 365 (Windows or Mac) with Power Query ("Get & Transform Data").

## Step 1 — Create the 5 parameter queries

For each file in `parameters/`: **Data → Get Data → Launch Power Query
Editor → New Query → Blank Query**. Rename the query to match the filename
exactly (without `.pq`) — e.g. `Param_ShopifyStoreDomain` — then open
**Advanced Editor** and paste the file's contents in, replacing the
placeholder text. Right-click each in the Queries pane → **Enable Load**
should be **off** (these are lookups other queries use, not tables to load).

**Important:** these queries read named ranges already on `15_Settings`
(`SetShopifyStoreDomain`, `SetShopifyAPIVersion`, etc. — see Phase 1). Set
`Shopify Store Domain` on `15_Settings` to your real `*.myshopify.com`
domain before refreshing anything.

## Step 2 — Create the 4 shared function queries

Same process, for every file in `shared/`: blank query, rename to match the
filename (`fn_ShopifyGraphQL`, `fn_ShopifyPagedConnection`,
`fn_IncrementalWindow`, `fn_AppendLog`), paste the M code, disable load.
Create these **after** Step 1 — `fn_ShopifyGraphQL` references the parameter
queries by name.

## Step 3 — Set the credential (no token ever touches the workbook)

Refresh `fn_ShopifyGraphQL` once (right-click → Refresh) — Excel will prompt
for credentials for the new Web data source (your store's domain). Choose
credential type **Web API**, and paste the Shopify Admin API access token
into the **Key** field. Excel stores this in the Windows Credential Manager
/ macOS Keychain, not in the file. To change or re-enter it later: **Data →
Get Data → Data Source Settings → [your store domain] → Edit Permissions →
Credentials → Edit...**

## Step 4 — Create the staging queries, in this order

Order matters here because later queries reference earlier ones by name:

1. `RAW_Products`, `RAW_Variants`, `RAW_Customers`, `RAW_Collections`,
   `RAW_InventoryLevels`, `RAW_Discounts` — independent, any order.
2. `Orders_Source` — **disable load** (connection-only; it's shared
   plumbing, not a table anyone should see).
3. `RAW_Orders`, `RAW_OrderLines`, `RAW_Transactions`, `RAW_Refunds` — each
   references `Orders_Source`.

For each: blank query → rename to match the filename → Advanced Editor →
paste → **Close & Load To... → Table → Existing worksheet**, pointing at the
matching `RAW_` sheet Phase 1 already created and documented. Before loading,
delete that sheet's Phase 1 placeholder table first (select it → Table
Design → Convert to Range, or delete its two rows) so Power Query's own
table doesn't collide with it — the sheet's documentation block and hidden
state are unaffected either way.

## Step 5 — Create the 2 log queries last

`LOG_RefreshHistory` and `LOG_DataQuality` both reference every `RAW_` query
by name — that dependency is what makes Excel refresh them *after* all the
staging queries in the same **Refresh All**, giving an accurate per-refresh
summary. Load each to its matching hidden `LOG_` sheet the same way as
Step 4.

## Step 6 — Refresh

**Data → Refresh All.** First run pulls the historical backfill (from
`Historical Backfill Start Date` on `15_Settings`); every run after that is
incremental (rolling `Lookback Days` window — see `fn_IncrementalWindow.pq`).
Check `LOG_RefreshHistory` and `LOG_DataQuality` afterward for row counts and
any `WARNING` rows.

## How incremental refresh works (no watermark cell required)

`fn_IncrementalWindow` checks whether the target `RAW_` table already has
rows. Empty (first run) → fetch from `Historical Backfill Start Date`.
Otherwise → fetch from `(now − Lookback Days)`, a rolling re-check window.
This trades a little redundant re-fetching (harmless) for robustness: there's
no stored watermark cell that could get stuck if a refresh fails partway.

## How pagination works

`fn_ShopifyPagedConnection` follows `pageInfo.endCursor` automatically via
`List.Generate`, stopping at `hasNextPage = false` or `Max Pages Per Refresh`
(`15_Settings`) — whichever comes first, guaranteeing every refresh
terminates even if a filter is misconfigured.

## How error handling works

`fn_ShopifyGraphQL` distinguishes:
- **HTTP 401/403** → `Shopify.AuthError` with a message pointing at Data
  Source Settings (bad/missing/under-scoped token).
- **GraphQL `errors[]` in a 200 response** → `Shopify.GraphQLError` with the
  combined error text (e.g. a bad field or filter).
- **HTTP 429** → waits for the `Retry-After` header, retries (up to 5x).
- **HTTP 500/502/503/504** → exponential backoff (2s, 4s, 8s, 16s), retries
  up to 5x.
- **Cost-based throttling** (Shopify's GraphQL point bucket, independent of
  HTTP 429) → pauses long enough for the bucket to refill before retrying.

## Known limitations (see also each file's header comments)

- `RAW_OrderLines`/`RAW_Transactions`/`RAW_Refunds` inherit `Orders_Source`'s
  50-line-items-per-order and 20-transactions/refunds-per-order caps — no
  nested pagination within an order. Very unlikely to bind for a retail
  catalog; raise the caps in `Orders_Source.pq` if it ever does.
- `RAW_Discounts` only has verified field mappings for the 3 code-based
  discount types (Basic/FreeShipping/Bxgy) plus a minimal-field fallback for
  the 3 automatic types; function-backed (app) discounts return ID only. See
  that file's header comment before relying on discount reporting.
- `RAW_Orders.LocationID` is populated only for POS/retail orders
  (`retailLocation`); blank for ordinary online orders — expected, not a bug.
- `LOG_RefreshHistory`'s `RowsUpdated`/`Errors`/`DurationSeconds` columns are
  placeholders (0) — Power Query has no built-in wall-clock timer or
  previous-run diff without extra bookkeeping; a reasonable Phase 3 addition.
- This sandbox's LibreOffice cannot execute Power Query at all (M isn't part
  of ODF/Calc), so none of this M code could be test-run here — it was
  written against the live Shopify Admin GraphQL schema (verified field-by-
  field via the schema introspection tool, not from memory) and reviewed
  carefully, but the very first real refresh in Excel is this layer's actual
  first test. Watch `LOG_DataQuality` closely on that first run.
