// FACT_Returns
// -----------------------------------------------------------------------------
// Grain: one row per refunded line item. Reads the same Orders_Source as
// FACT_OrderLines (shared fetch, not a second API call) and flattens the
// nested refunds > refundLineItems structure.
// -----------------------------------------------------------------------------
let
    Orders = Orders_Source,

    ToTable = Table.FromRecords(Orders, {"id", "refunds"}, MissingField.UseNull),

    AddRefundNodes = Table.AddColumn(ToTable, "RefundNodes", each [refunds]),
    ExpandedRefunds = Table.ExpandListColumn(AddRefundNodes, "RefundNodes"),
    FilteredHasRefunds = Table.SelectRows(ExpandedRefunds, each [RefundNodes] <> null),

    AddRefundDate = Table.AddColumn(FilteredHasRefunds, "DateKey", each Number.From(Date.ToText(DateTime.Date(DateTime.FromText([RefundNodes][createdAt])), "yyyyMMdd")), Int64.Type),

    AddLineNodes = Table.AddColumn(AddRefundDate, "RefundLineNodes", each List.Transform([RefundNodes][refundLineItems][edges], each _[node])),
    ExpandedLines = Table.ExpandListColumn(AddLineNodes, "RefundLineNodes"),

    AddProductKey = Table.AddColumn(ExpandedLines, "ProductKey", each try [RefundLineNodes][lineItem][product][id] otherwise null, type text),
    AddQuantity = Table.AddColumn(AddProductKey, "Quantity", each [RefundLineNodes][quantity], Int64.Type),
    AddRefundAmount = Table.AddColumn(AddQuantity, "RefundAmount", each Number.From([RefundLineNodes][subtotalSet][shopMoney][amount]), type number),

    Renamed = Table.RenameColumns(AddRefundAmount, {{"id", "OrderID"}}),
    Reordered = Table.SelectColumns(Renamed, {"DateKey", "OrderID", "ProductKey", "Quantity", "RefundAmount"}),

    Typed = Table.TransformColumnTypes(Reordered, {
        {"DateKey", Int64.Type}, {"OrderID", type text}, {"ProductKey", type text},
        {"Quantity", Int64.Type}, {"RefundAmount", type number}
    })
in
    Typed
