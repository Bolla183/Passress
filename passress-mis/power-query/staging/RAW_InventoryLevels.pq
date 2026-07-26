// RAW_InventoryLevels
// -----------------------------------------------------------------------------
// Shopify resource: Inventory Levels, reached via the root query field
// `inventoryItems` (there is no root-level `inventoryLevels` query — levels
// are only reachable nested under an inventory item or a location).
// Grain: one row per InventoryItem x Location.
// Incremental: yes, via updated_at query filter on `inventoryItems`. Note:
// `inventoryItems` has NO `sortKey` argument (confirmed against the live
// schema) — only `query` filtering, no explicit UPDATED_AT sort. That's fine
// for correctness (the filter still restricts which rows come back); it just
// means results aren't guaranteed to arrive in updated_at order.
// Output columns: InventoryItemID, SKU, LocationID, Available, UpdatedAt
// -----------------------------------------------------------------------------
let
    GraphQLQuery = "
        query InventoryLevels($first: Int!, $after: String, $query: String) {
          inventoryItems(first: $first, after: $after, query: $query) {
            pageInfo { hasNextPage endCursor }
            edges {
              node {
                id
                sku
                inventoryLevels(first: 10) {
                  edges {
                    node {
                      updatedAt
                      location { id }
                      quantities(names: [""available""]) { name quantity }
                    }
                  }
                }
              }
            }
          }
        }
    ",

    IncrementalFilter = fn_IncrementalWindow("RAW_InventoryLevels"),
    BaseVariables = [first = 250, #"query" = IncrementalFilter],

    ItemNodes = fn_ShopifyPagedConnection(GraphQLQuery, BaseVariables, {"inventoryItems"}),

    Expanded = Table.FromRecords(
        List.Combine(
            List.Transform(
                ItemNodes,
                (item) =>
                    List.Transform(
                        item[inventoryLevels][edges],
                        (edge) =>
                            let
                                node = edge[node],
                                availableQty = List.First(List.Select(node[quantities], each _[name] = "available"), [quantity = null])[quantity]
                            in
                                [
                                    InventoryItemID = item[id],
                                    SKU = item[sku],
                                    LocationID = node[location][id],
                                    Available = availableQty,
                                    UpdatedAt = node[updatedAt]
                                ]
                    )
            )
        ),
        {"InventoryItemID", "SKU", "LocationID", "Available", "UpdatedAt"}
    ),

    Typed = Table.TransformColumnTypes(Expanded, {
        {"InventoryItemID", type text}, {"SKU", type text}, {"LocationID", type text},
        {"Available", Int64.Type}, {"UpdatedAt", type datetime}
    })
in
    Typed
