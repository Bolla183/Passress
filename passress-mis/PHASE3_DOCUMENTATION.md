# PASSRESS MIS — Phase 3 Reference: Business Master Data & Manual-Entry Engine

Everything below is either brand new in Phase 3 or an upgrade of a Phase 1
placeholder. Cells shaded **green** are manual input; **light gray** cells
are automatic formulas (locked); **orange** cells are configurable lookups.
Every dropdown sources from an editable table — nothing is a hardcoded Excel
list — so extending a category is "add a row," never "edit a formula."

---

## 1. Product Cost Master — `05_Products`, table `tbl_ProductCostMaster`

Appended below the Phase 1 dashboard placeholders (untouched — still Phase 4
work). Grain: **one row per SKU per cost version** — historical costing by
design, not a simple current-cost lookup.

| Column | Type | Source / Validation | Notes |
|---|---|---|---|
| Cost ID | auto (locked) | `="COST-"&TEXT(ROW()-header,"00000")` | sequential, auto-fills on new rows |
| SKU | manual | dropdown → `SKUList` (`tbl_RAW_Variants[SKU]`) | ties every cost row to a real, live Shopify SKU |
| Product Name | manual | free text | |
| Variant | manual | free text | e.g. "Black / M" |
| Collection | manual | dropdown → `CollectionTitleList` (`tbl_RAW_Collections[Title]`) | |
| Fabric Cost | manual | number | |
| Accessories Cost | manual | number | |
| Manufacturing Cost | manual | number | |
| Packaging Cost | manual | number | |
| Shipping Cost | manual | number | |
| Other Cost | manual | number | |
| Total Landed Cost | auto (locked) | `=SUM(Fabric...Other)` | |
| Selling Price | manual | number | |
| Expected Gross Margin % | auto (locked) | `=(SellingPrice-TotalLandedCost)/SellingPrice`, divide-by-zero guarded | |
| Effective From Date | manual | date | first date this cost version applies |
| Effective To Date | manual | date, optional | blank = still open-ended/current |
| Active Flag | manual | dropdown → inline list `Active,Inactive` | exactly one Active row per SKU expected |
| Overlap Warning | auto (locked) | `COUNTIFS` flags >1 Active row for the same SKU | duplicate-detection guard rail |

**Historical costing rule (enforced by process, not by lock):** when a cost
changes, add a **new** row with its own Effective From Date; set the **old**
row's Effective To Date and Active Flag = Inactive. Never edit or delete a
historical row. Phase 4's COGS calculation will match each order line to the
cost row whose SKU matches and whose Effective From/To range contains the
order's date — that's the whole point of preserving every version here.

**Relationship:** `SKU` → `tbl_RAW_Variants[SKU]` (dropdown source — the
placeholder table name; see `PHASE9_DOCUMENTATION.md` for why this points
at the placeholder rather than the post-wiring `RAW_Variants` name). Phase
4: `SKU` + date-range → `FACT_OrderLines` for time-correct COGS.

**Data Model mirror:** `DIM_ProductCostHistory` (hidden) — same time-variant
shape (CostKey, SKU, Collection, TotalLandedCost, SellingPrice,
ExpectedGrossMarginPct, EffectiveFromDate, EffectiveToDate, ActiveFlag),
loaded from this table in Phase 4.

---

## 2. Manual Expenses — `10_Expenses`, table `tbl_ManualExpenses`

Grain: one row per expense.

| Column | Type | Source / Validation | Notes |
|---|---|---|---|
| Expense ID | auto (locked) | `="EXP-"&TEXT(ROW()-header,"00000")` | |
| Expense Date | manual | date | |
| Expense Category | manual | dropdown → `LookupExpenseCategory` | unlimited, editable on 15_Settings |
| Expense Subcategory | manual | dropdown → `LookupExpenseSubcategory` | unlimited, editable on 15_Settings |
| Supplier | manual | dropdown → `SupplierNameList` (`tbl_SupplierMaster[Supplier Name]`) | optional — leave blank if none |
| Amount | manual | number | |
| Currency | manual | dropdown → `LookupCurrency` | |
| Payment Method | manual | dropdown → `LookupPaymentMethod` | |
| Related Collection | manual | dropdown → `CollectionTitleList` (live Shopify) | optional |
| Related SKU | manual | dropdown → `SKUList` (live Shopify) | optional |
| Cost Center | manual | dropdown → `LookupCostCenter` | |
| Notes | manual | free text | |
| Invoice Number | manual | free text | document reference, see §8 |
| File Name | manual | free text | document reference, see §8 |
| File Path | manual | free text | document reference, see §8 |
| Cloud Link | manual | free text (URL) | document reference, see §8 |
| Possible Duplicate | auto (locked) | `COUNTIFS` on Date+Supplier+Amount > 1 | flags likely re-entry, doesn't block it |

