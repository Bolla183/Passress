# PASSRESS MIS — Phase 4 DAX Measure Library

Every measure below is real, considered DAX written against the star schema
`dax/README.md` describes — but none of it has been execution-tested,
because this sandbox has no Excel/Power Pivot engine to run DAX against (the
same honest caveat as Phase 2's M code, one level down: LibreOffice can't
evaluate Power Query either, but DAX doesn't exist *at all* outside a real
Data Model). Enter these into Excel in the order given — later measures
reference earlier ones by name — and use the **Reconciliation** section
(§9) as your first real test: those checks should land near zero once
real data is flowing.

**Design principle throughout:** one measure per *concept*, not one measure
per *breakdown*. `[Gross Profit]` is a single measure; "Profit per SKU,"
"Profit per Month," "Profit per Collection" are the same measure evaluated
in whatever context a PivotTable's rows or slicers provide — that's what
makes DAX context-aware, and building five near-identical measures for five
breakdowns would be exactly the duplication this phase was told to avoid.
Composite measures (`[Gross Profit]`, `[EBITDA]`, ...) reference simpler ones
by name rather than re-deriving them, so a definition only ever lives once.

---

## 0. Foundation Measures

The atomic building blocks every other section reuses.

```dax
Gross Sales =
SUMX(FACT_OrderLines, FACT_OrderLines[GrossAmount])
// Sum of Quantity x UnitPrice across every order line, before any discount
// or return. FACT_OrderLines[GrossAmount] was pre-computed in Power Query.

Discounts =
SUMX(FACT_OrderLines, FACT_OrderLines[DiscountAmount])
// Line-level discount allocation only (matches Shopify's own
// totalDiscountSet per line) — does not include order-level or code-based
// discounts not allocated down to a line; see power-query/DOCUMENTATION.md's
// RAW_OrderLines section for that boundary.

Returns =
SUM(FACT_Refunds[RefundAmount])
// RefundAmount = subtotal + tax refunded (see FACT_Refunds.pq) — so this
// line slightly overstates a pure revenue reversal by whatever tax portion
// was refunded. Documented simplification; splitting the two would need a
// second column on FACT_Refunds if ever needed.

Net Sales =
[Gross Sales] - [Discounts] - [Returns]

COGS =
SUMX(FACT_OrderLines, FACT_OrderLines[COGS])
// Uses each line's historically-correct cost, already resolved in Power
// Query via fn_GetEffectiveCost (SKU + order date -> the Product Cost
// Master row active on that date) — never today's cost applied
// retroactively. Lines with no matching cost row contribute COGS = 0 and
// are flagged; see [Lines Missing Cost] below.

Gross Profit =
[Net Sales] - [COGS]

Gross Margin % =
DIVIDE([Gross Profit], [Net Sales])

Operating Expenses =
SUM(FACT_ManualExpenses[Amount])
// Every category on 15_Settings' Expense Category lookup rolls up here
// undifferentiated — break it down by putting ExpenseCategory on a
// PivotTable's rows, not by building a measure per category.

EBITDA =
[Gross Profit] - [Operating Expenses]

Net Profit =
[EBITDA]
// BUSINESS RULE: this workbook does not separately track Depreciation &
// Amortization, Interest, or Tax as their own line items — if incurred,
// they'd be recorded as ordinary Expense Categories and are already inside
// [Operating Expenses]. EBITDA and Net Profit are therefore numerically
// identical here. If the business later wants a genuine EBITDA-vs-Net-Profit
// split, add "Depreciation," "Interest," and "Tax" to the Expense Category
// lookup, then redefine Net Profit = EBITDA minus measures that isolate
// those categories (CALCULATE([Operating Expenses], FACT_ManualExpenses[ExpenseCategory]="Depreciation"), etc.).

Net Profit Margin % =
DIVIDE([Net Profit], [Net Sales])

Units Sold =
SUM(FACT_OrderLines[Quantity])

Order Count =
DISTINCTCOUNT(FACT_OrderLines[OrderID])

Average Order Value =
DIVIDE([Net Sales], [Order Count])

Lines Missing Cost =
CALCULATE(COUNTROWS(FACT_OrderLines), FACT_OrderLines[MissingCostFlag] = TRUE)
// Reconciliation aid: a nonzero count means some order lines' COGS is
// understated (SKU had no matching Product Cost Master row on that date).
// Also listed under §9.
```

