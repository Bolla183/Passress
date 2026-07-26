// DIM_Collection
// -----------------------------------------------------------------------------
// Built from RAW_Collections (Phase 2) — no new Shopify API calls. Adds a
// surrogate CollectionKey matching what DIM_Product's Collection column
// and FACT_ManualExpenses' RelatedCollection column hold (Collection Title),
// so relationships in the Data Model join on Title.
// Output columns: CollectionKey, CollectionID, Title, Handle
// -----------------------------------------------------------------------------
let
    Source = RAW_Collections,
    AddKey = Table.AddColumn(Source, "CollectionKey", each [Title], type text),
    Reordered = Table.SelectColumns(AddKey, {"CollectionKey", "CollectionID", "Title", "Handle"}),
    RemoveBlank = Table.SelectRows(Reordered, each [Title] <> null and [Title] <> ""),
    Distinct = Table.Distinct(RemoveBlank, {"Title"})
in
    Distinct