**Relationships:** `Supplier` → `tbl_SupplierMaster`; `Related Collection` →
`RAW_Collections`; `Related SKU` → `RAW_Variants`. **Data Model mirror:**
`FACT_ManualExpenses` (hidden), headers updated in Phase 3 to match this
richer schema.

---

## 3. Capital — `11_Capital`, table `tbl_CapitalTransactions`

Grain: one row per capital movement.

| Column | Type | Source / Validation | Notes |
|---|---|---|---|
| Capital ID | auto (locked) | `="CAP-"&TEXT(ROW()-header,"00000")` | |
| Date | manual | date | |
| Owner | manual | dropdown → `LookupOwner` | editable list, not hardcoded to one founder |
| Transaction Type | manual | dropdown → `LookupCapitalTransactionType` (Capital Contribution / Capital Withdrawal) | |
| Amount | manual | number | |
| Notes | manual | free text | |
| Entered By | manual | free text | added beyond the literal spec, for audit-trail consistency with other modules |
| Possible Duplicate | auto (locked) | `COUNTIFS` on Date+Owner+Amount > 1 | |

**Data Model mirror:** `FACT_CapitalTransactions` (hidden).

---

## 4. Supplier Master — `12_Suppliers`, table `tbl_SupplierMaster`

Grain: one row per supplier. `Supplier Name` is the key every other module's
"Supplier" dropdown reads from (`SupplierNameList`).

| Column | Type | Source / Validation | Notes |
|---|---|---|---|
| Supplier ID | auto (locked) | `="SUP-"&TEXT(ROW()-header,"00000")` | kept as the relational key even though not in the literal field list, for FK integrity from Purchase Orders |
| Supplier Name | manual | free text | dropdown source for every other "Supplier" field in the workbook |
| Supplier Type | manual | dropdown → `LookupSupplierType` | |
| Contact Person | manual | free text | |
| Phone | manual | free text | |
| Email | manual | free text | |
| Currency | manual | dropdown → `LookupCurrency` | |
| Payment Terms | manual | free text | e.g. "Net 30" |
| Status | manual | dropdown → `LookupSupplierStatus` | |
| Notes | manual | free text | |

**Data Model mirror:** `DIM_Supplier` (hidden).

---

## 5. Purchase Orders (NEW) — `12_Suppliers`

Three linked tables implementing the purchasing engine, all on the same
sheet as Supplier Master (thematically one "Suppliers & Purchasing" surface —
there was no spare slot in the fixed 01–15 visible-sheet list for a separate
tab).

### 5a. Purchase Order Header — `tbl_POHeader`
Grain: one row per PO.

| Column | Type | Source / Validation | Notes |
|---|---|---|---|
| PO Number | auto (locked) | `="PO-"&TEXT(ROW()-header,"00000")` | automatic, as required |
| Supplier | manual | dropdown → `SupplierNameList` | |
| Order Date | manual | date | |
| Expected Delivery Date | manual | date | |
| Status | manual | dropdown → `LookupPOStatus` | Draft → Approved → Sent → Partially Received → Received → Closed, or Cancelled at any point (see §5d) |
| Currency | manual | dropdown → `LookupCurrency` | |
| Notes | manual | free text | |

### 5b. Purchase Order Lines — `tbl_POLines`
Grain: one row per SKU per PO.

| Column | Type | Source / Validation | Notes |
|---|---|---|---|
| PO Number | manual | dropdown → `POHeaderList` (`tbl_POHeader[PO Number]`) | must be an existing header |
| SKU | manual | dropdown → `SKUList` (live Shopify) | |
| Quantity Ordered | manual | number | |
| Unit Cost | manual | number | |
| Total Cost | auto (locked) | `=QuantityOrdered * UnitCost` | |

### 5c. Goods Receipt — `tbl_GoodsReceipt`
Grain: one row per receiving event (a PO line can be received in several
partial shipments, each its own row).

