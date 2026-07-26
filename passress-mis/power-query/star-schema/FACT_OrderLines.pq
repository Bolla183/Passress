// FACT_OrderLines
// -----------------------------------------------------------------------------
// Built from RAW_OrderLines + RAW_Orders (both Phase 2 — no new API calls).
// Grain: one row per order line item (same grain as RAW_OrderLines).
//
// COGS is resolved HERE, at refresh time, via fn_GetEffectiveCost(SKU, order
// date) — the historically-correct cost as of when the order happened, per
// Phase 3's design. This is intentionally a Power Query column, not a DAX
// measure: DAX has no clean way to express "the cost row whose date range
// contains this order's date" without an expensive per-row iterator, while
// Power Query resolves it once per refresh and DAX then just SUMs a plain
// number — correct and fast.
//
// A line whose SKU has no matching cost row (new product not yet costed,
// or a data-entry gap) gets UnitCost = 0 and is flagged in MissingCostFlag
// — check that column after every refresh; a nonzero count means gross
// margin is understated for those lines until Product Cost Master is
// updated.
// Output columns: OrderLineKey, OrderID, DateKey, ProductKey, CustomerKey,
//                  LocationKey, Quantity, UnitPrice, GrossAmount,
//                  DiscountAmount, TaxAmount, NetAmount, UnitCost, COGS,
//                  MissingCostFlag
// -----------------------------------------------------------------------------
let
    OrderHeaders = Table.SelectColumns(RAW_Orders, {"OrderID", "CreatedAt", "CustomerID", "LocationID"}),

    Joined = Table.NestedJoin(RAW_OrderLines, {"OrderID"}, OrderHeaders, {"OrderID"}, "OrderInfo", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(Joined, "OrderInfo", {"CreatedAt", "CustomerID", "LocationID"}, {"OrderCreatedAt", "CustomerID", "LocationID"}),

    AddOrderDate = Table.AddColumn(Expanded, "OrderDate", each Date.From([OrderCreatedAt]), type date),
    AddDateKey = Table.AddColumn(AddOrderDate, "DateKey", each Date.ToText([OrderDate], "yyyyMMdd"), type text),

    AddGross = Table.AddColumn(AddDateKey, "GrossAmount", each [Quantity] * [UnitPrice], type number),
    AddNet = Table.AddColumn(AddGross, "NetAmount", each [GrossAmount] - [DiscountAllocated], type number),

    // Resolved once per row into a temp column, then reused, rather than
    // calling fn_GetEffectiveCost twice (it does a table scan per call).
    AddResolvedCost = Table.AddColumn(AddNet, "_ResolvedCost", each fn_GetEffectiveCost([SKU], [OrderDate]), type nullable number),
    AddUnitCost = Table.AddColumn(AddResolvedCost, "UnitCost", each if [_ResolvedCost] = null then 0 else [_ResolvedCost], type number),
    AddMissingCostFlag = Table.AddColumn(AddUnitCost, "MissingCostFlag", each [_ResolvedCost] = null, type logical),
    AddCOGS = Table.AddColumn(AddMissingCostFlag, "COGS", each [Quantity] * [UnitCost], type number),

    Renamed = Table.RenameColumns(AddCOGS, {
        {"LineItemID", "OrderLineKey"}, {"SKU", "ProductKey"}, {"CustomerID", "CustomerKey"},
        {"LocationID", "LocationKey"}, {"DiscountAllocated", "DiscountAmount"}, {"TaxAllocated", "TaxAmount"}
    }),

    Reordered = Table.SelectColumns(Renamed,
        {"OrderLineKey", "OrderID", "DateKey", "ProductKey", "CustomerKey", "LocationKey", "Quantity",
         "UnitPrice", "GrossAmount", "DiscountAmount", "TaxAmount", "NetAmount", "UnitCost", "COGS", "MissingCostFlag"})
in
    Reordered
