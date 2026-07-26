# PASSRESS MIS — Phase 5 DAX Addendum: Targets, Budget, Variance

Additive to `MEASURES.md` — nothing in that file changed. Enter these the
same way (Power Pivot → New Measure), after everything in `MEASURES.md`
already exists (several measures below reference Phase 4 measures by name).

**Setup requirement:** `tbl_KPITargets` and `tbl_Budget` (both new Phase 5
tables — 15_Settings and 08_Finance respectively) must be added to the Data
Model (`dax/README.md` Step 2) before any measure below will resolve.

---

## KPI Targets

One `LOOKUPVALUE` per target, reading `tbl_KPITargets[Target Value]` by
`tbl_KPITargets[KPI Name]` — a single source (editable on 15_Settings) for
every dashboard's Actual-vs-Target comparison, rather than a hardcoded
number baked into each card.

```dax
Sales Target = LOOKUPVALUE(tbl_KPITargets[Target Value], tbl_KPITargets[KPI Name], "Sales Target")
Margin Target = LOOKUPVALUE(tbl_KPITargets[Target Value], tbl_KPITargets[KPI Name], "Margin Target")
Orders Target = LOOKUPVALUE(tbl_KPITargets[Target Value], tbl_KPITargets[KPI Name], "Orders Target")
Inventory Target = LOOKUPVALUE(tbl_KPITargets[Target Value], tbl_KPITargets[KPI Name], "Inventory Target")
Inventory Turnover Target = LOOKUPVALUE(tbl_KPITargets[Target Value], tbl_KPITargets[KPI Name], "Inventory Turnover Target")
AOV Target = LOOKUPVALUE(tbl_KPITargets[Target Value], tbl_KPITargets[KPI Name], "AOV Target")
Repeat Customer % Target = LOOKUPVALUE(tbl_KPITargets[Target Value], tbl_KPITargets[KPI Name], "Repeat Customer % Target")
```

`CAC Target` and `ROAS Target` are stored on `tbl_KPITargets` (editable
now) but have no matching **Actual** measure yet — CAC needs ad spend
(`FACT_MarketingSpend`, deliberately unbuilt — see the Marketing-Ready
Layer) and ROAS needs the same. `Conversion Rate Target` has the same gap:
the Shopify Admin API has no storefront-traffic/session data, so there's no
"sessions" denominator to compute an actual conversion rate against. All
three targets are ready to go the moment their data source exists — that's
the point of preparing the target now — but don't build an `[Actual CAC]`
measure by inventing a stand-in denominator; leave it absent until real
spend/traffic data exists so a missing number stays honestly missing
instead of quietly wrong.

```dax
Sales Variance = [Net Sales] - [Sales Target]
Sales Attainment % = DIVIDE([Net Sales], [Sales Target])
Margin Variance = [Gross Margin %] - [Margin Target]
Orders Variance = [Order Count] - [Orders Target]
Orders Attainment % = DIVIDE([Order Count], [Orders Target])
AOV Variance = [Average Order Value] - [AOV Target]
Inventory Variance = [Inventory Value] - [Inventory Target]
// Inventory Target is a CEILING (avoid overstock), not a floor — a
// POSITIVE variance here means overstocked, unlike every other variance
// above where positive means "ahead of plan." Worth a distinct icon/color
// on whatever dashboard displays it, not the same green-up/red-down logic
// as Sales or Orders variance.
Inventory Turnover Variance = [Inventory Turnover] - [Inventory Turnover Target]
Repeat Customer % Actual =
DIVIDE([Returning Customers], [Returning Customers] + [New Customers])
// The straightforward "share of active customers this period who are
// returning" reading. Note this is a DIFFERENT question from Customer
// Retention Rate (MoM) in MEASURES.md (which asks "of last month's
// customers, what fraction came back") — both are legitimate "repeat
// customer" metrics answering different questions; this one matches the
// KPI Target's plain-English framing.
Repeat Customer % Variance = [Repeat Customer % Actual] - [Repeat Customer % Target]
```

---

## Budget

