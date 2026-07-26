// RAW_Collections
// -----------------------------------------------------------------------------
// Shopify resource: Collections (root query field `collections`)
// Incremental: NO — full reload every refresh. Collection count is typically
// low (tens, not thousands) for a single-brand fashion store, so a full
// reload every refresh is cheap and avoids depending on an unverified
// updated_at/sortKey filter on this connection.
// Output columns: CollectionID, Title, Handle
// -----------------------------------------------------------------------------
let
    GraphQLQuery = "
        query Collections($first: Int!, $after: String) {
          collections(first: $first, after: $after) {
            pageInfo { hasNextPage endCursor }
            edges {
              node {
                id
                title
                handle
              }
            }
          }
        }
    ",

    BaseVariables = [first = 250],

    Nodes = fn_ShopifyPagedConnection(GraphQLQuery, BaseVariables, {"collections"}),

    ToTable = Table.FromRecords(Nodes, {"id", "title", "handle"}, MissingField.UseNull),

    Renamed = Table.RenameColumns(ToTable, {
        {"id", "CollectionID"}, {"title", "Title"}, {"handle", "Handle"}
    }),

    Typed = Table.TransformColumnTypes(Renamed, {
        {"CollectionID", type text}, {"Title", type text}, {"Handle", type text}
    })
in
    Typed
