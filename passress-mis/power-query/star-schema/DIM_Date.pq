// DIM_Date
// -----------------------------------------------------------------------------
// Standalone generated calendar table — the official Date Table for the Data
// Model (mark it as such: Data Model window > Design > Mark as Date Table >
// column Date). Every time-intelligence measure in dax/MEASURES.md depends on
// this being marked correctly and on every fact table relating to it via a
// DateKey (never filtering fact tables by a raw Date/DateTime column).
//
// Range: 2023-01-01 through 2030-12-31 — covers the historical backfill
// window with headroom. Extend EndDate if the business is still running
// past 2030.
// Output columns: DateKey, Date, Year, FiscalYear, Quarter, FiscalQuarter,
//                  Month, MonthName, Week, Day, DayName, IsWeekend
// -----------------------------------------------------------------------------
let
    StartDate = #date(2023, 1, 1),
    EndDate = #date(2030, 12, 31),
    DayCount = Duration.Days(EndDate - StartDate) + 1,
    DateList = List.Dates(StartDate, DayCount, #duration(1, 0, 0, 0)),

    Base = Table.FromList(DateList, Splitter.SplitByNothing(), {"Date"}),
    Typed0 = Table.TransformColumnTypes(Base, {{"Date", type date}}),

    FYStartMonth = Param_FiscalYearStartMonth,

    AddDateKey = Table.AddColumn(Typed0, "DateKey", each Date.ToText([Date], "yyyyMMdd"), type text),
    AddYear = Table.AddColumn(AddDateKey, "Year", each Date.Year([Date]), Int64.Type),
    AddMonth = Table.AddColumn(AddYear, "Month", each Date.Month([Date]), Int64.Type),
    // Fiscal year is labeled by the calendar year it ENDS in (standard
    // convention): if the fiscal year starts in January, FiscalYear = Year.
    // Otherwise every month from FYStartMonth through December belongs to
    // the NEXT calendar year's fiscal label.
    AddFiscalYear = Table.AddColumn(AddMonth, "FiscalYear",
        each if FYStartMonth = 1 then [Year] else if [Month] >= FYStartMonth then [Year] + 1 else [Year],
        Int64.Type),
    AddQuarter = Table.AddColumn(AddFiscalYear, "Quarter", each Date.QuarterOfYear([Date]), Int64.Type),
    AddFYMonthOffset = Table.AddColumn(AddQuarter, "_FYMonthOffset", each Number.Mod([Month] - FYStartMonth, 12), Int64.Type),
    AddFiscalQuarter = Table.AddColumn(AddFYMonthOffset, "FiscalQuarter", each Number.IntegerDivide([_FYMonthOffset], 3) + 1, Int64.Type),
    AddMonthName = Table.AddColumn(AddFiscalQuarter, "MonthName", each Date.MonthName([Date]), type text),
    AddWeek = Table.AddColumn(AddMonthName, "Week", each Date.WeekOfYear([Date]), Int64.Type),
    AddDay = Table.AddColumn(AddWeek, "Day", each Date.Day([Date]), Int64.Type),
    AddDayName = Table.AddColumn(AddDay, "DayName", each Date.DayOfWeekName([Date]), type text),
    AddIsWeekend = Table.AddColumn(AddDayName, "IsWeekend",
        each Date.DayOfWeek([Date], Day.Monday) >= 5, type logical),

    Reordered = Table.SelectColumns(AddIsWeekend,
        {"DateKey", "Date", "Year", "FiscalYear", "Quarter", "FiscalQuarter", "Month", "MonthName", "Week", "Day", "DayName", "IsWeekend"})
in
    Reordered
