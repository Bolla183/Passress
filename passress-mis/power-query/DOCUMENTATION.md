# PASSRESS MIS — Phase 2 Reference: Every Query, Parameter, and Field

Schema field names below were verified against the live Shopify Admin GraphQL
schema via introspection immediately before writing each query — not recalled
from training data. Where a mapping is inferred rather than directly
verified (the discount-type family), it's flagged explicitly.

---

## 1. Parameters

| Query | Type | Reads (named range, on 15_Settings) | Purpose |
|---|---|---|---|
| `Param_ShopifyStoreDomain` | text | `SetShopifyStoreDomain` | Store domain used to build every API URL |
| `Param_ShopifyAPIVersion` | text | `SetShopifyAPIVersion` | Admin API version, e.g. `2025-01` |
| `Param_LookbackDays` | number | `SetLookbackDaysIncrementalRefresh` | Rolling incremental re-check window, in days |
| `Param_MaxPages` | number | `SetMaxPagesPerRefreshSafetyCap` | Pagination hard stop, per query per refresh |
| `Param_HistoricalBackfillStartDate` | date | `SetHistoricalBackfillStartDate` | Start date for a table's first-ever (empty-table) load |

None of these ever hold the access token — see §2, `fn_ShopifyGraphQL`.

---

## 2. Shared Functions

| Query | Purpose |
|---|---|
| `fn_ShopifyGraphQL(query, variables, attempt)` | The only place that calls `Web.Contents`. Authenticates via `Extension.CurrentCredential()` (never a hardcoded token), retries on 429/5xx with backoff, retries on Shopify's cost-based throttle, raises `Shopify.AuthError` / `Shopify.GraphQLError` / `Shopify.HttpError` with actionable messages. Read-only: only ever called with `query` documents, never `mutation`. |
| `fn_ShopifyPagedConnection(query, baseVariables, connectionPath)` | Automatic pagination: repeatedly calls `fn_ShopifyGraphQL`, follows `pageInfo.endCursor`, stops at `hasNextPage = false` or `Param_MaxPages`. Returns the flat list of every page's `edges[].node`. |
| `fn_IncrementalWindow(tableName)` | Returns a `updated_at:>='...'` filter fragment: `Param_HistoricalBackfillStartDate` if `tableName`'s current table is empty, else `now − Param_LookbackDays`. |
| `fn_AppendLog(tableName, newRow)` | Reads a `LOG_` table's current contents, appends one new row, returns the combined table — Excel's only way to fake an append-only log across refreshes. |

---

## 3. Staging Queries

Grain, incremental behavior, and the destination-column ← GraphQL-source-path
mapping for every RAW_/LOG_ query. "Root" is the GraphQL root query field
each ultimately reads from (directly, or via `Orders_Source`).

### RAW_Products — root `products` — incremental: yes (`updated_at`, sortKey `UPDATED_AT`)
Grain: one row per product.

| Column | Source path | Notes |
|---|---|---|
| ProductID | `id` | |
| Title | `title` | |
| ProductType | `productType` | |
| Vendor | `vendor` | |
| CollectionIDs | `collections(first:20).edges[].node.id` | joined with `"; "` |
| CreatedAt | `createdAt` | |
| UpdatedAt | `updatedAt` | drives incremental refresh |
| Status | `status` | |

### RAW_Variants — root `productVariants` — incremental: yes (`updated_at`, sortKey `UPDATED_AT`)
Grain: one row per product variant.

| Column | Source path | Notes |
|---|---|---|
| VariantID | `id` | |
| ProductID | `product.id` | |
| SKU | `sku` | |
| Title | `title` | |
| Price | `price` | `Money` scalar (decimal string), used directly |
| CompareAtPrice | `compareAtPrice` | `Money` scalar |
| InventoryItemID | `inventoryItem.id` | |
| UnitCost | `inventoryItem.unitCost.amount` | `MoneyV2` object — `.amount` required. Requires "View product costs" permission on the token's owning staff account |
| CreatedAt | `createdAt` | |
| UpdatedAt | `updatedAt` | |

### Orders_Source — root `orders` — incremental: yes (`updated_at`, sortKey `UPDATED_AT`)
**Connection-only** shared query (not loaded to a sheet). Fetches orders with
lineItems, transactions, and refunds nested in a single GraphQL call — see
§"Design note" below. `RAW_Orders`, `RAW_OrderLines`, `RAW_Transactions`, and
`RAW_Refunds` all read from this one query's output.