| Column | Type | Source / Validation | Notes |
|---|---|---|---|
| PO Number | manual | dropdown → `POHeaderList` | |
| SKU | manual | dropdown → `SKUList` | |
| Goods Received Date | manual | date | |
| Quantity Received | manual | number | |
| Remaining Quantity | auto (locked) | `SUMIFS(PO Lines Qty Ordered) - SUMIFS(Goods Receipt Qty Received)` for this PO+SKU | reflects total remaining **as of all receipts to date**, not a per-row running balance — see limitation below |
| Actual Unit Cost | manual | number | what was actually paid/invoiced |
| Variance from PO | auto (locked) | `ActualUnitCost - SUMIFS(PO Lines Unit Cost)` for this PO+SKU | positive = paid more than quoted |
| Warehouse | manual | dropdown → `LookupWarehouse` | |
| Receiver | manual | free text | staff name, not a lookup (matches the "Entered By" pattern elsewhere) |

**Known limitation:** `Remaining Quantity` is computed from the *current
totals* of all Goods Receipt rows for that PO+SKU, not a row-by-row running
balance at the moment each receipt was logged. For a PO received in one or
two shipments (the common case) this is exactly right; for a PO with many
partial receipts, every row will show the same final remaining quantity
rather than a mid-sequence snapshot. A true running balance would need a
row-order-aware formula (or a helper index column) — a reasonable Phase 4+
enhancement if partial receiving turns out to be frequent.

### 5d. Status Flow
`Draft → Approved → Sent → Partially Received → Received → Closed`, with
`Cancelled` reachable from any state. Enforced as a dropdown list on
`Status`, not as an automated state machine — Excel has no native workflow
engine; the dropdown plus this documented order *is* the spreadsheet-native
implementation of "status flow."

