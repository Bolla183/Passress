// FACT_OrderLines
// -----------------------------------------------------------------------------
// Grain: one row per order line item. Reads Orders_Source (shared with
// FACT_Returns) and flattens each order's nested lineItems into its own row
// — no separate "RAW_" staging query in between; Power BI's Data Model
// doesn't need the intermediate worksheet-landing step the Excel project
// required (see DATA_MODEL.md's closing note on why).
//
// Close & Load To: this query only — Data Model (no separate worksheet view
// needed the way Excel's Table-based loading worked). In Power BI Desktop
// this is just "Close & Apply"; there's no "load to sheet vs. load to model"
// choice to make, every loaded query goes into the Data Model.
// -----------------------------------------------------------------------------
let
    Orders = Orders_Source,

    // One row per order, still carrying its lineItems list, before expanding.
    ToTable = Table.FromRecords(
        Orders,
        {"id", "name", "createdAt", "sourceName", "shippingAddress", "customer", "lineItems"},
        MissingField.UseNull
    ),

    AddDateKey = Table.AddColumn(ToTable, "DateKey", each Number.From(Date.ToText(DateTime.Date(DateTime.FromText([createdAt])), "yyyyMMdd")), Int64.Type),
    AddCustomerKey = Table.AddColumn(AddDateKey, "CustomerKey", each try [customer][id] otherwise null, type text),
    AddCountry = Table.AddColumn(AddCustomerKey, "ShippingCountry", each try [shippingAddress][countryCodeV2] otherwise null, type text),
    AddChannel = Table.AddColumn(AddCountry, "Channel", each if [sourceName] = null then "Unknown" else [sourceName], type text),

    // Expand lineItems: each order becomes N rows, one per line item.
    AddLineNodes = Table.AddColumn(AddChannel, "LineNodes", each List.Transform([lineItems][edges], each _[node])),
    ExpandedLines = Table.ExpandListColumn(AddLineNodes, "LineNodes"),

    AddSKU = Table.AddColumn(ExpandedLines, "SKU", each [LineNodes][sku], type text),
    AddProductKey = Table.AddColumn(AddSKU, "ProductKey", each try [LineNodes][product][id] otherwise null, type text),
    AddQuantity = Table.AddColumn(AddProductKey, "Quantity", each [LineNodes][quantity], Int64.Type),
    AddUnitPrice = Table.AddColumn(AddQuantity, "UnitPrice", each Number.From([LineNodes][originalUnitPriceSet][shopMoney][amount]), type number),
    AddLineDiscount = Table.AddColumn(AddUnitPrice, "LineDiscount", each Number.From([LineNodes][totalDiscountSet][shopMoney][amount]), type number),
    AddNetAmount = Table.AddColumn(AddLineDiscount, "NetAmount", each ([UnitPrice] * [Quantity]) - [LineDiscount], type number),

    Renamed = Table.RenameColumns(AddNetAmount, {{"id", "OrderID"}, {"name", "OrderNumber"}}),

    Reordered = Table.SelectColumns(Renamed,
        {"DateKey", "OrderID", "OrderNumber", "ProductKey", "CustomerKey", "SKU",
         "Quantity", "UnitPrice", "LineDiscount", "NetAmount", "Channel", "ShippingCountry"}),

    Typed = Table.TransformColumnTypes(Reordered, {
        {"DateKey", Int64.Type}, {"OrderID", type text}, {"OrderNumber", type text},
        {"ProductKey", type text}, {"CustomerKey", type text}, {"SKU", type text},
        {"Quantity", Int64.Type}, {"UnitPrice", type number}, {"LineDiscount", type number},
        {"NetAmount", type number}, {"Channel", type text}, {"ShippingCountry", type text}
    })
in
    Typed
