// DIM_ProductCostHistory
// -----------------------------------------------------------------------------
// Data Model-ready mirror of 05_Products' Product Cost Master table (Phase 3).
// Straight read + rename + retype — Total Landed Cost and Expected Gross
// Margin % are read as their COMPUTED values (Power Query reads
// Excel.CurrentWorkbook() cell values, not formula text, so the worksheet
// formulas from Phase 3 are already resolved here).
//
// This table is intentionally NOT related to FACT_OrderLines via a Data
// Model relationship — see fn_GetEffectiveCost.pq for why (date-range joins
// aren't expressible as a Power Pivot relationship). FACT_OrderLines already
// carries its own resolved UnitCost/COGS per line, computed via that
// function at refresh time. This table exists in the Data Model for
// reference/browsing (e.g. "what does the current cost sheet look like")
// and Product Cost Master-specific DAX measures (see dax/MEASURES.md), not
// for joining to orders.
// Output columns: CostKey, SKU, Collection, TotalLandedCost, SellingPrice,
//                  ExpectedGrossMarginPct, EffectiveFromDate, EffectiveToDate, ActiveFlag
// -----------------------------------------------------------------------------
let
    Source = Excel.CurrentWorkbook(){[Name="tbl_ProductCostMaster"]}[Content],
    Typed = Table.TransformColumnTypes(Source, {
        {"Cost ID", type text}, {"SKU", type text}, {"Collection", type text},
        {"Total Landed Cost", type number}, {"Selling Price", type number},
        {"Expected Gross Margin %", type number},
        {"Effective From Date", type date}, {"Effective To Date", type date},
        {"Active Flag", type text}
    }),
    Renamed = Table.RenameColumns(Typed, {
        {"Cost ID", "CostKey"}, {"Total Landed Cost", "TotalLandedCost"},
        {"Selling Price", "SellingPrice"}, {"Expected Gross Margin %", "ExpectedGrossMarginPct"},
        {"Effective From Date", "EffectiveFromDate"}, {"Effective To Date", "EffectiveToDate"},
        {"Active Flag", "ActiveFlag"}
    }),
    Reordered = Table.SelectColumns(Renamed,
        {"CostKey", "SKU", "Collection", "TotalLandedCost", "SellingPrice",
         "ExpectedGrossMarginPct", "EffectiveFromDate", "EffectiveToDate", "ActiveFlag"}),
    RemoveBlankSku = Table.SelectRows(Reordered, each [SKU] <> null and [SKU] <> "")
in
    RemoveBlankSku
