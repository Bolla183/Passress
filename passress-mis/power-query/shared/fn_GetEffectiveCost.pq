// fn_GetEffectiveCost
// -----------------------------------------------------------------------------
// The historical-costing lookup Phase 3 was built for: given a SKU and a
// date, returns the Total Landed Cost from the Product Cost Master row whose
// Effective From/To range contains that date — NOT today's cost. This is
// deliberately done in Power Query (a table lookup with a range condition),
// not as a Data Model relationship, because Power Pivot relationships only
// support single-column equality joins and cannot express "date falls
// between these two columns."
//
// Matching rule: EffectiveFromDate <= asOfDate AND (EffectiveToDate is blank
// OR asOfDate <= EffectiveToDate). If more than one row matches (shouldn't
// happen if Product Cost Master's date ranges don't overlap — see its
// Overlap Warning column), the most recent EffectiveFromDate wins. If no row
// matches, returns null (the caller decides how to handle a missing cost —
// FACT_OrderLines treats it as 0 and flags it, see that file's comments).
//
// Inputs: sku (text), asOfDate (date)
// Output: number (Total Landed Cost) or null
// -----------------------------------------------------------------------------
let
    fn_GetEffectiveCost = (sku as text, asOfDate as date) as nullable number =>
    let
        source = try DIM_ProductCostHistory otherwise
            Excel.CurrentWorkbook(){[Name="tbl_ProductCostMaster"]}[Content],
        matches = Table.SelectRows(source, each
            Record.FieldOrDefault(_, "SKU", null) = sku
            and Date.From(Record.Field(_, "EffectiveFromDate")) <= asOfDate
            and (
                Record.FieldOrDefault(_, "EffectiveToDate", null) = null
                or Date.From(Record.Field(_, "EffectiveToDate")) >= asOfDate
            )
        ),
        sorted = Table.Sort(matches, {{"EffectiveFromDate", Order.Descending}}),
        result = if Table.IsEmpty(sorted) then null else
            Record.FieldOrDefault(sorted{0}, "TotalLandedCost", Record.FieldOrDefault(sorted{0}, "Total Landed Cost", null))
    in
        result
in
    fn_GetEffectiveCost
