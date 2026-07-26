// FACT_InventoryMovements
// -----------------------------------------------------------------------------
// HONEST LIMITATION, read before relying on turnover/coverage trends: this is
// NOT a true movement/transaction log. Shopify's inventory-adjustment history
// (`inventoryAdjustmentGroups` and similar) was never fetched — RAW_InventoryLevels
// only ever gives a point-in-time "available now" snapshot. So this table is a
// PERIODIC SNAPSHOT FACT (a standard, well-understood data-warehousing
// pattern): every refresh appends one row per SKU x Location with that
// moment's on-hand quantity, building up a history of snapshots over time as
// the workbook gets refreshed repeatedly. MovementType is always "Snapshot"
// and QuantityChange is always blank — there is no per-transaction delta to
// report. Inventory Turnover / Days of Inventory / Stock Coverage measures
// (dax/MEASURES.md) are built on averages across these snapshots, which is
// the correct approach GIVEN this constraint, but is naturally coarser than
// a true daily movement ledger would give. A true movement log is a
// reasonable future-phase addition if this granularity isn't enough.
//
// Uses the same self-referential append pattern as LOG_RefreshHistory
// (Phase 2): reads this table's own current contents before they're
// overwritten, and unions today's snapshot on top.
// Output columns: MovementKey, DateKey, ProductKey, LocationKey,
//                  MovementType, QuantityChange, ResultingOnHand
// -----------------------------------------------------------------------------
let
    SnapshotDate = Date.From(DateTime.LocalNow()),
    SnapshotDateKey = Date.ToText(SnapshotDate, "yyyyMMdd"),

    Today = Table.FromRecords(
        List.Transform(Table.ToRecords(RAW_InventoryLevels), each [
            MovementKey = Text.Combine({_[SKU], _[LocationID], SnapshotDateKey}, "|"),
            DateKey = SnapshotDateKey,
            ProductKey = _[SKU],
            LocationKey = _[LocationID],
            MovementType = "Snapshot",
            QuantityChange = null,
            ResultingOnHand = _[Available]
        ]),
        {"MovementKey", "DateKey", "ProductKey", "LocationKey", "MovementType", "QuantityChange", "ResultingOnHand"}
    ),

    Previous = try Excel.CurrentWorkbook(){[Name="tbl_FACT_InventoryMovements"]}[Content] otherwise null,
    PreviousRows = if Previous = null then #table(
        {"MovementKey", "DateKey", "ProductKey", "LocationKey", "MovementType", "QuantityChange", "ResultingOnHand"}, {}
    ) else Previous,

    // De-duplicate: if this query runs more than once on the same day (e.g.
    // an on-demand refresh after the scheduled one), replace today's rows
    // rather than doubling them.
    PreviousMinusToday = Table.SelectRows(PreviousRows, each [DateKey] <> SnapshotDateKey),
    Combined = if Table.IsEmpty(PreviousMinusToday) then Today else Table.Combine({PreviousMinusToday, Today})
in
    Combined
