// FACT_PurchaseOrderLines
// -----------------------------------------------------------------------------
// Data Model-ready mirror of 12_Suppliers' Purchase Order Lines table
// (Phase 3). No date column of its own — PO Lines has no date field in the
// source sheet; time-based PO Lines analysis relates through
// FACT_PurchaseOrderHeader's OrderDate via PONumber (see dax/README.md's
// relationship list). Straight read + retype, no new logic.
// Output columns: PONumber, SKU, QuantityOrdered, UnitCost, TotalCost
// -----------------------------------------------------------------------------
let
    Source = Excel.CurrentWorkbook(){[Name="tbl_POLines"]}[Content],
    Typed = Table.TransformColumnTypes(Source, {
        {"PO Number", type text}, {"SKU", type text},
        {"Quantity Ordered", Int64.Type}, {"Unit Cost", type number}, {"Total Cost", type number}
    }),
    Renamed = Table.RenameColumns(Typed, {
        {"PO Number", "PONumber"}, {"Quantity Ordered", "QuantityOrdered"}, {"Unit Cost", "UnitCost"}, {"Total Cost", "TotalCost"}
    }),
    RemoveBlank = Table.SelectRows(Renamed, each [PONumber] <> null and [PONumber] <> "" and [SKU] <> null and [SKU] <> "")
in
    RemoveBlank
