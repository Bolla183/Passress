// LOG_RefreshHistory
// -----------------------------------------------------------------------------
// Appends one row per Refresh All, summarizing every staging query's row
// count. Referencing each RAW_ query by name (below) is what makes this work:
// Excel computes query dependencies automatically, so this query always
// refreshes AFTER all of them in the same Refresh All pass — there is no
// other way to get "post-refresh" ordering out of Power Query in Excel.
// See fn_AppendLog.pq for the append pattern and its documented limitations.
// Output columns: RefreshID, Timestamp, Source, RowsLoaded, RowsUpdated,
//                  Errors, DurationSeconds, TriggeredBy
// This first version reports RowsLoaded per refresh; RowsUpdated/Errors/
// DurationSeconds are populated as 0/blank placeholders here because Power
// Query has no built-in "previous row count" or wall-clock-duration API
// without additional bookkeeping — a reasonable Phase 3 enhancement (e.g.
// comparing against the prior LOG_RefreshHistory row's RowsLoaded).
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

    RowCounts = Record.ToTable(Record.TransformFields(Sources, List.Transform(Record.FieldNames(Sources), (name) => {name, each Table.RowCount(_)}))),
    TotalRows = List.Sum(RowCounts[Value]),
    SourceSummary = Text.Combine(List.Transform(Table.ToRecords(RowCounts), each [Name] & "=" & Text.From([Value])), ", "),

    NewRow = [
        RefreshID = Text.NewGuid(),
        Timestamp = DateTime.LocalNow(),
        Source = SourceSummary,
        RowsLoaded = TotalRows,
        RowsUpdated = 0,
        Errors = 0,
        DurationSeconds = 0,
        // M has no built-in "current OS user" function reachable from Excel's
        // sandboxed evaluation context, so this is a static placeholder rather
        // than a guessed API call. If per-user attribution matters later, the
        // simplest fix is a manual cell on 15_Settings the user fills in.
        TriggeredBy = "Excel Refresh"
    ],

    Result = fn_AppendLog("LOG_RefreshHistory", NewRow)
in
    Result
