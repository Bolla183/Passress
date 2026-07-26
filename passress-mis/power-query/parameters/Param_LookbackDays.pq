// Param_LookbackDays
// Reads "Lookback Days (Incremental Refresh)" on 15_Settings (named range
// SetLookbackDaysIncrementalRefresh). Used by fn_IncrementalWindow as the
// rolling re-check window on every refresh after the first.
// Type: number, e.g. 7.
let
    Source = Excel.CurrentWorkbook(){[Name="SetLookbackDaysIncrementalRefresh"]}[Content]{0}[Column1],
    AsNumber = Number.From(Source)
in
    AsNumber
