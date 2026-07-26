// RAW_OrderLines
// -----------------------------------------------------------------------------
// Grain: one row per order line item. Reads the shared Orders_Source and
// expands each order's nested lineItems.edges (capped at 50/order — see
// Orders_Source.pq for that limitation).
// Output columns: LineItemID, OrderID, ProductID, VariantID, SKU, Title,
//                  Quantity, UnitPrice, DiscountAllocated, TaxAllocated
// TaxAllocated = sum of the line's taxLines[].priceSet.shopMoney.amount
// (a line can have more than one tax line, e.g. multiple jurisdictions).
// -----------------------------------------------------------------------------
let
    OrderNodes = Orders_Source,

    Expanded = Table.FromRecords(
        List.Combine(
            List.Transform(
                OrderNodes,
                (order) =>
                    List.Transform(
                        order[lineItems][edges],
                        (edge) =>
                            let node = edge[node] in
                            [
                                LineItemID = node[id],
                                OrderID = order[id],
                                ProductID = try node[product][id] otherwise null,
                                VariantID = try node[variant][id] otherwise null,
                                SKU = node[sku],
                                Title = node[title],
                                Quantity = node[quantity],
                                UnitPrice = Number.From(node[originalUnitPriceSet][shopMoney][amount]),
                                DiscountAllocated = Number.From(node[totalDiscountSet][shopMoney][amount]),
                                TaxAllocated = List.Sum(List.Transform(node[taxLines], each Number.From(_[priceSet][shopMoney][amount])))
                            ]
                    )
            )
        ),
        {"LineItemID", "OrderID", "ProductID", "VariantID", "SKU", "Title",
         "Quantity", "UnitPrice", "DiscountAllocated", "TaxAllocated"}
    ),

    Typed = Table.TransformColumnTypes(Expanded, {
        {"LineItemID", type text}, {"OrderID", type text}, {"ProductID", type text}, {"VariantID", type text},
        {"SKU", type text}, {"Title", type text}, {"Quantity", Int64.Type}, {"UnitPrice", type number},
        {"DiscountAllocated", type number}, {"TaxAllocated", type number}
    })
in
    Typed
