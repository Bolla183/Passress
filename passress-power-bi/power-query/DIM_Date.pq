// DIM_Date
// -----------------------------------------------------------------------------
// Standalone generated calendar table — mark it as the Data Model's Date
// Table after loading (Model view > right-click DIM_Date > Mark as date
// table > column Date). Every time-intelligence DAX measure and the
// Daily/Weekly/Monthly/Quarterly/Yearly Field Parameter switcher (built
// alongside the Executive Dashboard, a later phase) depends on this.
//
// Range: 2023-01-01 through 2030-12-31 — adjust EndDate if PASSRESS is
// still trading past 2030.
// -----------------------------------------------------------------------------
let
    StartDate = #date(2023, 1, 1),
    EndDate = #date(2030, 12, 31),
    DayCount = Duration.Days(EndDate - StartDate) + 1,
    DateList = List.Dates(StartDate, DayCount, #duration(1, 0, 0, 0)),

    Base = Table.FromList(DateList, Splitter.SplitByNothing(), {"Date"}),
    Typed0 = Table.TransformColumnTypes(Base, {{"Date", type date}}),

    AddDateKey = Table.AddColumn(Typed0, "DateKey", each Number.From(Date.ToText([Date], "yyyyMMdd")), Int64.Type),
    AddYear = Table.AddColumn(AddDateKey, "Year", each Date.Year([Date]), Int64.Type),
    AddQuarter = Table.AddColumn(AddYear, "Quarter", each "Q" & Text.From(Date.QuarterOfYear([Date])), type text),
    AddMonthNumber = Table.AddColumn(AddQuarter, "MonthNumber", each Date.Month([Date]), Int64.Type),
    AddMonthName = Table.AddColumn(AddMonthNumber, "MonthName", each Date.ToText([Date], "MMM"), type text),
    AddWeek = Table.AddColumn(AddMonthName, "Week", each Date.WeekOfYear([Date]), Int64.Type),
    AddDay = Table.AddColumn(AddWeek, "Day", each Date.Day([Date]), Int64.Type),

    Reordered = Table.SelectColumns(AddDay,
        {"DateKey", "Date", "Year", "Quarter", "MonthNumber", "MonthName", "Week", "Day"})
in
    Reordered
