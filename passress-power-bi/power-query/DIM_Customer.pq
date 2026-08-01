// DIM_Customer
// -----------------------------------------------------------------------------
// Grain: one row per customer.
//
// NOTE — FirstOrderDate is NOT pulled here: Shopify's Customer object
// doesn't expose it as a direct field. When the Customers page is built
// (later phase, needs New vs. Returning), it'll be computed from
// FACT_OrderLines (MIN order date per customer) instead — flagged here so
// it isn't forgotten, not built now since the Sales page doesn't need it.
// DATA_MODEL.md's DIM_Customer table listing reflects this — no
// FirstOrderDate column ships in this phase.
// -----------------------------------------------------------------------------
let
    GraphQLQuery = "
        query Customers($first: Int!, $after: String) {
          customers(first: $first, after: $after) {
            pageInfo { hasNextPage endCursor }
            edges {
              node {
                id
                displayName
                email
                defaultAddress { countryCodeV2 }
              }
            }
          }
        }
    ",

    BaseVariables = [first = 100],
    Nodes = fn_ShopifyPagedConnection(GraphQLQuery, BaseVariables, {"customers"}),

    ToTable = Table.FromRecords(Nodes, {"id", "displayName", "email", "defaultAddress"}, MissingField.UseNull),

    AddCountry = Table.AddColumn(ToTable, "Country", each try [defaultAddress][countryCodeV2] otherwise null, type text),
    AddCustomerKey = Table.AddColumn(AddCountry, "CustomerKey", each [id], type text),

    Renamed = Table.RenameColumns(AddCustomerKey, {{"id", "CustomerID"}, {"displayName", "Name"}, {"email", "Email"}}),

    Reordered = Table.SelectColumns(Renamed, {"CustomerKey", "CustomerID", "Name", "Email", "Country"}),

    Typed = Table.TransformColumnTypes(Reordered, {
        {"CustomerKey", type text}, {"CustomerID", type text}, {"Name", type text},
        {"Email", type text}, {"Country", type text}
    })
in
    Typed
