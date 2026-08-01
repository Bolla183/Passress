// DIM_Product
// -----------------------------------------------------------------------------
// Grain: one row per product (not per variant — Sales/Executive/Products
// pages all report at product level; if a future page genuinely needs
// variant-level detail, e.g. size/color breakdowns, that's a new column on
// this same table, not a new table).
//
// "Collection" pulls only the FIRST collection returned per product — see
// DATA_MODEL.md's note on why this is a deliberate simplification, not an
// oversight.
//
// UNVERIFIED — CHECK BEFORE FIRST REAL REFRESH: `unitCost` requires "View
// product costs" permission on the token's owning staff account. If this
// column comes back entirely blank, that permission is the first thing to
// check, not a query bug.
// -----------------------------------------------------------------------------
let
    GraphQLQuery = "
        query Products($first: Int!, $after: String) {
          products(first: $first, after: $after) {
            pageInfo { hasNextPage endCursor }
            edges {
              node {
                id
                title
                productType
                vendor
                status
                collections(first: 1) { edges { node { title } } }
                variants(first: 1) {
                  edges {
                    node {
                      sku
                      inventoryItem { unitCost { amount } }
                    }
                  }
                }
              }
            }
          }
        }
    ",

    BaseVariables = [first = 100],
    Nodes = fn_ShopifyPagedConnection(GraphQLQuery, BaseVariables, {"products"}),

    ToTable = Table.FromRecords(Nodes, {"id", "title", "productType", "vendor", "status", "collections", "variants"}, MissingField.UseNull),

    AddCollection = Table.AddColumn(ToTable, "Collection", each
        if List.Count([collections][edges]) > 0 then [collections][edges]{0}[node][title] else "Uncategorized", type text),

    AddSKU = Table.AddColumn(AddCollection, "SKU", each
        if List.Count([variants][edges]) > 0 then [variants][edges]{0}[node][sku] else null, type text),

    AddUnitCost = Table.AddColumn(AddSKU, "UnitCost", each
        try Number.From([variants][edges]{0}[node][inventoryItem][unitCost][amount]) otherwise null, type number),

    Renamed = Table.RenameColumns(AddUnitCost, {
        {"id", "ProductID"}, {"title", "Title"}, {"productType", "Category"}
    }),

    // ProductKey mirrors ProductID (same GID) — kept as a separate column
    // name so every fact table's join column is named consistently
    // "ProductKey" rather than mixing ProductID/ProductKey across tables.
    AddProductKey = Table.AddColumn(Renamed, "ProductKey", each [ProductID], type text),

    Reordered = Table.SelectColumns(AddProductKey,
        {"ProductKey", "ProductID", "SKU", "Title", "Category", "Collection", "Vendor", "UnitCost", "Status"}),

    Typed = Table.TransformColumnTypes(Reordered, {
        {"ProductKey", type text}, {"ProductID", type text}, {"SKU", type text}, {"Title", type text},
        {"Category", type text}, {"Collection", type text}, {"Vendor", type text},
        {"UnitCost", type number}, {"Status", type text}
    })
in
    Typed
