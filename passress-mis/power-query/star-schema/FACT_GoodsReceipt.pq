// FACT_GoodsReceipt
// -----------------------------------------------------------------------------
// Data Model-ready mirror of 12_Suppliers' Goods Receipt table (Phase 3).
// Adds a DateKey (derived from Goods Received Date), consistent with every
// other fact. This is the table Phase 4's Inventory/COGS-by-received-qty
// measures should read from — see dax/README.md's note on received vs.
// ordered quantities.
// Output columns: PONumber, DateKey, SKU, GoodsReceivedDate,
//                  QuantityReceived, RemainingQuantity, ActualUnitCost,
//                  VarianceFromPO, Warehouse
// -----------------------------------------------------------------------------
let
    Source = Excel.CurrentWorkbook(){[Name="tbl_GoodsReceipt"]}[Content],
    Typed = Table.TransformColumnTypes(Source, {
        {"PO Number", type text}, {"SKU", type text}, {"Goods Received Date", type date},
        {"Quantity Received", Int64.Type}, {"Remaining Quantity", Int64.Type},
        {"Actual Unit Cost", type number}, {"Variance from PO", type number}
    }),
    AddDateKey = Table.AddColumn(Typed, "DateKey", each Date.ToText([Goods Received Date], "yyyyMMdd"), type text),
    Renamed = Table.RenameColumns(AddDateKey, {
        {"PO Number", "PONumber"}, {"Goods Received Date", "GoodsReceivedDate"},
        {"Quantity Received", "QuantityReceived"}, {"Remaining Quantity", "RemainingQuantity"},
        {"Actual Unit Cost", "ActualUnitCost"}, {"Variance from PO", "VarianceFromPO"}
    }),
    Reordered = Table.SelectColumns(Renamed,
        {"PONumber", "DateKey", "SKU", "GoodsReceivedDate", "QuantityReceived", "RemainingQuantity",
         "ActualUnitCost", "VarianceFromPO", "Warehouse"}),
    RemoveBlank = Table.SelectRows(Reordered, each [PONumber] <> null and [PONumber] <> "" and [SKU] <> null and [SKU] <> "")
in
    RemoveBlank