---

## 1. Profit & Loss

Every requested P&L line is already a Foundation measure — this section is
a map, not new formulas, so a P&L PivotTable knows what to put on rows:

| P&L Line | Measure |
|---|---|
| Gross Sales | `[Gross Sales]` |
| Discounts | `[Discounts]` |
| Returns | `[Returns]` |
| Net Sales | `[Net Sales]` |
| COGS | `[COGS]` |
| Gross Profit | `[Gross Profit]` |
| Gross Margin % | `[Gross Margin %]` |
| Operating Expenses | `[Operating Expenses]` |
| EBITDA | `[EBITDA]` |
| Net Profit | `[Net Profit]` |

Put `DIM_Date[MonthName]`/`[Quarter]`/`[Year]` on columns and these ten rows
on rows for a standard monthly/quarterly/annual P&L. Time-intelligence
variants (MTD/YTD/SPLY/etc.) for the headline three are in §8.

---

## 2. Balance Sheet

A balance sheet is a point-in-time snapshot, not a period flow — every
measure here uses the same "cumulative to the selected date" pattern rather
than summing just the currently-filtered period.

```dax
Capital Contributions (Period) =
CALCULATE(SUM(FACT_CapitalTransactions[Amount]), FACT_CapitalTransactions[TransactionType] = "Capital Contribution")

Capital Withdrawals (Period) =
CALCULATE(SUM(FACT_CapitalTransactions[Amount]), FACT_CapitalTransactions[TransactionType] = "Capital Withdrawal")

Net Capital (Period) =
[Capital Contributions (Period)] - [Capital Withdrawals (Period)]

Capital Invested (Cumulative) =
CALCULATE([Net Capital (Period)], FILTER(ALL(DIM_Date), DIM_Date[Date] <= MAX(DIM_Date[Date])))
// Standard "running total to the selected date" DAX pattern: for whatever
// date is in context (a single day, or the max day of a selected month/
// quarter/year), sum every capital transaction from the beginning of time
// through that date.

Retained Earnings =
CALCULATE([Net Profit], FILTER(ALL(DIM_Date), DIM_Date[Date] <= MAX(DIM_Date[Date])))
// Same running-total pattern applied to Net Profit — the standard
// definition of Retained Earnings (cumulative profit since inception).

Cumulative Net Sales =
CALCULATE([Net Sales], FILTER(ALL(DIM_Date), DIM_Date[Date] <= MAX(DIM_Date[Date])))
// Helper for Accounts Receivable below.

Cash Collected from Customers =
VAR SalesCash = CALCULATE(SUM(FACT_Payments[Amount]), FACT_Payments[Kind] IN {"SALE", "CAPTURE"})
VAR RefundCash = CALCULATE(SUM(FACT_Payments[Amount]), FACT_Payments[Kind] = "REFUND")
RETURN SalesCash - RefundCash
// BUSINESS RULE / ASSUMPTION: assumes Shopify reports refund transaction
// amounts as positive magnitudes (subtracted here), matching its documented
// behavior. If a store's payment gateway ever reports refunds as already-
// negative, this would double-subtract — verify against a known refund in
// LOG_DataQuality's first real refresh.

Cash Paid for Purchases =
SUMX(FACT_GoodsReceipt, FACT_GoodsReceipt[QuantityReceived] * FACT_GoodsReceipt[ActualUnitCost])
// Uses RECEIVED quantities and ACTUAL unit cost, not ordered/quoted —
// matches the brief's instruction that financial calculations should use
// received quantities where appropriate.

Cash Paid for Expenses =
[Operating Expenses]
// ASSUMPTION: every recorded expense is treated as paid in the period it's
// entered (no "paid vs. unpaid" status exists on Manual Expenses — see the
// Accounts Payable note below for the same underlying gap).

Accounts Receivable =
VAR NetSalesToDate = [Cumulative Net Sales]
VAR CashCollectedToDate = CALCULATE([Cash Collected from Customers], FILTER(ALL(DIM_Date), DIM_Date[Date] <= MAX(DIM_Date[Date])))
RETURN MAX(0, NetSalesToDate - CashCollectedToDate)
// Whatever cumulative net sales haven't yet shown up as collected cash is
// treated as receivable. For a DTC store where checkout = payment, this
// should normally sit near zero; a materially positive number usually means
// pending/partially-paid orders (RAW_Orders.FinancialStatus) are piling up.

Accounts Payable (Proxy) =
CALCULATE(
    SUMX(FACT_PurchaseOrderLines, FACT_PurchaseOrderLines[TotalCost]),
    FILTER(FACT_PurchaseOrderHeader, FACT_PurchaseOrderHeader[Status] <> "Closed" && FACT_PurchaseOrderHeader[Status] <> "Cancelled")
)
// FLAGGED LIMITATION (raised before Phase 4 started): neither Manual
// Expenses nor Purchase Orders has a paid/unpaid status field, so there is
// no clean source for Accounts Payable. This proxy — the total value of PO
// Lines belonging to any PO not yet Closed or Cancelled — approximates
// "committed purchase spend not yet settled." It is directional, not
// precise: a PO can be Received (goods in hand) and still count here if it
// hasn't been marked Closed, even if it was in fact paid on delivery. A
// real "Payment Status" field on both Manual Expenses and PO Header is the
// correct long-term fix.

Inventory Value =
VAR LatestKey = CALCULATE(MAX(FACT_InventoryMovements[DateKey]), ALL(DIM_Date))
RETURN
CALCULATE(
    SUMX(
        FACT_InventoryMovements,
        FACT_InventoryMovements[ResultingOnHand] *
        LOOKUPVALUE(
            DIM_ProductCostHistory[TotalLandedCost],
            DIM_ProductCostHistory[SKU], FACT_InventoryMovements[ProductKey],
            DIM_ProductCostHistory[ActiveFlag], "Active"
        )
    ),
    FACT_InventoryMovements[DateKey] = LatestKey,
    ALL(DIM_Date)
)
// Always uses the MOST RECENT inventory snapshot available, regardless of
// any date filter/slicer in the report — Inventory Value is inherently a
// "current state" figure given FACT_InventoryMovements is a periodic
// snapshot, not a true movement ledger (see that table's own header note).
// LOOKUPVALUE errors if a SKU somehow has more than one Active cost row —
// that should never happen (Product Cost Master's Overlap Warning column
// catches it), but if this measure ever throws an error, check there first.

Assets =
[Cash Position (Direct, Cumulative)] + [Inventory Value] + [Accounts Receivable]

Liabilities =
[Accounts Payable (Proxy)]

Equity =
[Capital Invested (Cumulative)] + [Retained Earnings]

Balance Sheet Check =
[Assets] - [Liabilities] - [Equity]
// Should be ~0. See §9 — this is one of the required reconciliation checks,
// not just a display line.
```

