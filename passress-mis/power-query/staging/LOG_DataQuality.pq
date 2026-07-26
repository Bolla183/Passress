// LOG_DataQuality
// -----------------------------------------------------------------------------
// Appends one row per staging query per refresh with a basic automatic
// completeness check: did this query return any rows at all? References each
// RAW_ query by name so it refreshes after them (see LOG_RefreshHistory.pq for
// why that ordering trick works). This is intentionally a minimal Phase 2
// check — it proves the ingestion layer is alive, not that the data is
// correct. Richer, rule-driven checks (against 14_Data_Quality's
// tbl_ValidationRules table) are a Phase 3+ enhancement once there's a
// Data Model to validate against.
// Output columns: CheckID, Timestamp, CheckName, TableName, Status, Details
// -----------------------------------------------------------------------------
let
    Sources = [
        RAW_Products = RAW_Products,
        RAW_Variants = RAW_Variants,
        RAW_Orders = RAW_Orders,
        RAW_OrderLines = RAW_OrderLines,
        RAW_Transactions = RAW_Transactions,
        RAW_Refunds = RAW_Refunds,
        RAW_Customers = RAW_Customers,
        RAW_Collections = RAW_Collections,
        RAW_InventoryLevels = RAW_InventoryLevels,
        RAW_Discounts = RAW_Discounts
    ],

    Timestamp = DateTime.LocalNow(),

    CheckRows = List.Transform(
        Record.FieldNames(Sources),
        (tableName) =>
            let
                rowCount = Table.RowCount(Record.Field(Sources, tableName))
            in
                [
                    CheckID = Text.NewGuid(),
                    Timestamp = Timestamp,
                    CheckName = "RowCountCheck",
                    TableName = tableName,
                    Status = if rowCount = 0 then "WARNING - No rows returned" else "OK",
                    Details = Text.From(rowCount) & " row(s) loaded this refresh"
                ]
    ),

    NewRows = Table.FromRecords(CheckRows,
        {"CheckID", "Timestamp", "CheckName", "TableName", "Status", "Details"}),

    Previous = try Excel.CurrentWorkbook(){[Name="LOG_DataQuality"]}[Content] otherwise null,
    PreviousRows = if Previous = null then #table({"CheckID","Timestamp","CheckName","TableName","Status","Details"}, {}) else Previous,
    Result = if Table.IsEmpty(PreviousRows) then NewRows else Table.Combine({PreviousRows, NewRows})
in
    Result
