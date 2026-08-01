// Param_ShopifyStoreDomain
// -----------------------------------------------------------------------------
// Create as: Power Query Editor > Manage Parameters > New Parameter
//   Name: Param_ShopifyStoreDomain, Type: Text
//   Current Value: your-store.myshopify.com
// The single place the store domain lives — every query below reads this
// parameter rather than hardcoding the domain, so switching stores (or
// testing against a dev store) is a one-cell change, not a find-and-replace
// across every query.
// -----------------------------------------------------------------------------
"your-store.myshopify.com" meta [IsParameterQuery=true, Type="Text", IsParameterQueryRequired=true]