`[Cash Position (Direct, Cumulative)]` is defined in §3 (Cash Flow) and
reused here rather than duplicated — Assets needs it, but it's fundamentally
a cash-flow concept.

---

## 3. Cash Flow

```dax
Cash Flow from Operating Activities =
[Cash Collected from Customers] - [Cash Paid for Expenses] - [Cash Paid for Purchases]
// Inventory purchases sit in Operating (not Investing) — for a merchandise
// business, buying stock is core operations, not a capital investment.

Cash Flow from Investing Activities =
0
// BUSINESS RULE: this workbook has no fixed-asset / capex tracking module —
// there's nowhere for equipment, leasehold improvements, etc. to be
// recorded as an investing outflow. Hardcoded to 0 rather than silently
// omitted, so it's visible on every Cash Flow statement as a known gap. A
// future Fixed Assets module (mirroring Purchase Orders' pattern) would
// replace this with a real calculation.

Cash Flow from Financing Activities =
[Net Capital (Period)]

Net Cash Flow =
[Cash Flow from Operating Activities] + [Cash Flow from Investing Activities] + [Cash Flow from Financing Activities]

Cash Position (Direct, Cumulative) =
CALCULATE([Net Cash Flow], FILTER(ALL(DIM_Date), DIM_Date[Date] <= MAX(DIM_Date[Date])))
// The "direct" / bottom-up cash position: actual cash movements, summed
// since inception. Compared against the "indirect" plug version in §9 as
// the core reconciliation check for the whole financial engine.

Cash Position (Indirect, Plug) =
[Equity] + [Liabilities] - [Inventory Value] - [Accounts Receivable]
// Derived algebraically from the accounting identity Assets = Liabilities +
// Equity, solved for Cash. Used ONLY for reconciliation (§9) — never as the
// number actually reported as "cash," since it inherits any imprecision in
// Accounts Payable's proxy definition.
```

