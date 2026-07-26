// RAW_Orders
// -----------------------------------------------------------------------------
// Grain: one row per order. Reads the shared Orders_Source (see that file for
// the GraphQL query, incremental logic, and known limitations) and selects
// only the order-level fields.
// Output columns: OrderID, OrderNumber, CreatedAt, UpdatedAt, FinancialStatus,
//                  FulfillmentStatus, Currency, TotalPrice, SubtotalPrice,
//                  TotalDiscounts, TotalTax, CustomerID, LocationID
// LocationID note: sourced from Order.retailLocation, which is populated only
// for POS/retail orders. It will be blank for ordinary online orders — that's
// expected, not a data error.
// -----------------------------------------------------------------------------
let
    Nodes = Orders_Source,

    ToTable = Table.FromRecords(
        Nodes,
        {"id", "name", "createdAt", "updatedAt", "displayFinancialStatus", "displayFulfillmentStatus",
         "currencyCode", "totalPriceSet", "subtotalPriceSet", "totalDiscountsSet", "totalTaxSet",
         "customer", "retailLocation"},
        MissingField.UseNull
    ),

    AddAmounts = Table.AddColumn(ToTable, "TotalPrice", each Number.From([totalPriceSet][shopMoney][amount]), type number),
    AddAmounts2 = Table.AddColumn(AddAmounts, "SubtotalPrice", each Number.From([subtotalPriceSet][shopMoney][amount]), type number),
    AddAmounts3 = Table.AddColumn(AddAmounts2, "TotalDiscounts", each Number.From([totalDiscountsSet][shopMoney][amount]), type number),
    AddAmounts4 = Table.AddColumn(AddAmounts3, "TotalTax", each Number.From([totalTaxSet][shopMoney][amount]), type number),
    AddCustomerId = Table.AddColumn(AddAmounts4, "CustomerID", each try [customer][id] otherwise null, type text),
    AddLocationId = Table.AddColumn(AddCustomerId, "LocationID", each try [retailLocation][id] otherwise null, type text),

    Renamed = Table.RenameColumns(AddLocationId, {
        {"id", "OrderID"}, {"name", "OrderNumber"}, {"createdAt", "CreatedAt"}, {"updatedAt", "UpdatedAt"},
        {"displayFinancialStatus", "FinancialStatus"}, {"displayFulfillmentStatus", "FulfillmentStatus"},
        {"currencyCode", "Currency"}
    }),

    Reordered = Table.SelectColumns(Renamed,
        {"OrderID", "OrderNumber", "CreatedAt", "UpdatedAt", "FinancialStatus", "FulfillmentStatus",
         "Currency", "TotalPrice", "SubtotalPrice", "TotalDiscounts", "TotalTax", "CustomerID", "LocationID"}),

    Typed = Table.TransformColumnTypes(Reordered, {
        {"OrderID", type text}, {"OrderNumber", type text}, {"CreatedAt", type datetime}, {"UpdatedAt", type datetime},
        {"FinancialStatus", type text}, {"FulfillmentStatus", type text}, {"Currency", type text},
        {"TotalPrice", type number}, {"SubtotalPrice", type number}, {"TotalDiscounts", type number},
        {"TotalTax", type number}, {"CustomerID", type text}, {"LocationID", type text}
    })
in
    Typed
