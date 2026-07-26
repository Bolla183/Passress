// fn_IncrementalWindow
// -----------------------------------------------------------------------------
// Computes the effective `updated_at` lower bound for a resource's incremental
// refresh, already formatted as a Shopify search-syntax fragment ready to pass
// as the GraphQL `query` argument.
//
// Logic:
//   - First-ever run (the RAW_ table is empty or doesn't exist yet): use
//     Param_HistoricalBackfillStartDate — a full backfill from that date.
//   - Every subsequent refresh: use (now - Param_LookbackDays), a rolling
//     re-check window. This re-pulls a slightly overlapping slice of recent
//     history on every refresh, which is deliberately simpler and more robust
//     than a stored high-watermark cell (no risk of a failed refresh leaving
//     the watermark stuck, no write-back required from a read-only query
//     language). The tradeoff: a record updated and then reverted within the
//     lookback window is re-fetched needlessly — harmless, just a few extra
//     API rows.
//
// Input:  tableName (text) - the RAW_ table name to check for existing rows
// Output: text, e.g. "updated_at:>='2026-07-19T00:00:00Z'"
// -----------------------------------------------------------------------------
let
    fn_IncrementalWindow = (tableName as text) as text =>
    let
        existing = try Excel.CurrentWorkbook(){[Name=tableName]}[Content] otherwise null,
        isFirstRun = existing = null or Table.IsEmpty(existing),

        startDateTime =
            if isFirstRun then
                DateTime.From(Param_HistoricalBackfillStartDate)
            else
                DateTime.From(DateTimeZone.UtcNow()) - #duration(Param_LookbackDays, 0, 0, 0),

        isoText = DateTime.ToText(startDateTime, "yyyy-MM-ddTHH:mm:ssZ")
    in
        "updated_at:>='" & isoText & "'"
in
    fn_IncrementalWindow
