# PASSRESS MIS — Phase 6 DAX Addendum: Growth & Health Score Inputs

Additive to `MEASURES.md` and `PHASE5_MEASURES_ADDENDUM.md` — neither file
changed. Three small, genuinely new measures, added because the Business
Health Score (`BI_HealthScore`) needs a "Customer Growth" and a
"Return Rate" signal that didn't exist yet, and both are useful reused
elsewhere too, not just inside the score.

```dax
Customers Active (Current Period) Same Period Last Year =
CALCULATE([Customers Active (Current Period)], SAMEPERIODLASTYEAR(DIM_Date[Date]))

Customer Growth % (YoY) =
DIVIDE(
    [Customers Active (Current Period)] - [Customers Active (Current Period) Same Period Last Year],
    [Customers Active (Current Period) Same Period Last Year]
)
// Same SAMEPERIODLASTYEAR pattern as [Revenue Growth % (YoY)] in MEASURES.md
// §8 — reused deliberately, not reinvented, so both "growth" measures behave
// identically under the hood.

Return Rate % =
DIVIDE([Returns], [Gross Sales])
// Returns as a share of gross sales — a plain, reusable ratio that MEASURES.md
// never named directly (P&L just lists Returns as its own line). Referenced
// by the Business Health Score; useful on its own for a Sales/Profitability
// view too.
```

## Business Health Score — worksheet formulas, not a DAX measure

The composite 0-100 score itself is built on `BI_HealthScore` as Excel
formulas (`CUBEVALUE` calls combined with plain arithmetic), not as one
big DAX measure. Two reasons: (1) two of its ten inputs — Data Quality %
and Alerts — are computed from worksheet tables (`14_Data_Quality`,
`BI_Alerts`) that aren't part of the Data Model, so a pure-DAX measure
couldn't reach them without adding tables to the model purely to feed a
scoring formula; (2) this matches the exact pattern `BI_Insights`/
`BI_Alerts`/`BI_Forecast` already established in Phase 5 — "system-
generated dashboard content" lives as CUBEVALUE-driven worksheet formulas,
not DAX. See `PHASE6_DOCUMENTATION.md` §3 for the full 10-component
formula set and the weighting table (`tbl_HealthScoreWeights`, 15_Settings).