**Future financial calculations must use received quantities, not ordered
quantities, where appropriate** (e.g. inventory valuation, landed-cost
averaging) — that's why Goods Receipt, not PO Lines, carries `Actual Unit
Cost` and `Remaining Quantity`; Phase 4's calculations should read from
Goods Receipt for anything cash/stock-real, and from PO Lines only for
"what was ordered" reporting.

**Data Model mirrors:** `FACT_PurchaseOrderHeader`, `FACT_PurchaseOrderLines`,
`FACT_GoodsReceipt` (all hidden).

---

## 6. Expense Category Master / Lookup Tables — `15_Settings`

Section "MASTER DATA LOOKUP TABLES." Eleven small, single-column, orange
(configurable) tables — every dropdown in the workbook sources one of these
via a named range, so extending a category is "add a row on 15_Settings,"
never a formula or VBA change.

| Lookup table | Named range | Starter values | Used by |
|---|---|---|---|
| `tbl_LookupExpenseCategory` | `LookupExpenseCategory` | Rent, Utilities, Salaries, Marketing, Shipping & Logistics, Packaging, Software & Subscriptions, Professional Fees, Bank Charges, Other | 10_Expenses |
| `tbl_LookupExpenseSubcategory` | `LookupExpenseSubcategory` | General, Office, Warehouse, Online Ads, Influencer, Photography, Courier, Customs & Duties, Software License, Legal, Accounting, Other | 10_Expenses |
| `tbl_LookupCostCenter` | `LookupCostCenter` | Head Office, Warehouse, E-Commerce, Marketing, Production | 10_Expenses |
| `tbl_LookupPaymentMethod` | `LookupPaymentMethod` | Bank Transfer, Cash, Credit Card, Instapay, Cheque, Other | 10_Expenses |
| `tbl_LookupCurrency` | `LookupCurrency` | EGP, USD, EUR, GBP | 10_Expenses, 12_Suppliers |
| `tbl_LookupSupplierType` | `LookupSupplierType` | Fabric, Accessories, Manufacturing, Packaging, Logistics, Marketing Agency, Software Vendor, Other | 12_Suppliers |
| `tbl_LookupSupplierStatus` | `LookupSupplierStatus` | Active, Inactive, On Hold | 12_Suppliers |
| `tbl_LookupCapitalTransactionType` | `LookupCapitalTransactionType` | Capital Contribution, Capital Withdrawal | 11_Capital |
| `tbl_LookupPOStatus` | `LookupPOStatus` | Draft, Approved, Sent, Partially Received, Received, Closed, Cancelled | 12_Suppliers |
| `tbl_LookupWarehouse` | `LookupWarehouse` | Main Warehouse, Retail Store, Third-Party Logistics | 12_Suppliers |
| `tbl_LookupOwner` | `LookupOwner` | Founder | 11_Capital |

Two dropdowns deliberately do **not** use a 15_Settings lookup, because a
better single source of truth already exists in the live Data Model:
- **SKU** (`SKUList` → `tbl_RAW_Variants[SKU]`) — Product Cost Master,
  Manual Expenses, PO Lines, Goods Receipt.
- **Collection** (`CollectionTitleList` → `tbl_RAW_Collections[Title]`) —
  Product Cost Master, Manual Expenses.
- **Supplier** (`SupplierNameList` → `tbl_SupplierMaster[Supplier Name]`) —
  Manual Expenses, PO Header, PO Lines, Goods Receipt.
- **PO Number** (`POHeaderList` → `tbl_POHeader[PO Number]`) — PO Lines,
  Goods Receipt.

This is the concrete form of "integrate with the existing Shopify Data
Model": master data never duplicates a list Shopify (or another workbook
table) already owns.

---

## 7. Validation Summary

24 dropdown validations across 5 sheets, every one with an input prompt
(shown when the cell is selected) and a stop-on-error message (shown if
something other than a list value is typed/pasted):

| Sheet | Validated columns |
|---|---|
| 05_Products | SKU, Collection, Active Flag |
| 10_Expenses | Expense Category, Expense Subcategory, Supplier, Currency, Payment Method, Related Collection, Related SKU, Cost Center |
| 11_Capital | Owner, Transaction Type |
| 12_Suppliers | Supplier Type, Currency, Status (Supplier Master) · Supplier, Status, Currency (PO Header) · PO Number, SKU (PO Lines) · PO Number, SKU, Warehouse (Goods Receipt) |

Duplicate-detection formulas (COUNTIFS-based warning columns, not hard
blocks — a flagged row can still be saved, since a human sometimes does mean
to enter two similar transactions on the same day):

| Sheet | Table | Duplicate key |
|---|---|---|
| 05_Products | Product Cost Master | SKU + Active Flag = "Active" (>1 → overlapping active cost) |
| 10_Expenses | Manual Expenses | Date + Supplier + Amount |
| 11_Capital | Capital Transactions | Date + Owner + Amount |

Validation ranges extend to row 501 on every table (~490 future entries per
table) so pasting or typing new rows keeps the dropdown and duplicate-check
without any manual re-application — comfortable multi-year headroom for a
single-brand operation.

---

## 8. Document Management

No file is ever stored inside the workbook. Every module that needs a
document reference carries the same four columns (currently: Manual
Expenses only — the only module Phase 3 asked for this on):

| Column | Purpose |
|---|---|
| Invoice Number | the supplier's/system's own document number |
| File Name | e.g. `jan-rent.pdf` |
| File Path | local/network path if not cloud-stored |
| Cloud Link | a pasted OneDrive/SharePoint/Drive URL |

**Future integration:** a later phase could replace the plain-text Cloud
Link column with a live OneDrive/SharePoint connector (Power Automate flow
on new-row, or a Power Query read of a document library's metadata) — out of
scope for Phase 3, which only had to make the reference fields exist.

---

## 9. Sheet-Level Documentation

Every sheet touched or added in Phase 3 has its in-workbook Purpose / Input
tables / Output tables / Relationships / Future data source block (the same
collapsible "Sheet Documentation" strip established in Phase 1) updated to
match. This file is the detailed column-level companion to those blocks —
the sheet strips answer "what is this sheet for," this file answers "what
does column X actually validate against."

---

## 10. What Phase 3 deliberately does NOT contain

No dashboards, no KPI cards beyond the Phase 1 placeholders already on
02–09/13 (untouched), no PivotTables, no PivotCharts, no DAX measures, no
P&L/Balance Sheet/Cash Flow. The workbook can now **store** every business
input Phase 4's financial calculations will need — Shopify data (Phase 2),
product costing with full history, manual expenses, capital, suppliers,
purchase orders, and goods receiving — but nothing here *calculates*
anything beyond the structural totals (Total Landed Cost, Total Cost,
Remaining Quantity, Variance) required for the master data itself to be
internally consistent.