### RAW_Orders — from `Orders_Source` — grain: one row per order

| Column | Source path | Notes |
|---|---|---|
| OrderID | `id` | |
| OrderNumber | `name` | |
| CreatedAt | `createdAt` | |
| UpdatedAt | `updatedAt` | drives incremental refresh |
| FinancialStatus | `displayFinancialStatus` | |
| FulfillmentStatus | `displayFulfillmentStatus` | |
| Currency | `currencyCode` | |
| TotalPrice | `totalPriceSet.shopMoney.amount` | shop currency, not presentment |
| SubtotalPrice | `subtotalPriceSet.shopMoney.amount` | |
| TotalDiscounts | `totalDiscountsSet.shopMoney.amount` | |
| TotalTax | `totalTaxSet.shopMoney.amount` | |
| CustomerID | `customer.id` | null for guest/POS orders without a linked customer |
| LocationID | `retailLocation.id` | **populated only for POS/retail orders** — null for ordinary online orders, by design |

### RAW_OrderLines — from `Orders_Source` — grain: one row per order line item (≤50/order)

| Column | Source path | Notes |
|---|---|---|
| LineItemID | `lineItems.edges[].node.id` | |
| OrderID | parent order `id` | |
| ProductID | `lineItems.edges[].node.product.id` | |
| VariantID | `lineItems.edges[].node.variant.id` | |
| SKU | `lineItems.edges[].node.sku` | |
| Title | `lineItems.edges[].node.title` | |
| Quantity | `lineItems.edges[].node.quantity` | includes refunded/removed units |
| UnitPrice | `originalUnitPriceSet.shopMoney.amount` | pre-discount |
| DiscountAllocated | `totalDiscountSet.shopMoney.amount` | line-level only, excludes order-level/code discounts |
| TaxAllocated | `SUM(taxLines[].priceSet.shopMoney.amount)` | a line can have multiple tax lines (jurisdictions) |

### RAW_Transactions — from `Orders_Source` — grain: one row per order transaction (≤20/order)
No root-level `transactions` query exists in the schema — nested under Order only.

| Column | Source path | Notes |
|---|---|---|
| TransactionID | `transactions[].id` | |
| OrderID | parent order `id` | |
| Kind | `transactions[].kind` | enum: SALE / CAPTURE / AUTHORIZATION / VOID / REFUND / CHANGE / SUGGESTED_REFUND |
| Status | `transactions[].status` | enum: SUCCESS / PENDING / FAILURE / ERROR / AWAITING_RESPONSE |
| Gateway | `transactions[].gateway` | e.g. `shopify_payments` |
| AmountShop | `amountSet.shopMoney.amount` | |
| CurrencyShop | parent order `currencyCode` | |
| CreatedAt | `transactions[].createdAt` | |
| ProcessedAt | `transactions[].processedAt` | |
| Test | `transactions[].test` | boolean |

