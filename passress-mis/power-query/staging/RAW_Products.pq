// RAW_Products
// -----------------------------------------------------------------------------
// Shopify resource: Products (root query field `products`)
// Incremental: yes, via updated_at (sortKey: UPDATED_AT, query filter)
// Output columns: ProductID, Title, ProductType, Vendor, CollectionIDs,
//                  CreatedAt, UpdatedAt, Status
// Field-by-field source mapping is documented in ../DOCUMENTATION.md
// -----------------------------------------------------------------------------
let
    GraphQLQuery = "
        query Products($first: Int!, $after: String, $query: String) {
          products(first: $first, after: $after, query: $query, sortKey: UPDATED_AT) {
            pageInfo { hasNextPage endCursor }
            edges {
              node {
                id
                title
                productType
                vendor
                status
                createdAt
                updatedAt
                collections(first: 20) { edges { node { id } } }
              }
            }
          }
        }
    ",

    IncrementalFilter = fn_IncrementalWindow("RAW_Products"),
    BaseVariables = [first = 250, #"query" = IncrementalFilter],

    Nodes = fn_ShopifyPagedConnection(GraphQLQuery, BaseVariables, {"products"}),

    ToTable = Table.FromRecords(
        Nodes,
        {"id", "title", "productType", "vendor", "status", "createdAt", "updatedAt", "collections"},
        MissingField.UseNull
    ),

    AddCollectionIds = Table.AddColumn(
        ToTable, "CollectionIDs",
        each Text.Combine(List.Transform([collections][edges], each _[node][id]), "; "),
        type text
    ),

    Renamed = Table.RenameColumns(AddCollectionIds, {
        {"id", "ProductID"}, {"title", "Title"}, {"productType", "ProductType"},
        {"vendor", "Vendor"}, {"status", "Status"}, {"createdAt", "CreatedAt"}, {"updatedAt", "UpdatedAt"}
    }),

    Reordered = Table.SelectColumns(Renamed,
        {"ProductID", "Title", "ProductType", "Vendor", "CollectionIDs", "CreatedAt", "UpdatedAt", "Status"}),

    Typed = Table.TransformColumnTypes(Reordered, {
        {"ProductID", type text}, {"Title", type text}, {"ProductType", type text},
        {"Vendor", type text}, {"CollectionIDs", type text},
        {"CreatedAt", type datetime}, {"UpdatedAt", type datetime}, {"Status", type text}
    })
in
    Typed
