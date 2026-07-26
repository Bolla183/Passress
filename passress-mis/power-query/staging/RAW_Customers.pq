// RAW_Customers
// -----------------------------------------------------------------------------
// Shopify resource: Customers (root query field `customers`)
// Incremental: yes, via updated_at (sortKey: UPDATED_AT, query filter)
// Output columns: CustomerID, FirstName, LastName, Email, CreatedAt, UpdatedAt,
//                  OrdersCount, TotalSpent, DefaultAddressCountry
// Note: Customer.email was deprecated/removed from the schema — email now
// comes from defaultEmailAddress.emailAddress. Confirmed against the live
// Admin GraphQL schema before writing this query, not assumed from memory.
// -----------------------------------------------------------------------------
let
    GraphQLQuery = "
        query Customers($first: Int!, $after: String, $query: String) {
          customers(first: $first, after: $after, query: $query, sortKey: UPDATED_AT) {
            pageInfo { hasNextPage endCursor }
            edges {
              node {
                id
                firstName
                lastName
                defaultEmailAddress { emailAddress }
                createdAt
                updatedAt
                numberOfOrders
                amountSpent { amount }
                defaultAddress { country }
              }
            }
          }
        }
    ",

    IncrementalFilter = fn_IncrementalWindow("RAW_Customers"),
    BaseVariables = [first = 250, #"query" = IncrementalFilter],

    Nodes = fn_ShopifyPagedConnection(GraphQLQuery, BaseVariables, {"customers"}),

    ToTable = Table.FromRecords(
        Nodes,
        {"id", "firstName", "lastName", "defaultEmailAddress", "createdAt", "updatedAt",
         "numberOfOrders", "amountSpent", "defaultAddress"},
        MissingField.UseNull
    ),

    AddEmail = Table.AddColumn(ToTable, "Email", each try [defaultEmailAddress][emailAddress] otherwise null, type text),
    AddSpent = Table.AddColumn(AddEmail, "TotalSpent", each Number.From([amountSpent][amount]), type number),
    AddCountry = Table.AddColumn(AddSpent, "DefaultAddressCountry", each try [defaultAddress][country] otherwise null, type text),

    Renamed = Table.RenameColumns(AddCountry, {
        {"id", "CustomerID"}, {"firstName", "FirstName"}, {"lastName", "LastName"},
        {"createdAt", "CreatedAt"}, {"updatedAt", "UpdatedAt"}, {"numberOfOrders", "OrdersCount"}
    }),

    Reordered = Table.SelectColumns(Renamed,
        {"CustomerID", "FirstName", "LastName", "Email", "CreatedAt", "UpdatedAt",
         "OrdersCount", "TotalSpent", "DefaultAddressCountry"}),

    Typed = Table.TransformColumnTypes(Reordered, {
        {"CustomerID", type text}, {"FirstName", type text}, {"LastName", type text}, {"Email", type text},
        {"CreatedAt", type datetime}, {"UpdatedAt", type datetime}, {"OrdersCount", Int64.Type},
        {"TotalSpent", type number}, {"DefaultAddressCountry", type text}
    })
in
    Typed
