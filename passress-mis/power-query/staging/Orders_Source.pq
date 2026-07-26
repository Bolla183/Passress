// Orders_Source
// -----------------------------------------------------------------------------
// SHARED, CONNECTION-ONLY query — do not load this to a worksheet or the Data
// Model. RAW_Orders, RAW_OrderLines, RAW_Transactions, and RAW_Refunds all
// reference this single query and each expand the piece of it they need. This
// keeps the design to ONE paginated API fetch per refresh for all four
// resources, instead of four separate fetches — GraphQL's nested-fetch
// strength used deliberately to minimize API calls and rate-limit cost.
//
// Incremental: yes, via Order.updated_at (sortKey: UPDATED_AT, query filter).
// Because lineItems/transactions/refunds are nested under Order, they inherit
// the SAME incremental window as their parent order — an order that hasn't
// been updated recently is skipped entirely, along with everything nested
// under it.
//
// KNOWN LIMITATION: lineItems is capped at `first: 50` per order (no nested
// pagination). Orders with more than 50 distinct line items will have the
// remainder silently truncated. For a retail/fashion catalog this is very
// unlikely to bind, but if it ever does, raise the cap or add nested
// pagination inside GetConnection's node handling as a Phase 3+ enhancement.
//
// KNOWN LIMITATION (per Shopify): by default the Order object only exposes
// the last 60 days of orders. Reaching further back for the historical
// backfill requires the `read_all_orders` scope in addition to `read_orders`
// on the custom app's access token — request that scope if the backfill
// needs history older than 60 days.
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
                updatedAt
                displayFinancialStatus
                displayFulfillmentStatus
                currencyCode
                totalPriceSet { shopMoney { amount } }
                subtotalPriceSet { shopMoney { amount } }
                totalDiscountsSet { shopMoney { amount } }
                totalTaxSet { shopMoney { amount } }
                customer { id }
                retailLocation { id }
                lineItems(first: 50) {
                  edges {
                    node {
                      id
                      sku
                      title
                      quantity
                      variant { id }
                      product { id }
                      originalUnitPriceSet { shopMoney { amount } }
                      totalDiscountSet { shopMoney { amount } }
                      taxLines { priceSet { shopMoney { amount } } }
                    }
                  }
                }
                transactions(first: 20) {
                  id
                  kind
                  status
                  gateway
                  amountSet { shopMoney { amount } }
                  createdAt
                  processedAt
                  test
                }
                refunds(first: 20) {
                  id
                  createdAt
                  processedAt
                  note
                  refundLineItems(first: 50) {
                    edges {
                      node {
                        id
                        quantity
                        lineItem { id }
                        subtotalSet { shopMoney { amount } }
                        totalTaxSet { shopMoney { amount } }
                      }
                    }
                  }
                }
              }
            }
          }
        }
    ",

    IncrementalFilter = fn_IncrementalWindow("RAW_Orders"),
    BaseVariables = [first = 100, #"query" = IncrementalFilter],

    OrderNodes = fn_ShopifyPagedConnection(GraphQLQuery, BaseVariables, {"orders"})
in
    OrderNodes