`tbl_Budget` (08_Finance) supports both grains in one table: a row with
`Month` blank is a yearly budget line for that `Year` + `Category`; a row
with `Month` filled is a monthly line. The measures below read whichever
grain matches the current filter context.

```dax
Revenue Budget (Period) =
CALCULATE(
    SUM(tbl_Budget[Budget Amount]),
    tbl_Budget[Category] = "Revenue",
    tbl_Budget[Year] = YEAR(MAX(DIM_Date[Date])),
    FILTER(tbl_Budget, ISBLANK(tbl_Budget[Month]) || tbl_Budget[Month] = MONTH(MAX(DIM_Date[Date])))
)
// Picks up a monthly line for the current month if one exists, otherwise
// falls back to that year's yearly line. If BOTH exist for the same
// Year+Category, this sums them (a data-entry situation to avoid — keep
// either a yearly OR monthly line per Year+Category, not both).

Expense Budget (Period) =
CALCULATE(
    SUM(tbl_Budget[Budget Amount]),
    tbl_Budget[Category] = "Expense",
    tbl_Budget[Year] = YEAR(MAX(DIM_Date[Date])),
    FILTER(tbl_Budget, ISBLANK(tbl_Budget[Month]) || tbl_Budget[Month] = MONTH(MAX(DIM_Date[Date])))
)

Marketing Budget (Period) =
CALCULATE(
    SUM(tbl_Budget[Budget Amount]),
    tbl_Budget[Category] = "Marketing",
    tbl_Budget[Year] = YEAR(MAX(DIM_Date[Date])),
    FILTER(tbl_Budget, ISBLANK(tbl_Budget[Month]) || tbl_Budget[Month] = MONTH(MAX(DIM_Date[Date])))
)

Purchasing Budget (Period) =
CALCULATE(
    SUM(tbl_Budget[Budget Amount]),
    tbl_Budget[Category] = "Purchasing",
    tbl_Budget[Year] = YEAR(MAX(DIM_Date[Date])),
    FILTER(tbl_Budget, ISBLANK(tbl_Budget[Month]) || tbl_Budget[Month] = MONTH(MAX(DIM_Date[Date])))
)

Profit Budget (Period) =
CALCULATE(
    SUM(tbl_Budget[Budget Amount]),
    tbl_Budget[Category] = "Profit",
    tbl_Budget[Year] = YEAR(MAX(DIM_Date[Date])),
    FILTER(tbl_Budget, ISBLANK(tbl_Budget[Month]) || tbl_Budget[Month] = MONTH(MAX(DIM_Date[Date])))
)

Revenue Actual vs Budget = [Net Sales] - [Revenue Budget (Period)]
Expense Actual vs Budget = [Operating Expenses] - [Expense Budget (Period)]
// Marketing Actual vs Budget is intentionally absent: there is no Actual
// Marketing Spend measure yet (FACT_MarketingSpend is unbuilt — see the
// Marketing-Ready Layer). Marketing Budget (Period) above is ready the
// moment that fact table exists; don't approximate Actual from
// Operating Expenses' "Marketing" category alone without checking that
// category mapping matches what "Marketing Budget" is meant to cover.
Purchasing Actual vs Budget = [Cash Paid for Purchases] - [Purchasing Budget (Period)]
Profit Actual vs Budget = [Net Profit] - [Profit Budget (Period)]

Revenue Forecast vs Budget = [Net Sales Rolling 12 Months] - ([Revenue Budget (Period)] * 12)
// A simple annualized comparison: the trailing-12-month run rate against a
// full year of the current monthly budget. For a true forecast-vs-budget
// (using BI_Forecast's actual projection rather than a trailing-12
// run-rate), pull BI_Forecast!E<row> for Sales directly into a report cell
// instead — that table's FORECAST.LINEAR value IS the forward-looking
// number; this DAX measure is the backward-looking run-rate version,
// useful as a sanity check on the two agreeing roughly.
```

---

## Documentation note

Every measure above follows `MEASURES.md`'s existing rule: composite
measures reference base ones by name (`[Sales Variance]` uses `[Net Sales]`
and `[Sales Target]` rather than re-deriving either), so a target or budget
change on 15_Settings/08_Finance propagates everywhere automatically.
