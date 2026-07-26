// FACT_CapitalTransactions
// -----------------------------------------------------------------------------
// Data Model-ready mirror of 11_Capital's Capital Transactions table (Phase 3).
// Adds a DateKey (derived from Date), consistent with every other fact.
// Output columns: CapitalKey, DateKey, Date, Owner, TransactionType, Amount
// -----------------------------------------------------------------------------
let
    Source = Excel.CurrentWorkbook(){[Name="tbl_CapitalTransactions"]}[Content],
    Typed = Table.TransformColumnTypes(Source, {
        {"Capital ID", type text}, {"Date", type date}, {"Amount", type number}
    }),
    AddDateKey = Table.AddColumn(Typed, "DateKey", each Date.ToText([Date], "yyyyMMdd"), type text),
    Renamed = Table.RenameColumns(AddDateKey, {
        {"Capital ID", "CapitalKey"}, {"Transaction Type", "TransactionType"}
    }),
    Reordered = Table.SelectColumns(Renamed, {"CapitalKey", "DateKey", "Date", "Owner", "TransactionType", "Amount"}),
    RemoveBlank = Table.SelectRows(Reordered, each [CapitalKey] <> null and [CapitalKey] <> "")
in
    RemoveBlank