### RAW_Refunds — from `Orders_Source` — grain: one row per refunded line item (≤50/refund, ≤20 refunds/order)
No root-level `refund` list exists — `Refund` is only reachable nested under
Order. **Grain correction from the Phase 1 skeleton**: originally assumed one
row per refund with a per-line "Reason"; the verified schema has no per-line
reason field, so grain is now one row per `RefundLineItem`, and `Note` is the
refund-level note (repeated across that refund's rows).

| Column | Source path | Notes |
|---|---|---|
| RefundLineItemID | `refunds[].refundLineItems.edges[].node.id` | |
| RefundID | `refunds[].id` | one refund can have several line rows |
| OrderID | parent order `id` | |
| LineItemID | `refundLineItems.edges[].node.lineItem.id` | links back to RAW_OrderLines |
| Quantity | `refundLineItems.edges[].node.quantity` | |
| SubtotalAmount | `subtotalSet.shopMoney.amount` | |
| TaxAmount | `totalTaxSet.shopMoney.amount` | |
| RefundCreatedAt | `refunds[].createdAt` | |
| RefundProcessedAt | `refunds[].processedAt` | |
| Note | `refunds[].note` | refund-level, not line-level |

### RAW_Customers — root `customers` — incremental: yes (`updated_at`, sortKey `UPDATED_AT`)
Grain: one row per customer.

| Column | Source path | Notes |
|---|---|---|
| CustomerID | `id` | |
| FirstName | `firstName` | |
| LastName | `lastName` | |
| Email | `defaultEmailAddress.emailAddress` | **not** a plain `email` field — that field was deprecated/removed from the schema |
| CreatedAt | `createdAt` | |
| UpdatedAt | `updatedAt` | drives incremental refresh |
| OrdersCount | `numberOfOrders` | lifetime count |
| TotalSpent | `amountSpent.amount` | lifetime, shop currency |
| DefaultAddressCountry | `defaultAddress.country` | |

### RAW_Collections — root `collections` — incremental: **no** (full reload every refresh)
Grain: one row per collection. Low volume for a single-brand catalog; a full
reload avoids depending on an unverified `updated_at` filter/sort on this
connection.

| Column | Source path |
|---|---|
| CollectionID | `id` |
| Title | `title` |
| Handle | `handle` |

### RAW_InventoryLevels — root `inventoryItems` — incremental: yes (`updated_at` query filter; **no `sortKey` argument exists on this field**, confirmed against the live schema)
Grain: one row per InventoryItem × Location.

| Column | Source path | Notes |
|---|---|---|
| InventoryItemID | `id` | |
| SKU | `sku` | |
| LocationID | `inventoryLevels.edges[].node.location.id` | |
| Available | `inventoryLevels.edges[].node.quantities(names:["available"])[].quantity` | modern `quantities` field, not the deprecated flat `available` |
| UpdatedAt | `inventoryLevels.edges[].node.updatedAt` | this is the InventoryLevel's own updatedAt, not the InventoryItem's |

### RAW_Discounts — root `discountNodes` — incremental: **no** (full reload every refresh)
Grain: one row per discount. `DiscountNode.discount` is a GraphQL **union**
with no shared fields — every field requires a typed inline fragment.

| Column | Source path | Notes |
|---|---|---|
| DiscountNodeID | `id` | |
| Typename | `discount.__typename` | tells you which concrete discount type this row is |
| Title | `discount.<Type>.title` | |
| Status | `discount.<Type>.status` | |
| Summary | `discount.<Type>.summary` | human-readable description, e.g. "20% off Sale collection" — **code types only** |
| Code | `discount.<Type>.codes(first:1).edges[0].node.code` | **code types only**, first code if several exist |
| StartsAt | `discount.<Type>.startsAt` | |
| EndsAt | `discount.<Type>.endsAt` | |
| UsageLimit | `discount.<Type>.usageLimit` | **code types only** |
| AsyncUsageCount | `discount.<Type>.asyncUsageCount` | **code types only**, eventually-consistent per Shopify's own docs |
| CreatedAt | `discount.<Type>.createdAt` | |
| UpdatedAt | `discount.<Type>.updatedAt` | |

**Verified vs. inferred:** `DiscountCodeBasic`'s field shape was confirmed
directly against the live schema. `DiscountCodeFreeShipping` and
`DiscountCodeBxgy` are assumed to share it (Shopify's consistent
`DiscountCode*` naming/design pattern) but **not independently verified**.
The three `DiscountAutomatic*` fragments deliberately request only
title/status/dates — the lowest-risk common subset — for the same reason.
Function-backed (app) discounts aren't covered by any fragment; those rows
still appear (ID + Typename), with every other column null.

### LOG_RefreshHistory — reads all 10 RAW_ query outputs by name
One row appended per Refresh All. `RowsLoaded` = total rows across every
`RAW_` table this refresh. `RowsUpdated`, `Errors`, `DurationSeconds` are
placeholder columns (0) — see README's Known Limitations.

### LOG_DataQuality — reads all 10 RAW_ query outputs by name
One row appended per `RAW_` table per refresh: `RowCountCheck`, `Status` =
`OK` or `WARNING - No rows returned`, `Details` = row count.

---

## Design note: why `Orders_Source` exists

GraphQL lets a single query nest related data (orders → line items →
transactions → refunds) in one round trip. Fetching those four resources
independently would mean four separate paginated API calls covering largely
the same orders — four times the requests, four times the rate-limit cost,
and four independent (and possibly inconsistent) incremental windows.
`Orders_Source` fetches the nested bundle once; `RAW_Orders`,
`RAW_OrderLines`, `RAW_Transactions`, and `RAW_Refunds` each just select and
flatten the slice they need from that one shared result — Excel's query
dependency graph makes sure `Orders_Source` only actually runs once per
refresh even though four other queries reference it.