---

## 4. Product Profitability

`[Gross Profit]`, `[Net Sales]`, `[Units Sold]` etc. are already fully
context-aware — put any of these on a PivotTable's Values with `DIM_Product`,
`DIM_Collection`, `DIM_Customer`, or `DIM_Date[MonthName]` on Rows and you
have Profit per SKU / per Collection / per Customer / per Month, with zero
new measures. `DIM_Product[PrimarySupplierID]` relates to `DIM_Supplier`
(see `dax/README.md`'s relationship list), so Profit per Supplier works the
same way — with the caveat documented on `DIM_Product.pq`: PrimarySupplierID
is a best-effort "most recent Goods Receipt for this SKU," not a guaranteed
canonical supplier, since nothing in the schema declares one SKU = one
supplier permanently.

Two genuinely new measures — "per Supplier/Customer" implies an *average*,
which existing measures alone don't give:

```dax
Average Profit per Order =
DIVIDE([Gross Profit], [Order Count])

Average Profit per Customer =
DIVIDE([Gross Profit], DISTINCTCOUNT(FACT_OrderLines[CustomerKey]))
```

---

## 5. Customer Metrics

```dax
New Customers =
CALCULATE(
    DISTINCTCOUNT(DIM_Customer[CustomerKey]),
    FILTER(DIM_Customer, DIM_Customer[FirstOrderDate] >= MIN(DIM_Date[Date]) && DIM_Customer[FirstOrderDate] <= MAX(DIM_Date[Date]))
)
// Customers whose very first order fell inside the currently selected
// period. DIM_Customer isn't related to DIM_Date (a customer's first-order
// date shouldn't filter the whole customer dimension) — this measure reads
// the ambient DIM_Date filter's MIN/MAX directly instead.

Customers Active (Current Period) =
DISTINCTCOUNT(FACT_OrderLines[CustomerKey])

Returning Customers =
CALCULATE(
    DISTINCTCOUNT(FACT_OrderLines[CustomerKey]),
    FILTER(DIM_Customer, DIM_Customer[FirstOrderDate] < MIN(DIM_Date[Date]))
)
// Customers who placed an order in the current period AND whose first-ever
// order was before this period started.

Customer Lifetime Value (Historical) =
CALCULATE(
    DIVIDE([Cumulative Net Sales], DISTINCTCOUNT(FACT_OrderLines[CustomerKey])),
    FILTER(ALL(DIM_Date), DIM_Date[Date] <= MAX(DIM_Date[Date]))
)
// This is HISTORICAL CLV (cumulative net sales per customer to date), not a
// predictive lifetime-value model — a true predictive CLV needs assumptions
// (expected customer lifespan, discount rate) this workbook has no basis to
// invent. Rename or extend deliberately if a predictive model is wanted
// later; don't silently repurpose this one.

Purchase Frequency =
DIVIDE([Order Count], DISTINCTCOUNT(FACT_OrderLines[CustomerKey]))
// Orders per active customer within the selected period.

Retained Customers (MoM) =
CALCULATE(
    DISTINCTCOUNT(FACT_OrderLines[CustomerKey]),
    FILTER(
        VALUES(FACT_OrderLines[CustomerKey]),
        CALCULATE(COUNTROWS(FACT_OrderLines), DATEADD(DIM_Date[Date], -1, MONTH)) > 0
    )
)
// Customers active in the current period who were ALSO active in the prior
// month. Month-over-month specifically (see DATEADD's -1, MONTH) — for a
// different cadence (week-over-week, quarter-over-quarter), copy this
// measure and change MONTH to WEEK/QUARTER, matching whatever granularity
// is on the PivotTable.

Customer Retention Rate (MoM) =
DIVIDE([Retained Customers (MoM)], CALCULATE([Customers Active (Current Period)], DATEADD(DIM_Date[Date], -1, MONTH)))
// Retained / (customers active in the PRIOR month) — the standard
// retention-rate definition.
```

**Customer Cohorts** is a PivotTable layout, not a single measure:
`DIM_Customer[CohortMonth]` (added to `DIM_Product.pq`'s sibling
`DIM_Customer.pq` specifically for this) on Rows, `DIM_Date[MonthName]`/
`[Year]` on Columns, `[Net Sales]` or `[Customers Active (Current Period)]`
in Values gives the classic cohort matrix — building "per-cohort" measures
would just be this same pivot pre-collapsed into formulas, which is exactly
the duplication this phase avoids.

---

## 6. Inventory Metrics

```dax
Average Inventory Value =
AVERAGEX(
    VALUES(FACT_InventoryMovements[DateKey]),
    CALCULATE(
        SUMX(
            FACT_InventoryMovements,
            FACT_InventoryMovements[ResultingOnHand] *
            LOOKUPVALUE(DIM_ProductCostHistory[TotalLandedCost], DIM_ProductCostHistory[SKU], FACT_InventoryMovements[ProductKey], DIM_ProductCostHistory[ActiveFlag], "Active")
        )
    )
)
// Unlike [Inventory Value] (always "now"), this respects the current date
// filter — it averages every snapshot date that falls inside the selected
// period. With one refresh per day, a month with 20 refreshes averages 20
// snapshots; a month with one refresh averages just that one. Turnover
// accuracy improves with refresh frequency — see the header note on
// FACT_InventoryMovements.pq for why a true daily ledger isn't available.

Inventory Turnover =
DIVIDE([COGS], [Average Inventory Value])
// Standard ratio: COGS incurred over the period / average inventory value
// held during that same period.

Days of Inventory =
DIVIDE([Average Inventory Value], [COGS]) * (DATEDIFF(MIN(DIM_Date[Date]), MAX(DIM_Date[Date]), DAY) + 1)
// Backward-looking: how many days of the PERIOD'S OWN average sales pace
// the average inventory represents. Period-length-aware (uses the actual
// number of days in whatever's selected — a quarter and a year shouldn't
// produce the same "days" answer for the same turnover ratio). If your
// Power Pivot engine doesn't support DATEDIFF (an occasionally newer DAX
// function), replace the multiplier with a fixed 365/91/30 depending on
// the report's granularity.

Stock Coverage (Days) =
VAR RecentDailyCOGS = DIVIDE(CALCULATE([COGS], DATESINPERIOD(DIM_Date[Date], MAX(DIM_Date[Date]), -30, DAY)), 30)
RETURN DIVIDE([Inventory Value], RecentDailyCOGS)
// DELIBERATELY DIFFERENT from Days of Inventory: this is FORWARD-looking —
// "at the recent (trailing 30-day) sales pace, how many days would today's
// on-hand inventory last?" — the more operationally useful number for
// reorder-timing decisions. Days of Inventory (above) explains historical
// efficiency; Stock Coverage answers "should I reorder soon."

Slow Moving SKU Count =
COUNTROWS(
    FILTER(
        VALUES(DIM_Product[ProductKey]),
        CALCULATE([Units Sold], DATESINPERIOD(DIM_Date[Date], MAX(DIM_Date[Date]), -90, DAY)) < 3
            && [Inventory Value] > 0
    )
)
// BUSINESS RULE (adjust the threshold to taste): "slow moving" = fewer than
// 3 units sold in the trailing 90 days, while still holding stock. The "3"
// and "90" are business judgment calls, not derived from anything — change
// them directly in this formula if the threshold should differ.

Dead Stock SKU Count =
COUNTROWS(
    FILTER(
        VALUES(DIM_Product[ProductKey]),
        CALCULATE([Units Sold], DATESINPERIOD(DIM_Date[Date], MAX(DIM_Date[Date]), -180, DAY)) = 0
            && [Inventory Value] > 0
    )
)
// Same pattern, harder threshold: ZERO units sold in the trailing 180 days
// while still holding stock. Both this and Slow Moving SKU Count are
// anchored on MAX(DIM_Date[Date]) in whatever filter context they're
// evaluated in — put them on a PivotTable WITHOUT a restrictive date filter
// (or at the grand-total level) so that anchor lands on the true latest date.
```

---

## 7. Executive KPIs

An executive view is a curated subset, not new logic — pulling the headline
number from each section above:

| KPI | Measure |
|---|---|
| Net Sales | `[Net Sales]` |
| Gross Margin % | `[Gross Margin %]` |
| Net Profit | `[Net Profit]` |
| Cash Position | `[Cash Position (Direct, Cumulative)]` |
| Inventory Value | `[Inventory Value]` |
| Capital Invested | `[Capital Invested (Cumulative)]` |
| Average Order Value | `[Average Order Value]` |
| New Customers | `[New Customers]` |
| Customer Retention Rate | `[Customer Retention Rate (MoM)]` |
| Inventory Turnover | `[Inventory Turnover]` |

Two new composite ratios genuinely belong at the executive level and don't
exist yet:

```dax
Operating Expense Ratio % =
DIVIDE([Operating Expenses], [Net Sales])
// Expenses as a % of revenue — the standard "how lean is the operation" KPI.

Break-Even Net Sales =
DIVIDE([Operating Expenses], [Gross Margin %])
// Classic break-even formula (fixed costs / contribution margin %): the
// Net Sales level at which Net Profit would be exactly zero, given the
// period's actual gross margin. Treats all Operating Expenses as fixed —
// a simplification (some, like payment-gateway fees, technically scale
// with sales) reasonable for a single-brand DTC operation at this scale.
```

Revenue Growth % (YoY) is defined in §8, alongside the rest of the
time-intelligence layer it depends on.

---

## 8. Time Intelligence

**Daily / Weekly / Monthly / Quarterly / Yearly are not measures at all** —
they're whichever `DIM_Date` column (`Day`, `Week`, `MonthName`, `Quarter`,
`Year`) is on a PivotTable's rows or columns. Every measure above
automatically re-aggregates to that grain. Building a `[Net Sales Daily]`
measure alongside `[Net Sales Monthly]` would just be the same number
computed twice — this is the single most common way DAX models end up
bloated, and exactly what "no duplicated calculations" is warning against.

