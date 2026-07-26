// DIM_Product
// -----------------------------------------------------------------------------
// Built from RAW_Variants + RAW_Products (both from Phase 2 — no new Shopify
// API calls). Grain: one row per SKU, matching FACT_OrderLines' grain, so the
// relationship to FACT_OrderLines is a clean one-to-many on SKU = ProductKey.
//
// UnitCost here is a REFERENCE-ONLY convenience (the SKU's current Active
// cost from DIM_ProductCostHistory, if any) — it is NOT what COGS
// calculations should use. COGS must come from FACT_OrderLines' own
// pre-computed UnitCost/COGS columns, which resolve the historically-correct
// cost as of each order's date via fn_GetEffectiveCost. Using this column for
// COGS would silently apply TODAY's cost to historical orders — exactly what
// Phase 3's historical costing was built to prevent.
// PrimarySupplierID: there is no direct "this SKU's supplier" field anywhere
// in the workbook (a SKU could in principle be sourced from different
// suppliers over time) — so this is a best-effort derivation: the supplier
// on the MOST RECENT Goods Receipt for that SKU. A SKU never received
// (ordered but not yet delivered, or never purchased at all) gets a blank
// PrimarySupplierID. It exists specifically so "Profit per Supplier"
// (dax/MEASURES.md, Product Profitability) is a real relationship-driven
// breakdown rather than an unsupported metric — treat it as directional,
// not authoritative, and see that measure's notes.
// Output columns: ProductKey, ProductID, SKU, Title, ProductType, Vendor,
//                  Collection, UnitCost, Status, PrimarySupplierID
// -----------------------------------------------------------------------------
let
    // RAW_Variants already has its own UnitCost (Shopify InventoryItem.unitCost)
    // — dropped here deliberately, since DIM_Product's UnitCost must come from
    // this workbook's own Product Cost Master (the source of truth per Phase
    // 3), not Shopify's inventory accounting field. RAW_Variants' VariantID/SKU
    // stay untouched (already named correctly by Phase 2's RAW_Variants.pq).
    Variants = Table.RemoveColumns(RAW_Variants, {"UnitCost"}),
    Products = Table.SelectColumns(RAW_Products, {"ProductID", "Title", "ProductType", "Vendor", "CollectionIDs", "Status"}),

    Joined = Table.NestedJoin(Variants, {"ProductID"}, Products, {"ProductID"}, "ProductInfo", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(Joined, "ProductInfo",
        {"Title", "ProductType", "Vendor", "CollectionIDs", "Status"},
        {"ProductTitle", "ProductType", "Vendor", "CollectionIDs", "Status"}),

    CostLookup = try DIM_ProductCostHistory otherwise #table(
        {"SKU", "TotalLandedCost", "ActiveFlag"}, {}),
    ActiveCosts = Table.SelectColumns(
        Table.SelectRows(CostLookup, each Record.FieldOrDefault(_, "ActiveFlag", "") = "Active"),
        {"SKU", "TotalLandedCost"}
    ),
    ActiveCostsDistinct = Table.Distinct(ActiveCosts, {"SKU"}),  // safety net: one row per SKU even if Product Cost Master briefly has >1 Active row

    WithCurrentCost = Table.NestedJoin(Expanded, {"SKU"}, ActiveCostsDistinct, {"SKU"}, "CostInfo", JoinKind.LeftOuter),
    ExpandedCost = Table.ExpandTableColumn(WithCurrentCost, "CostInfo", {"TotalLandedCost"}, {"UnitCost"}),

    Renamed = Table.RenameColumns(ExpandedCost, {{"CollectionIDs", "Collection"}}),
    AddProductKey = Table.AddColumn(Renamed, "ProductKey", each [SKU], type text),

    // Most recent supplier per SKU, via the latest Goods Receipt. SKUs never
    // received (e.g. ordered but not yet delivered, or never purchased at
    // all) simply get a blank PrimarySupplierID — see header note.
    POHeaderSuppliers = try Table.SelectColumns(FACT_PurchaseOrderHeader, {"PONumber", "SupplierID"}) otherwise #table({"PONumber", "SupplierID"}, {}),
    ReceiptsBySku = try Table.Group(
        Table.Sort(FACT_GoodsReceipt, {{"GoodsReceivedDate", Order.Ascending}}),
        {"SKU"},
        {{"LatestPO", each List.Last([PONumber]), type text}}
    ) otherwise #table({"SKU", "LatestPO"}, {}),

    WithLatestPO = Table.NestedJoin(AddProductKey, {"SKU"}, ReceiptsBySku, {"SKU"}, "SupplierPOInfo", JoinKind.LeftOuter),
    ExpandedPO = Table.ExpandTableColumn(WithLatestPO, "SupplierPOInfo", {"LatestPO"}, {"LatestPO"}),
    WithSupplierID = Table.NestedJoin(ExpandedPO, {"LatestPO"}, POHeaderSuppliers, {"PONumber"}, "SupplierIdInfo", JoinKind.LeftOuter),
    ExpandedSupplierID = Table.ExpandTableColumn(WithSupplierID, "SupplierIdInfo", {"SupplierID"}, {"PrimarySupplierID"}),

    Reordered = Table.SelectColumns(ExpandedSupplierID,
        {"ProductKey", "ProductID", "SKU", "ProductTitle", "ProductType", "Vendor", "Collection", "UnitCost", "Status", "PrimarySupplierID"}),
    FinalRenamed = Table.RenameColumns(Reordered, {{"ProductTitle", "Title"}}),

    RemoveBlankSku = Table.SelectRows(FinalRenamed, each [SKU] <> null and [SKU] <> ""),
    Distinct = Table.Distinct(RemoveBlankSku, {"SKU"})
in
    Distinct
