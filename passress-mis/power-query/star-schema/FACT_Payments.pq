// FACT_Payments
// -----------------------------------------------------------------------------
// Built from RAW_Transactions (Phase 2) — no new API calls. Grain: one row
// per order transaction (capture/refund/void/authorization).
// PresentmentAmount: RAW_Transactions only ever fetched the shop-currency
// amount (shopMoney), not presentment — for a single-currency EGP store this
// is a non-issue, so PresentmentAmount is set equal to Amount here. If this
// store ever sells in multiple presentment currencies, RAW_Transactions'
// GraphQL query needs a presentmentMoney field added before this column
// means anything different from Amount.
// DateKey uses ProcessedAt, falling back to CreatedAt.
// Output columns: PaymentKey, OrderID, DateKey, PaymentMethod, Currency,
//                  Amount, PresentmentAmount
// -----------------------------------------------------------------------------
let
    Source = RAW_Transactions,
    AddPaymentDate = Table.AddColumn(Source, "PaymentDate", each
        Date.From(if [ProcessedAt] <> null then [ProcessedAt] else [CreatedAt]), type date),
    AddDateKey = Table.AddColumn(AddPaymentDate, "DateKey", each Date.ToText([PaymentDate], "yyyyMMdd"), type text),
    AddPresentment = Table.AddColumn(AddDateKey, "PresentmentAmount", each [AmountShop], type number),

    Renamed = Table.RenameColumns(AddPresentment, {
        {"TransactionID", "PaymentKey"}, {"Gateway", "PaymentMethod"},
        {"AmountShop", "Amount"}, {"CurrencyShop", "Currency"}
    }),
    Reordered = Table.SelectColumns(Renamed,
        {"PaymentKey", "OrderID", "DateKey", "PaymentMethod", "Currency", "Amount", "PresentmentAmount"})
in
    Reordered