What genuinely needs its own measure is a **comparison across periods** —
MTD, YTD, previous period, same period last year, and the three rolling
windows. Below is the full pattern applied to the three P&L headline
measures plus Order Count. **To extend it to any other measure** (COGS,
Operating Expenses, Units Sold, ...), copy a block and replace every
`[Net Sales]` with the new measure name and rename the block's own measures
to match — the pattern itself never changes.

```dax
-- Net Sales -----------------------------------------------------------
Net Sales MTD = TOTALMTD([Net Sales], DIM_Date[Date])
Net Sales QTD = TOTALQTD([Net Sales], DIM_Date[Date])
Net Sales YTD = TOTALYTD([Net Sales], DIM_Date[Date])
Net Sales Previous Period = CALCULATE([Net Sales], DATEADD(DIM_Date[Date], -1, MONTH))
Net Sales Same Period Last Year = CALCULATE([Net Sales], SAMEPERIODLASTYEAR(DIM_Date[Date]))
Net Sales Rolling 30 Days = CALCULATE([Net Sales], DATESINPERIOD(DIM_Date[Date], MAX(DIM_Date[Date]), -30, DAY))
Net Sales Rolling 90 Days = CALCULATE([Net Sales], DATESINPERIOD(DIM_Date[Date], MAX(DIM_Date[Date]), -90, DAY))
Net Sales Rolling 12 Months = CALCULATE([Net Sales], DATESINPERIOD(DIM_Date[Date], MAX(DIM_Date[Date]), -12, MONTH))

-- Gross Profit ---------------------------------------------------------
Gross Profit MTD = TOTALMTD([Gross Profit], DIM_Date[Date])
Gross Profit QTD = TOTALQTD([Gross Profit], DIM_Date[Date])
Gross Profit YTD = TOTALYTD([Gross Profit], DIM_Date[Date])
Gross Profit Previous Period = CALCULATE([Gross Profit], DATEADD(DIM_Date[Date], -1, MONTH))
Gross Profit Same Period Last Year = CALCULATE([Gross Profit], SAMEPERIODLASTYEAR(DIM_Date[Date]))
Gross Profit Rolling 30 Days = CALCULATE([Gross Profit], DATESINPERIOD(DIM_Date[Date], MAX(DIM_Date[Date]), -30, DAY))
Gross Profit Rolling 90 Days = CALCULATE([Gross Profit], DATESINPERIOD(DIM_Date[Date], MAX(DIM_Date[Date]), -90, DAY))
Gross Profit Rolling 12 Months = CALCULATE([Gross Profit], DATESINPERIOD(DIM_Date[Date], MAX(DIM_Date[Date]), -12, MONTH))

-- Net Profit -----------------------------------------------------------
Net Profit MTD = TOTALMTD([Net Profit], DIM_Date[Date])
Net Profit QTD = TOTALQTD([Net Profit], DIM_Date[Date])
Net Profit YTD = TOTALYTD([Net Profit], DIM_Date[Date])
Net Profit Previous Period = CALCULATE([Net Profit], DATEADD(DIM_Date[Date], -1, MONTH))
Net Profit Same Period Last Year = CALCULATE([Net Profit], SAMEPERIODLASTYEAR(DIM_Date[Date]))
Net Profit Rolling 30 Days = CALCULATE([Net Profit], DATESINPERIOD(DIM_Date[Date], MAX(DIM_Date[Date]), -30, DAY))
Net Profit Rolling 90 Days = CALCULATE([Net Profit], DATESINPERIOD(DIM_Date[Date], MAX(DIM_Date[Date]), -90, DAY))
Net Profit Rolling 12 Months = CALCULATE([Net Profit], DATESINPERIOD(DIM_Date[Date], MAX(DIM_Date[Date]), -12, MONTH))

-- Order Count ------------------------------------------------------------
Order Count MTD = TOTALMTD([Order Count], DIM_Date[Date])
Order Count QTD = TOTALQTD([Order Count], DIM_Date[Date])
Order Count YTD = TOTALYTD([Order Count], DIM_Date[Date])
Order Count Previous Period = CALCULATE([Order Count], DATEADD(DIM_Date[Date], -1, MONTH))
Order Count Same Period Last Year = CALCULATE([Order Count], SAMEPERIODLASTYEAR(DIM_Date[Date]))
Order Count Rolling 30 Days = CALCULATE([Order Count], DATESINPERIOD(DIM_Date[Date], MAX(DIM_Date[Date]), -30, DAY))
Order Count Rolling 90 Days = CALCULATE([Order Count], DATESINPERIOD(DIM_Date[Date], MAX(DIM_Date[Date]), -90, DAY))
Order Count Rolling 12 Months = CALCULATE([Order Count], DATESINPERIOD(DIM_Date[Date], MAX(DIM_Date[Date]), -12, MONTH))

-- The one genuinely new ratio this layer enables -----------------------
Revenue Growth % (YoY) =
DIVIDE([Net Sales] - [Net Sales Same Period Last Year], [Net Sales Same Period Last Year])
```

