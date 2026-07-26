// FACT_PurchaseOrderHeader
// -----------------------------------------------------------------------------
// Data Model-ready mirror of 12_Suppliers' Purchase Order Header table
// (Phase 3). Resolves Supplier (name) to SupplierID via Supplier Master.
// Adds a DateKey (derived from Order Date), consistent with every other fact.
// Output columns: PONumber, DateKey, SupplierID, OrderDate,
//                  ExpectedDeliveryDate, Status, Currency
// -----------------------------------------------------------------------------
let
    Source = Excel.CurrentWorkbook(){[Name="tbl_POHeader"]}[Content],
    Typed = Table.TransformColumnTypes(Source, {
        {"PO Number", type text}, {"Order Date", type date}, {"Expected Delivery Date", type date}
    }),

    Suppliers = Table.SelectColumns(Excel.CurrentWorkbook(){[Name="tbl_SupplierMaster"]}[Content], {"Supplier ID", "Supplier Name"}),
    WithSupplier = Table.NestedJoin(Typed, {"Supplier"}, Suppliers, {"Supplier Name"}, "SupplierInfo", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(WithSupplier, "SupplierInfo", {"Supplier ID"}, {"SupplierID"}),

    AddDateKey = Table.AddColumn(Expanded, "DateKey", each Date.ToText([Order Date], "yyyyMMdd"), type text),

    Renamed = Table.RenameColumns(AddDateKey, {
        {"PO Number", "PONumber"}, {"Order Date", "OrderDate"}, {"Expected Delivery Date", "ExpectedDeliveryDate"}
    }),
    Reordered = Table.SelectColumns(Renamed,
        {"PONumber", "DateKey", "SupplierID", "OrderDate", "ExpectedDeliveryDate", "Status", "Currency"}),
    RemoveBlank = Table.SelectRows(Reordered, each [PONumber] <> null and [PONumber] <> "")
in
    RemoveBlank
