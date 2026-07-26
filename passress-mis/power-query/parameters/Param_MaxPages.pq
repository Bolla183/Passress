// Param_MaxPages
// Reads "Max Pages Per Refresh (Safety Cap)" on 15_Settings (named range
// SetMaxPagesPerRefreshSafetyCap). fn_ShopifyPagedConnection stops after this
// many pages even if the API still reports hasNextPage = true, guaranteeing
// every refresh terminates.
// Type: number, e.g. 500.
let
    Source = Excel.CurrentWorkbook(){[Name="SetMaxPagesPerRefreshSafetyCap"]}[Content]{0}[Column1],
    AsNumber = Number.From(Source)
in
    AsNumber
