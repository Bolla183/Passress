// DIM_Supplier
// -----------------------------------------------------------------------------
// Data Model-ready mirror of 12_Suppliers' Supplier Master table (Phase 3).
// Output columns: SupplierKey, SupplierID, SupplierName, SupplierType, Currency, Status
// -----------------------------------------------------------------------------
let
    Source = Excel.CurrentWorkbook(){[Name="tbl_SupplierMaster"]}[Content],
    Typed = Table.TransformColumnTypes(Source, {
        {"Supplier ID", type text}, {"Supplier Name", type text}, {"Supplier Type", type text},
        {"Currency", type text}, {"Status", type text}
    }),
    Renamed = Table.RenameColumns(Typed, {
        {"Supplier ID", "SupplierID"}, {"Supplier Name", "SupplierName"}, {"Supplier Type", "SupplierType"}
    }),
    AddSupplierKey = Table.AddColumn(Renamed, "SupplierKey", each [SupplierID], type text),
    Reordered = Table.SelectColumns(AddSupplierKey,
        {"SupplierKey", "SupplierID", "SupplierName", "SupplierType", "Currency", "Status"}),
    RemoveBlank = Table.SelectRows(Reordered, each [SupplierID] <> null and [SupplierID] <> "")
in
    RemoveBlank
