// Param_HistoricalBackfillStartDate
// Reads "Historical Backfill Start Date" on 15_Settings (named range
// SetHistoricalBackfillStartDate). fn_IncrementalWindow uses this only when a
// RAW_ table is empty (first-ever load) to bound how far back the initial
// backfill reaches; ignored on every subsequent refresh.
// Type: date, e.g. 2024-01-01.
let
    Source = Excel.CurrentWorkbook(){[Name="SetHistoricalBackfillStartDate"]}[Content]{0}[Column1],
    AsDate = Date.From(Source)
in
    AsDate
