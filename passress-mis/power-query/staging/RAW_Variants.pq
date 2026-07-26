// RAW_Variants
// -----------------------------------------------------------------------------
// Shopify resource: Product Variants (root query field `productVariants`)
// Incremental: yes, via updated_at (sortKey: UPDATED_AT, query filter)
// Output columns: VariantID, ProductID, SKU, Title, Price, CompareAtPrice,
//                  InventoryItemID, UnitCost, CreatedAt, UpdatedAt
// Note: `price` / `compareAtPrice` are the Shopify `Money` scalar (a decimal
// string in shop currency) — used directly, no `.amount` subfield needed.
// `unitCost` lives on the linked InventoryItem as MoneyV2, hence `.amount`.
// -----------------------------------------------------------------------------
let
    GraphQLQuery = "
        query Variants($first: Int!, $after: String, $query: String) {
          productVariants(first: $first, after: $after, query: $query, sortKey: UPDATED_AT) {
            pageInfo { hasNextPage endCursor }
            edges {
              node {
                id
                sku
                title
                price
                compareAtPrice
                createdAt
                updatedAt
                product { id }
                inventoryItem { id unitCost { amount } }
              }
            }
          }
        }
    ",

    IncrementalFilter = fn_IncrementalWindow("RAW_Variants"),
    BaseVariables = [first = 250, #"query" = IncrementalFilter],

    Nodes = fn_ShopifyPagedConnection(GraphQLQuery, BaseVariables, {"productVariants"}),

    ToTable = Table.FromRecords(
        Nodes,
        {"id", "sku", "title", "price", "compareAtPrice", "createdAt", "updatedAt", "product", "inventoryItem"},
        MissingField.UseNull
    ),

    AddProductId = Table.AddColumn(ToTable, "ProductID", each [product][id], type text),
    AddInventoryItemId = Table.AddColumn(AddProductId, "InventoryItemID", each [inventoryItem][id], type text),
    AddUnitCost = Table.AddColumn(AddInventoryItemId, "UnitCost",
        each try [inventoryItem][unitCost][amount] otherwise null, type number),

    Renamed = Table.RenameColumns(AddUnitCost, {
        {"id", "VariantID"}, {"sku", "SKU"}, {"title", "Title"},
        {"price", "Price"}, {"compareAtPrice", "CompareAtPrice"},
        {"createdAt", "CreatedAt"}, {"updatedAt", "UpdatedAt"}
    }),

    Reordered = Table.SelectColumns(Renamed,
        {"VariantID", "ProductID", "SKU", "Title", "Price", "CompareAtPrice",
         "InventoryItemID", "UnitCost", "CreatedAt", "UpdatedAt"}),

    Typed = Table.TransformColumnTypes(Reordered, {
        {"VariantID", type text}, {"ProductID", type text}, {"SKU", type text}, {"Title", type text},
        {"Price", type number}, {"CompareAtPrice", type number}, {"InventoryItemID", type text},
        {"UnitCost", type number}, {"CreatedAt", type datetime}, {"UpdatedAt", type datetime}
    })
in
    Typed
