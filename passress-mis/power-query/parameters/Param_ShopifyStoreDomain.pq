// Param_ShopifyStoreDomain
// Reads the "Shopify Store Domain" value cell on 15_Settings (named range
// SetShopifyStoreDomain) so every query shares one place to configure it.
// Type: text, e.g. "passress.myshopify.com" (no https://, no trailing slash).
let
    Source = Excel.CurrentWorkbook(){[Name="SetShopifyStoreDomain"]}[Content]{0}[Column1]
in
    Source
