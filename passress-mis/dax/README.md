# PASSRESS MIS — Phase 4 Setup Guide: Financial Calculation Engine

## Why this isn't already wired into the workbook

Same reason as Phase 2's Power Query layer, one level deeper: Excel's Data
Model (Power Pivot) is an embedded analytics engine stored in a proprietary
binary part of the `.xlsx` that no general-purpose tool — `openpyxl`
included — can write. DAX measures only exist *inside* that Data Model, so
they can't be scripted into the file directly either. What follows is the
complete, correct DAX — ready to paste — plus the exact steps to build the
Data Model it depends on.

## Prerequisite: Phase 2's Power Query layer must already be wired

If you haven't done Phase 2's setup yet (`power-query/README.md`), do that
first — every star-schema query below references the `RAW_` queries by name.

## Step 1 — Add the star-schema transformation queries

`power-query/star-schema/` (new this phase) builds the actual `FACT_`/`DIM_`
tables Phase 1 sketched as empty placeholders — Phase 2 deliberately stopped
at `RAW_` staging, so this layer never existed until now. Same process as
before: blank query → rename to match the filename → Advanced Editor →
paste. Create in this order (each references the ones before it by name):

1. `parameters/Param_FiscalYearStartMonth.pq`
2. `shared/fn_GetEffectiveCost.pq`
3. `star-schema/DIM_Date.pq`, `DIM_Customer.pq`, `DIM_Location.pq`,
   `DIM_Collection.pq`, `DIM_Supplier.pq`, `DIM_ProductCostHistory.pq`
4. `star-schema/FACT_ManualExpenses.pq`, `FACT_CapitalTransactions.pq`,
   `FACT_PurchaseOrderHeader.pq`, `FACT_PurchaseOrderLines.pq`,
   `FACT_GoodsReceipt.pq`
5. `star-schema/DIM_Product.pq` — **last among the DIMs**, because its
   `PrimarySupplierID` column reads `FACT_PurchaseOrderHeader` and
   `FACT_GoodsReceipt`, both created in step 4.
6. `star-schema/FACT_OrderLines.pq`, `FACT_Refunds.pq`, `FACT_Payments.pq`,
   `FACT_InventoryMovements.pq`

For each: **Close & Load To... → Table → Existing worksheet**, pointing at
the matching `DIM_`/`FACT_` sheet Phase 1 already created — delete that
sheet's placeholder table first (same as Phase 2's instructions).

## Step 2 — Add every table to the Data Model

