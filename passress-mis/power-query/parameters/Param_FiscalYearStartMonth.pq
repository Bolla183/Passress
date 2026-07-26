// Param_FiscalYearStartMonth
// Reads "Fiscal Year Start Month" on 15_Settings (named range
// SetFiscalYearStartMonth, e.g. "January") and converts it to a month
// number (1-12) for use in DIM_Date's FiscalYear/FiscalQuarter logic.
let
    Source = Excel.CurrentWorkbook(){[Name="SetFiscalYearStartMonth"]}[Content]{0}[Column1],
    MonthNames = {"January","February","March","April","May","June","July","August","September","October","November","December"},
    MonthNumber = List.PositionOf(MonthNames, Source) + 1,
    Result = if MonthNumber = 0 then 1 else MonthNumber  // default to January if the cell doesn't match a month name
in
    Result
