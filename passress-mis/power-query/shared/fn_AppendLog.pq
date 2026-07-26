// fn_AppendLog
// -----------------------------------------------------------------------------
// Builds an updated LOG_RefreshHistory / LOG_DataQuality table by combining the
// table's CURRENT contents (read before this refresh overwrites them) with one
// new row for this refresh — Excel Power Query's stand-in for an "append-only
// log", since Excel (unlike Power BI dataflows) has no native incremental /
// append query output: every refresh fully replaces its target table.
//
// KNOWN LIMITATIONS (documented deliberately, not hidden):
//   - If a refresh errors before this query evaluates, that refresh's row is
//     never added — there is no partial write.
//   - Every refresh re-combines the FULL history, so load time grows slowly as
//     the log grows. If LOG_RefreshHistory exceeds a few thousand rows, copy
//     older rows out to a plain (non-Table) archive sheet by hand.
//   - This pattern depends on the table already existing with the right
//     columns; it does not create the table from nothing.
//
// Inputs:
//   tableName (text)   - the LOG_ table name to read/append
//   newRow    (record) - one record whose field names match the table's columns
// Output: table = previous rows + the new row
// -----------------------------------------------------------------------------
let
    fn_AppendLog = (tableName as text, newRow as record) as table =>
    let
        previous = try Excel.CurrentWorkbook(){[Name=tableName]}[Content] otherwise null,
        previousRows = if previous = null then #table(Record.FieldNames(newRow), {}) else previous,
        newRowTable = Table.FromRecords({newRow}),
        combined = if Table.IsEmpty(previousRows) then newRowTable else Table.Combine({previousRows, newRowTable})
    in
        combined
in
    fn_AppendLog
