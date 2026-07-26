// RAW_Refunds
// -----------------------------------------------------------------------------
// Grain: one row per refunded line item (RefundLineItem) — NOT one row per
// refund event. A single refund can cover several line items; each becomes
// its own row here, all sharing the same RefundID.
// Reads the shared Orders_Source and expands each order's `refunds` array
// (plain list, capped at first:20/order) and each refund's
// `refundLineItems` connection (capped at first:50/refund).
// Output columns: RefundLineItemID, RefundID, OrderID, LineItemID, Quantity,
//                  SubtotalAmount, TaxAmount, RefundCreatedAt,
//                  RefundProcessedAt, Note
// Note: Shopify's schema has no per-line refund "reason" field at this grain
// (that was a Phase-1 placeholder assumption, corrected here); `Note` is the
// refund-level note instead, repeated across that refund's line rows.
// -----------------------------------------------------------------------------
let
    OrderNodes = Orders_Source,

    Expanded = Table.FromRecords(
        List.Combine(
            List.Transform(
                OrderNodes,
                (order) =>
                    List.Combine(
                        List.Transform(
                            order[refunds],
                            (refund) =>
                                List.Transform(
                                    refund[refundLineItems][edges],
                                    (edge) =>
                                        let node = edge[node] in
                                        [
                                            RefundLineItemID = node[id],
                                            RefundID = refund[id],
                                            OrderID = order[id],
                                            LineItemID = node[lineItem][id],
                                            Quantity = node[quantity],
                                            SubtotalAmount = Number.From(node[subtotalSet][shopMoney][amount]),
                                            TaxAmount = Number.From(node[totalTaxSet][shopMoney][amount]),
                                            RefundCreatedAt = refund[createdAt],
                                            RefundProcessedAt = refund[processedAt],
                                            Note = refund[note]
                                        ]
                                )
                        )
                    )
            )
        ),
        {"RefundLineItemID", "RefundID", "OrderID", "LineItemID", "Quantity",
         "SubtotalAmount", "TaxAmount", "RefundCreatedAt", "RefundProcessedAt", "Note"}
    ),

    Typed = Table.TransformColumnTypes(Expanded, {
        {"RefundLineItemID", type text}, {"RefundID", type text}, {"OrderID", type text}, {"LineItemID", type text},
        {"Quantity", Int64.Type}, {"SubtotalAmount", type number}, {"TaxAmount", type number},
        {"RefundCreatedAt", type datetime}, {"RefundProcessedAt", type datetime}, {"Note", type text}
    })
in
    Typed
