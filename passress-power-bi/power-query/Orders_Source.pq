// Orders_Source
// -----------------------------------------------------------------------------
// SHARED, CONNECTION-ONLY query — after creating it, right-click in the
// Queries pane > Properties > uncheck "Enable load" (Power BI won't load a
// query with no load-destination chosen by default the way Excel does, but
// confirm it explicitly). FACT_OrderLines and FACT_Returns both reference
// this single query and each pull out the piece they need — one paginated
// API fetch per refresh covers both tables, not two separate fetches.
//
// Filter: only orders updated on/after Param_HistoricalStartDate. Simpler
// than the Excel project's rolling lookback-window — see that parameter
// file's own note on why.
//
// KNOWN LIMITATION: lineItems capped at first:100 per order (no nested
// pagination) — very unlikely to bind for a single-brand fashion retailer,
// flagged rather than silently ignored.
//
// UNVERIFIED — CHECK BEFORE FIRST REAL REFRESH: `sourceName` is used below
// for the "Channel" field ("web", "pos", etc.) — this is a real, long-
// standing field on Shopify's Order object, but field availability can
// shift between API versions. If Channel comes back blank after your first
// refresh, open Shopify's GraphQL Admin API reference for the Order type
// (in-app: Settings > Apps > your custom app > API docs link, or ask
// whoever set up the custom app) and confirm the exact field name for the
// API version in Param_ShopifyAPIVersion.
// -----------------------------------------------------------------------------
let
    GraphQLQuery = "
        query Orders($first: Int!, $after: String, $query: String) {
          orders(first: $first, after: $after, query: $query, sortKey: UPDATED_AT) {
            pageInfo { hasNextPage endCursor }
            edges {
              node {
                id
                name
                createdAt
                sourceName
                shippingAddress { countryCodeV2 }
                customer { id }
                lineItems(first: 100) {
                  edges {
                    node {
                      id
                      sku
                      title
                      quantity
                      product { id }
                      originalUnitPriceSet { shopMoney { amount } }
                      totalDiscountSet { shopMoney { amount } }
                    }
                  }
                }
                refunds(first: 20) {
                  id
                  createdAt
                  refundLineItems(first: 50) {
                    edges {
                      node {
                        id
                        quantity
                        lineItem { id product { id } }
                        subtotalSet { shopMoney { amount } }
                      }
                    }
                  }
                }
              }
            }
          }
        }
    ",

    IsoStart = Date.ToText(Param_HistoricalStartDate, "yyyy-MM-dd"),
    BaseVariables = [first = 100, #"query" = "updated_at:>='" & IsoStart & "'"],

    OrderNodes = fn_ShopifyPagedConnection(GraphQLQuery, BaseVariables, {"orders"})
in
    OrderNodes
