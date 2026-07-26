// DIM_Customer
// -----------------------------------------------------------------------------
// Built from RAW_Customers (Phase 2) — no new Shopify API calls.
// Grain: one row per customer. CustomerSegment is left blank here — it's a
// natural DAX-measure candidate (RFM/cohort-based) rather than an ETL
// column, since segmentation logic tends to change as the business defines
// it; see dax/MEASURES.md's Customer Metrics section for cohort handling
// done in DAX instead.
// CohortMonth (added for Phase 4's cohort-analysis measures) is FirstOrderDate
// truncated to the 1st of its month — a static dimension attribute, not a
// DAX measure, since "which cohort a customer belongs to" doesn't change
// with filter context the way a measure would.
// Output columns: CustomerKey, CustomerID, Name, Email, Country,
//                  FirstOrderDate, CohortMonth, CustomerSegment
// -----------------------------------------------------------------------------
let
    Source = RAW_Customers,

    AddName = Table.AddColumn(Source, "Name",
        each Text.Trim(Text.Combine({[FirstName], [LastName]}, " ")), type text),

    // FirstOrderDate: derived from Orders_Source (the shared nested fetch) so
    // this doesn't require yet another API call — a customer's first order
    // date is just the minimum CreatedAt among their orders.
    OrdersByCustomer = Table.Group(
        Table.SelectRows(RAW_Orders, each [CustomerID] <> null),
        {"CustomerID"},
        {{"FirstOrderDate", each List.Min([CreatedAt]), type datetime}}
    ),
    WithFirstOrder = Table.NestedJoin(AddName, {"CustomerID"}, OrdersByCustomer, {"CustomerID"}, "OrderInfo", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(WithFirstOrder, "OrderInfo", {"FirstOrderDate"}, {"FirstOrderDate"}),

    AddCohortMonth = Table.AddColumn(Expanded, "CohortMonth", each
        if [FirstOrderDate] = null then null else #date(Date.Year(Date.From([FirstOrderDate])), Date.Month(Date.From([FirstOrderDate])), 1),
        type date),
    AddSegment = Table.AddColumn(AddCohortMonth, "CustomerSegment", each null, type text),
    AddCustomerKey = Table.AddColumn(AddSegment, "CustomerKey", each [CustomerID], type text),

    Reordered = Table.SelectColumns(AddCustomerKey,
        {"CustomerKey", "CustomerID", "Name", "Email", "DefaultAddressCountry", "FirstOrderDate", "CohortMonth", "CustomerSegment"}),
    Renamed = Table.RenameColumns(Reordered, {{"DefaultAddressCountry", "Country"}})
in
    Renamed
