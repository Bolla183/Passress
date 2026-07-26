// FACT_Refunds
// -----------------------------------------------------------------------------
// Built from RAW_Refunds (Phase 2) — no new API calls. Grain: one row per
// refunded line item, same as RAW_Refunds.
// RefundAmount = SubtotalAmount + TaxAmount (total cash returned to the
// customer for this line, per Shopify's own decomposition) — matches
// RAW_Refunds.DOCUMENTATION's field mapping.
// DateKey uses RefundProcessedAt, falling back to RefundCreatedAt if the
// processed date is blank (can happen for refunds still in flight).
// Output columns: RefundKey, OrderLineKey, DateKey, Quantity, RefundAmount
// -----------------------------------------------------------------------------
let
    Source = RAW_Refunds,
    AddRefundDate = Table.AddColumn(Source, "RefundDate", each
        Date.From(if [RefundProcessedAt] <> null then [RefundProcessedAt] else [RefundCreatedAt]), type date),
    AddDateKey = Table.AddColumn(AddRefundDate, "DateKey", each Date.ToText([RefundDate], "yyyyMMdd"), type text),
    AddAmount = Table.AddColumn(AddDateKey, "RefundAmount", each [SubtotalAmount] + [TaxAmount], type number),

    Renamed = Table.RenameColumns(AddAmount, {
        {"RefundLineItemID", "RefundKey"}, {"LineItemID", "OrderLineKey"}
    }),
    Reordered = Table.SelectColumns(Renamed, {"RefundKey", "OrderLineKey", "DateKey", "Quantity", "RefundAmount"})
in
    Reordered
