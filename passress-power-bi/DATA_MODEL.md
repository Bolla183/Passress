# PASSRESS Power BI — Data Model Design

This is the foundation every page (built now or later) sits on. It's
deliberately small: **5 tables** for this phase (Sales page), growing to
roughly **8–9 tables total** once every page in the brief is built —
nowhere near the 27-table star schema the retired Excel MIS project used,
because Power BI doesn't need most of what that complexity was there to
work around (see "Why this is simpler than the Excel version" at the
bottom).

---

## Star schema — this phase (Sales page)

```
                    ┌───────────────┐
                    │   DIM_Date    │
                    └───────┬───────┘
                            │ DateKey
              ┌─────────────┼─────────────┐
              │                           │
      ┌───────▼────────┐          ┌───────▼────────┐
      │ FACT_OrderLines │          │  FACT_Returns   │
      └───┬────────┬────┘          └───────┬────────┘
          │        │                       │
   ProductKey  CustomerKey            ProductKey
          │        │                       │
  ┌───────▼──┐ ┌───▼─────────┐            │
  │DIM_Product│ │DIM_Customer │◄───────────┘
  └──────────┘ └─────────────┘
```

All relationships are **single-direction, one-to-many**, Dimension → Fact
— the standard, fastest-performing Power BI pattern. Nothing bidirectional
(bidirectional filtering is a common cause of slow, hard-to-debug reports
and there's no reason to need it here).

### FACT_OrderLines
Grain: **one row per order line item**. The main sales fact table — almost
everything on the Sales and Executive Dashboard pages reads this.

| Column | Type | Notes |
|---|---|---|
| `DateKey` | whole number | Order created date, `yyyyMMdd` — joins to `DIM_Date` |
| `OrderID` | text | Shopify order GID |
| `OrderNumber` | text | Human-readable order number (`#1001`) |
| `ProductKey` | text | Joins to `DIM_Product` |
| `CustomerKey` | text | Joins to `DIM_Customer` |
| `SKU` | text | Kept on the fact for convenience; not a relationship |
| `Quantity` | whole number | Units on this line |
| `UnitPrice` | decimal | Price per unit before discount |
| `LineDiscount` | decimal | Discount allocated to this line |
| `NetAmount` | decimal | `(UnitPrice × Quantity) − LineDiscount` — the "Revenue" the Sales page reports before returns |
| `Channel` | text | Online Store / POS / etc. — see the flagged uncertainty in `power-query/RAW_OrderLines.pq` |
| `ShippingCountry` | text | Kept flat on the fact (not a separate geography table) — this workbook doesn't need country-level drill-down beyond a single "Sales by Country" chart, so a whole `DIM_Geography` table would be complexity with no payoff |

**Hidden from report view**: `OrderID`, `SKU` (kept for drill-through/
troubleshooting, not meant to be dragged onto a visual directly).

### FACT_Returns
Grain: **one row per refunded line item**. Small, deliberately separate
from `FACT_OrderLines` rather than merged into it — a return is a
different event on a different date, and keeping it separate means
"Revenue" and "Returns" are two clean, independently correct numbers
instead of one table doing two jobs.

| Column | Type | Notes |
|---|---|---|
| `DateKey` | whole number | Refund date — joins to `DIM_Date` |
| `OrderID` | text | Original order |
| `ProductKey` | text | Joins to `DIM_Product` |
| `Quantity` | whole number | Units returned |
| `RefundAmount` | decimal | Amount refunded for this line |

**Hidden from report view**: `OrderID`.

### DIM_Product
Grain: one row per product (not per variant — see the note in
`power-query/DIM_Product.pq` on why variant-level detail isn't needed for
this phase).

| Column | Type | Notes |
|---|---|---|
| `ProductKey` | text | Primary key |
| `ProductID` | text | Shopify product GID |
| `SKU` | text | |
| `Title` | text | Shown on every "Top Products" visual |
| `Category` | text | Shopify's `productType` field |
| `Collection` | text | **Primary collection only** — see below |
| `Vendor` | text | |
| `Status` | text | Active / Draft / Archived |

**Deliberate simplification — "Collection" is single-valued.** In Shopify,
a product can belong to more than one collection (a true many-to-many
relationship). Modeling that correctly needs a bridge table between
Product and Collection — real added complexity for a business-value payoff
this brief doesn't ask for (nothing here needs "show me every collection a
product is in," only "which collection does this product's Sales roll up
under"). `Collection` here is the product's **first/primary collection
only**, resolved in Power Query. Flagged here so it's a documented
decision, not a silent gap.

**Hidden from report view**: `ProductID`.

### DIM_Customer

| Column | Type | Notes |
|---|---|---|
| `CustomerKey` | text | Primary key |
| `CustomerID` | text | Shopify customer GID |
| `Name` | text | |
| `Email` | text | |
| `Country` | text | |

**Hidden from report view**: `CustomerID`, `Email` (PII — visible in the
model for lookups, not meant to be dragged onto a public-facing visual).

**Not pulled yet — `FirstOrderDate`**: Shopify's Customer object doesn't
expose it as a direct field. Needed later for the Customers page (New vs.
Returning); will be computed from `FACT_OrderLines` (`MIN` order date per
customer) when that page is built, not sourced from this query.

### DIM_Date
Standard calendar table, `Date.pq` generates it (Power Query, same pattern
as the retired Excel project — no reason to change a working approach).
Covers 2023-01-01 through 2030-12-31.

| Column | Type | Notes |
|---|---|---|
| `DateKey` | whole number | `yyyyMMdd` — the join key |
| `Date` | date | **Marked as the Data Model's Date Table** (Model view → right-click `DIM_Date` → Mark as date table) |
| `Year` | whole number | |
| `Quarter` | text | `"Q1"`, etc. |
| `MonthNumber` | whole number | For sorting `MonthName` correctly |
| `MonthName` | text | `"Jan"`, etc. — sort-by-column set to `MonthNumber` |
| `Week` | whole number | ISO week number |
| `Day` | whole number | |

This one table is what makes the Daily/Weekly/Monthly/Quarterly/Yearly
switcher (Field Parameters, built in a later phase alongside the Executive
Dashboard) work — every trend visual filters through it.

---

## Tables planned for later phases (not built yet)

Listed here so the model's eventual shape is visible now, even though only
Sales-page tables are built this phase — avoids redesigning the foundation
every time a new page is added.

| Table | Feeds | Phase |
|---|---|---|
| `FACT_Expenses` | Finance page, Executive Dashboard expense breakdown | When Finance page is built |
| `FACT_InventoryLevels` | Inventory page, Products page stock status | When Inventory page is built |
| `DIM_Campaign` + a marketing spend fact | Marketing page | When Marketing page is built — **flagged now**: Shopify's Admin API doesn't expose ad spend or campaign-level marketing data; this will need a separate source (manual entry, or an ads-platform connector) the same way the Excel project's "Marketing-Ready Layer" was reserved but never connected |

No other tables are anticipated. This model does not need a bridge table,
a junk dimension, or a role-playing date table for anything in the full
8-page brief — deliberately kept to what's actually required.

---

## Why this is simpler than the Excel version

The Excel MIS project needed 27 tables and an entire documented "table
naming lifecycle" (placeholder tables vs. post-wiring tables) because of
one specific Excel limitation: a Power Query table loaded into an Excel
worksheet is a *different object* from the Data Model table it also feeds,
and named ranges/formulas had to reference the worksheet copy by a name
that changed once real data replaced the Phase 1 placeholder — the exact
bug class that caused the file-corruption issue fixed this session.

**Power BI has no equivalent problem.** A Power Query table in Power BI
loads directly into the one Data Model — there's no separate "worksheet
table" copy, no placeholder-vs-live naming split, and therefore no
class of bug where a formula silently breaks (or worse, corrupts the file)
because it pointed at the wrong version of a table name. This is a real,
structural advantage of the Power BI approach for this project, not just a
preference.