**Note on "Previous Period":** hardcoded to `-1, MONTH` above since month is
the most common reporting cadence. If a report is built at quarter or year
grain, swap `MONTH` for `QUARTER`/`YEAR` in a copy of that specific measure
— `DATEADD` interprets the interval literally, it doesn't infer it from
what's on the PivotTable.

---

## 9. Reconciliation & Validation

Every financial statement above should tie back to source data. Run these
after every refresh — ideally as their own small PivotTable or table on a
future "Data Quality" view (Phase 5), not buried inside the P&L.

```dax
Reconciliation: Balance Sheet Check =
[Balance Sheet Check]
// Assets - Liabilities - Equity. Target: 0. A nonzero value here and in
// the Cash Variance check below should move together — they're measuring
// the same underlying gap two different ways.

Reconciliation: Cash Variance =
[Cash Position (Direct, Cumulative)] - [Cash Position (Indirect, Plug)]
// Target: 0. A nonzero value points at the Accounts Payable proxy's
// imprecision (see its definition in §2) or a genuine data gap, not a
// formula bug in either Cash Position measure individually.

Reconciliation: Net Sales Tie-Out (FACT vs RAW) =
[Net Sales] - SUMX(RAW_Orders, RAW_Orders[TotalPrice] - RAW_Orders[TotalDiscounts])
// Ties the line-level aggregation (FACT_OrderLines, this workbook's own
// build) back to Shopify's own order-level totals (RAW_Orders, straight
// from the API). RUN THIS ONE UNFILTERED (grand total, no date slicer) —
// RAW_Orders was never related to DIM_Date in the Data Model (it's staging,
// not part of the star schema), so a period filter wouldn't apply to it
// correctly. Target: ~0 (small rounding aside); a material gap usually
// means a line-item edge case (see RAW_OrderLines' documented 50-line cap)
// or a returns/tax treatment mismatch worth investigating line by line.

Reconciliation: Refund Orphan Count =
COUNTROWS(FILTER(FACT_Refunds, ISBLANK(RELATED(FACT_OrderLines[ProductKey]))))
// Counts refund rows whose OrderLineKey doesn't match any row in
// FACT_OrderLines — a data-integrity check on the FACT_OrderLines <->
// FACT_Refunds relationship. Target: 0.

Reconciliation: Lines Missing Cost =
[Lines Missing Cost]
// Repeated here from §0 as the standard first check after any refresh —
// a nonzero count means Gross Profit/COGS are understated for those SKUs
// until Product Cost Master gets an Effective-dated row covering them.
```

---

## What's still deliberately missing

No PivotTables, PivotCharts, or KPI cards use any of this yet — that's
Phase 5. No slicers, no conditional formatting, no layout decisions. This
file is the computation layer only, exactly as scoped.
