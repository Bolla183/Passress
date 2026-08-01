# PASSRESS Power BI — Sales Page DAX Measures

Every measure PASSRESS's Sales page needs, and nothing else. Enter in
Power BI Desktop: right-click `FACT_OrderLines` in the Fields pane → New
Measure → paste. Enter in the order listed — later measures reference
earlier ones by name.

**Design rule, carried over from what worked in the Excel project:** one
measure per *concept*, never one measure per *chart*. "Top Products,"
"Sales by Collection," "Sales by Category," "Sales by Channel," "Sales by
Country," and "Sales Trend" are **not** six measures — they're the same
`[Revenue]` measure placed on six different visuals, each with a different
field (`DIM_Product[Title]`, `DIM_Product[Collection]`, `DIM_Product
[Category]`, `FACT_OrderLines[Channel]`, `FACT_OrderLines[ShippingCountry]`,
`DIM_Date[Date]`) doing the breakdown. Building six near-identical measures
instead would be exactly the maintenance burden this project is trying to
avoid — the owner would have to remember to update six formulas every time
the definition of "Revenue" changes, instead of one.

---

```dax
Gross Sales =
SUMX(FACT_OrderLines, FACT_OrderLines[UnitPrice] * FACT_OrderLines[Quantity])
// Before any discount or return.

Discounts =
SUM(FACT_OrderLines[LineDiscount])

Returns =
SUM(FACT_Returns[RefundAmount])

Revenue =
[Gross Sales] - [Discounts] - [Returns]
// This is what every "Revenue" card/chart across the whole report means —
// net of discounts and returns. If a future page needs a pre-return figure
// specifically, that's [Gross Sales] - [Discounts], not a new measure.

Orders =
DISTINCTCOUNT(FACT_OrderLines[OrderID])

Average Order Value =
DIVIDE([Revenue], [Orders])

Units Sold =
SUM(FACT_OrderLines[Quantity])
```

## What's deliberately not here yet

- **Time intelligence** (MTD/YoY/Previous Period): not requested for the
  Sales page specifically in the brief, and the Daily/Weekly/Monthly/
  Quarterly/Yearly switcher (Field Parameters) covers "change the
  granularity" without needing a dedicated comparison measure. If the
  Executive Dashboard phase needs a "vs. last year" figure, that's the
  moment to add `Revenue Same Period Last Year = CALCULATE([Revenue],
  SAMEPERIODLASTYEAR(DIM_Date[Date]))` — not before it's actually used.
- **Profit/margin measures**: need `DIM_Product[UnitCost]`, which is
  already in the model, but Gross Profit/Margin % belong conceptually to
  the Finance and Products pages, not Sales — building them now, unused,
  would be exactly the "add it because we might need it" over-engineering
  the brief explicitly warned against. Added when those pages are built.
- **Returns as a % of sales, AOV trend, etc.**: same reasoning — real
  candidates for later pages, not manufactured now to look complete.

## Blank/zero handling

`DIVIDE()` is used for the one ratio here (`Average Order Value`) — returns
blank rather than erroring if `Orders` is ever 0 (a brand-new store with no
orders yet, for instance). Every other measure is a plain `SUM`/`SUMX`,
which naturally returns blank on an empty filter (no special handling
needed — this is correct DAX behavior, not a gap).
