// Param_ShopifyAPIVersion
// Reads the "Shopify API Version" value cell on 15_Settings (named range
// SetShopifyAPIVersion). Pinned deliberately rather than left on a rolling
// default — review and bump twice a year alongside Shopify's release notes.
// Type: text, e.g. "2025-01".
let
    Source = Excel.CurrentWorkbook(){[Name="SetShopifyAPIVersion"]}[Content]{0}[Column1]
in
    Source
