// DIM_Location
// -----------------------------------------------------------------------------
// SCOPE NOTE: Shopify's `locations` query (which returns location names,
// cities, countries) was never fetched in Phase 2 — it wasn't in the
// original 10-resource list, and this business's orders are almost all
// online (Order.retailLocation is documented as blank for online orders in
// power-query/DOCUMENTATION.md). Adding a full RAW_Locations resource for
// what would mostly be one warehouse felt like scope creep for this phase.
// So this dimension is built structurally correct but data-thin: LocationID
// values come from RAW_InventoryLevels (the only place Phase 2 captured
// them), and LocationName just repeats the ID until a future phase adds a
// real `locations` query. Inventory/location DAX measures work either way
// (they group by LocationKey); only the *display name* is a placeholder.
// Output columns: LocationKey, LocationID, LocationName, City, Country
// -----------------------------------------------------------------------------
let
    Distinct = Table.Distinct(Table.SelectColumns(RAW_InventoryLevels, {"LocationID"})),
    RemoveBlank = Table.SelectRows(Distinct, each [LocationID] <> null and [LocationID] <> ""),
    AddKey = Table.AddColumn(RemoveBlank, "LocationKey", each [LocationID], type text),
    AddName = Table.AddColumn(AddKey, "LocationName", each [LocationID], type text),
    AddCity = Table.AddColumn(AddName, "City", each null, type text),
    AddCountry = Table.AddColumn(AddCity, "Country", each null, type text),
    Reordered = Table.SelectColumns(AddCountry, {"LocationKey", "LocationID", "LocationName", "City", "Country"})
in
    Reordered
