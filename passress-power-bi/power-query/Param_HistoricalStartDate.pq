// Param_HistoricalStartDate
// -----------------------------------------------------------------------------
// Create as: Power Query Editor > Manage Parameters > New Parameter
//   Name: Param_HistoricalStartDate, Type: Date
//   Current Value: 2024-01-01 (adjust to whenever PASSRESS's Shopify history
//   should start being reported from)
//
// Deliberately simple: ONE fixed start date, no rolling "lookback window"
// logic. The Excel MIS project used a more complex incremental-refresh
// pattern (re-check the last N days on every refresh) because it was
// designed around Excel's own refresh model. This project assumes a normal
// daily Refresh (in Power BI Desktop, or scheduled in the Power BI Service)
// pulling everything from this date forward each time — simpler to
// understand and enough for this business's scale. If order volume ever
// grows large enough that a full pull becomes slow, the natural upgrade is
// Power BI Service's native Incremental Refresh feature (RangeStart/
// RangeEnd parameters) — not something to build by hand now.
// -----------------------------------------------------------------------------
#date(2024, 1, 1) meta [IsParameterQuery=true, Type="Date", IsParameterQueryRequired=true]
