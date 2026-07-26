// RAW_Transactions
// -----------------------------------------------------------------------------
// Grain: one row per order transaction (payment capture, refund, void,
// authorization, sale). Reads the shared Orders_Source and expands each
// order's `transactions` array (a plain list on Order, not a connection —
// capped at first:20/order in Orders_Source.pq).
// Output columns: TransactionID, OrderID, Kind, Status, Gateway, AmountShop,
//                  CurrencyShop, CreatedAt, ProcessedAt, Test
// Note: there is no root-level `transactions` query in the Shopify Admin
// GraphQL schema — transactions only exist nested under Order, hence this
// derives from Orders_Source rather than its own top-level fetch.
// -----------------------------------------------------------------------------
let
    OrderNodes = Orders_Source,

    Expanded = Table.FromRecords(
        List.Combine(
            List.Transform(
                OrderNodes,
                (order) =>
                    List.Transform(
                        order[transactions],
                        (txn) =>
                            [
                                TransactionID = txn[id],
                                OrderID = order[id],
                                Kind = txn[kind],
                                Status = txn[status],
                                Gateway = txn[gateway],
                                AmountShop = Number.From(txn[amountSet][shopMoney][amount]),
                                CurrencyShop = order[currencyCode],
                                CreatedAt = txn[createdAt],
                                ProcessedAt = txn[processedAt],
                                Test = txn[test]
                            ]
                    )
            )
        ),
        {"TransactionID", "OrderID", "Kind", "Status", "Gateway", "AmountShop",
         "CurrencyShop", "CreatedAt", "ProcessedAt", "Test"}
    ),

    Typed = Table.TransformColumnTypes(Expanded, {
        {"TransactionID", type text}, {"OrderID", type text}, {"Kind", type text}, {"Status", type text},
        {"Gateway", type text}, {"AmountShop", type number}, {"CurrencyShop", type text},
        {"CreatedAt", type datetime}, {"ProcessedAt", type datetime}, {"Test", type logical}
    })
in
    Typed