For **every** `RAW_`, `DIM_`, and `FACT_` table (Phase 2's staging tables
included, since some measures reference them directly — see MEASURES.md):
select the table → **Power Pivot tab → Add to Data Model** (or check "Add
this data to the Data Model" when loading a query). `tbl_ProductCostMaster`,
`tbl_SupplierMaster`, `tbl_ManualExpenses`, etc. on the visible sheets need
this too if you want to browse them directly in Power Pivot, but the
`FACT_`/`DIM_` mirrors are what the measures below actually use.

## Step 3 — Mark DIM_Date as the Date Table

Data Model window → select `DIM_Date` → **Design → Mark as Date Table →**
choose the `Date` column. Every time-intelligence measure in MEASURES.md
requires this — DAX's `TOTALYTD`, `SAMEPERIODLASTYEAR`, etc. don't work
without a properly marked date table.

## Step 4 — Build the relationships

Data Model window → **Design → Manage Relationships → Create**. All of these
are single-direction, one-to-many, Dimension → Fact:

| From (one side) | To (many side) |
|---|---|
| `DIM_Date[DateKey]` | `FACT_OrderLines[DateKey]` |
| `DIM_Date[DateKey]` | `FACT_Refunds[DateKey]` |
| `DIM_Date[DateKey]` | `FACT_Payments[DateKey]` |
| `DIM_Date[DateKey]` | `FACT_InventoryMovements[DateKey]` |
| `DIM_Date[DateKey]` | `FACT_ManualExpenses[DateKey]` |
| `DIM_Date[DateKey]` | `FACT_CapitalTransactions[DateKey]` |
| `DIM_Date[DateKey]` | `FACT_PurchaseOrderHeader[DateKey]` |
| `DIM_Date[DateKey]` | `FACT_GoodsReceipt[DateKey]` |
| `DIM_Product[ProductKey]` | `FACT_OrderLines[ProductKey]` |
| `DIM_Product[ProductKey]` | `FACT_PurchaseOrderLines[SKU]` |
| `DIM_Product[ProductKey]` | `FACT_GoodsReceipt[SKU]` |
| `DIM_Product[ProductKey]` | `FACT_InventoryMovements[ProductKey]` |
| `DIM_Product[ProductKey]` | `FACT_ManualExpenses[RelatedSKU]` |
| `DIM_Product[PrimarySupplierID]` | `DIM_Supplier[SupplierKey]` |
| `DIM_Customer[CustomerKey]` | `FACT_OrderLines[CustomerKey]` |
| `DIM_Location[LocationKey]` | `FACT_OrderLines[LocationKey]` |
| `DIM_Location[LocationKey]` | `FACT_InventoryMovements[LocationKey]` |
| `DIM_Collection[CollectionKey]` | `FACT_ManualExpenses[RelatedCollection]` |
| `DIM_Supplier[SupplierKey]` | `FACT_ManualExpenses[SupplierID]` |
| `DIM_Supplier[SupplierKey]` | `FACT_PurchaseOrderHeader[SupplierID]` |
| `FACT_OrderLines[OrderLineKey]` | `FACT_Refunds[OrderLineKey]` |
| `FACT_PurchaseOrderHeader[PONumber]` | `FACT_PurchaseOrderLines[PONumber]` |
| `FACT_PurchaseOrderHeader[PONumber]` | `FACT_GoodsReceipt[PONumber]` |

**`DIM_ProductCostHistory` is deliberately NOT related to anything.** Power
Pivot relationships are single-column equality joins; "SKU matches AND the
order date falls inside this cost row's Effective From/To range" isn't
expressible that way. That join already happened in Power Query
(`fn_GetEffectiveCost`, evaluated per order line at refresh time) — see
`power-query/star-schema/FACT_OrderLines.pq`. `DIM_ProductCostHistory` sits
in the model unrelated, for its own measures (current cost browsing) and for
`LOOKUPVALUE()` calls in a few measures below (Inventory Value) that
intentionally look up a value without a relationship.

The last two relationships (`FACT_OrderLines→FACT_Refunds`,
`FACT_PurchaseOrderHeader→FACT_PurchaseOrderLines/FACT_GoodsReceipt`) are
fact-to-fact. That's unusual in a textbook star schema but correct here —
a refund and a goods receipt are naturally "transaction subtypes" of an
order line / PO, not independent facts needing their own dimension path.

## Step 5 — Add the measures

Power Pivot tab → **Measures → New Measure**, or right-click a table in the
Fields list → **New Measure**. Paste each DAX formula from `MEASURES.md`
one at a time, using the exact measure name given (measures referencing
other measures by name — e.g. `[Net Sales]` inside `[Gross Profit]` — must
already exist first; MEASURES.md is ordered so earlier sections' measures
are always available to later ones).

Consider creating a disconnected "Measures" table (Power Pivot → Table →
New, paste one dummy column) to hold all measures in one place rather than
scattering them across `FACT_OrderLines`, `FACT_ManualExpenses`, etc. —
purely organizational, doesn't change how any measure works.

## A known constraint worth planning around: Excel for Mac

Flagged back in Phase 0 and worth restating now that we're actually at this
step: Excel for Mac can *load* a Data Model and display PivotTables built
from it, but its Power Pivot / DAX-authoring UI is meaningfully more
limited than Windows. If whoever is entering these measures is on a Mac,
either do this step in Excel for Windows (or Excel Online, which has fuller
Power Pivot support than Mac desktop) and let Mac just consume the finished
workbook, or budget extra time for a more constrained authoring experience.

## Verifying it worked

After all measures are in, open `dax/MEASURES.md`'s Reconciliation section
and build one quick PivotTable per check — each should show ~0 (small
rounding aside). A nonzero reconciliation value points at either a real data
gap (see each measure's documented limitations) or a relationship set up
incorrectly in Step 4.
