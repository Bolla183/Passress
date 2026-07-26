// FACT_ManualExpenses
// -----------------------------------------------------------------------------
// Data Model-ready mirror of 10_Expenses' Manual Expense Entry table (Phase 3).
// Resolves Supplier (name) to SupplierID via a lookup against Supplier
// Master, so this fact relates to DIM_Supplier the same way every other
// supplier-aware fact does. Adds a DateKey (derived from Expense Date) not
// present in the Phase 3 sheet design, so this fact relates to DIM_Date the
// same way as the Shopify-sourced facts — kept ExpenseDate too, for display.
// Output columns: ExpenseKey, DateKey, ExpenseDate, ExpenseCategory,
//                  ExpenseSubcategory, SupplierID, Amount, Currency,
//                  PaymentMethod, RelatedCollection, RelatedSKU, CostCenter, InvoiceNumber
// -----------------------------------------------------------------------------
let
    Source = Excel.CurrentWorkbook(){[Name="tbl_ManualExpenses"]}[Content],
    Typed = Table.TransformColumnTypes(Source, {
        {"Expense ID", type text}, {"Expense Date", type date}, {"Amount", type number}
    }),

    Suppliers = Table.SelectColumns(Excel.CurrentWorkbook(){[Name="tbl_SupplierMaster"]}[Content], {"Supplier ID", "Supplier Name"}),
    WithSupplier = Table.NestedJoin(Typed, {"Supplier"}, Suppliers, {"Supplier Name"}, "SupplierInfo", JoinKind.LeftOuter),
    Expanded = Table.ExpandTableColumn(WithSupplier, "SupplierInfo", {"Supplier ID"}, {"SupplierID"}),

    AddDateKey = Table.AddColumn(Expanded, "DateKey", each Date.ToText([Expense Date], "yyyyMMdd"), type text),

    Renamed = Table.RenameColumns(AddDateKey, {
        {"Expense ID", "ExpenseKey"}, {"Expense Date", "ExpenseDate"}, {"Expense Category", "ExpenseCategory"},
        {"Expense Subcategory", "ExpenseSubcategory"}, {"Payment Method", "PaymentMethod"},
        {"Related Collection", "RelatedCollection"}, {"Related SKU", "RelatedSKU"}, {"Cost Center", "CostCenter"},
        {"Invoice Number", "InvoiceNumber"}
    }),
    Reordered = Table.SelectColumns(Renamed,
        {"ExpenseKey", "DateKey", "ExpenseDate", "ExpenseCategory", "ExpenseSubcategory", "SupplierID",
         "Amount", "Currency", "PaymentMethod", "RelatedCollection", "RelatedSKU", "CostCenter", "InvoiceNumber"}),
    RemoveBlank = Table.SelectRows(Reordered, each [ExpenseKey] <> null and [ExpenseKey] <> "")
in
    RemoveBlank
