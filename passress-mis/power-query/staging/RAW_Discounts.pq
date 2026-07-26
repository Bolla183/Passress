// RAW_Discounts
// -----------------------------------------------------------------------------
// Shopify resource: Discounts (root query field `discountNodes` — NOT
// `codeDiscountNodes`, which only covers code-based discounts; `discountNodes`
// covers both code and automatic discounts, confirmed against the live schema).
// Incremental: NO — full reload every refresh, same reasoning as Collections
// (low volume, avoids depending on an unverified filter/sort on this field).
//
// DiscountNode.discount is a UNION (Discount) with NO shared fields — every
// field must come through a typed inline fragment (`... on TypeName { ... }`).
// This query covers the 6 most common discount types:
//   DiscountCodeBasic, DiscountCodeFreeShipping, DiscountCodeBxgy
//   DiscountAutomaticBasic, DiscountAutomaticFreeShipping, DiscountAutomaticBxgy
// DiscountCodeBasic's field shape (title, status, summary, startsAt, endsAt,
// createdAt, updatedAt, usageLimit, asyncUsageCount, codes) was verified
// directly against the live Admin GraphQL schema. Its two Code-family
// siblings (FreeShipping, Bxgy) are assumed to share that shape, following
// Shopify's consistent naming/design pattern for the DiscountCode* family —
// NOT independently verified field-by-field. The three Automatic-family
// fragments deliberately request only the minimal, lowest-risk common subset
// (title/status/dates) to reduce the chance of an unverified field breaking
// the whole query.
// KNOWN GAP: function-backed discounts (DiscountCodeApp, DiscountAutomaticApp)
// and any other discount type are NOT covered by a fragment here — those rows
// still come back (id + Typename), just with every detail column null. If
// the store uses app-based discount functions, extend this query's fragment
// list to match before relying on Discounts reporting.
// Output columns: DiscountNodeID, Typename, Title, Status, Summary, Code,
//                  StartsAt, EndsAt, UsageLimit, AsyncUsageCount, CreatedAt, UpdatedAt
// -----------------------------------------------------------------------------
let
    GraphQLQuery = "
        query Discounts($first: Int!, $after: String) {
          discountNodes(first: $first, after: $after) {
            pageInfo { hasNextPage endCursor }
            edges {
              node {
                id
                discount {
                  __typename
                  ... on DiscountCodeBasic {
                    title status summary startsAt endsAt createdAt updatedAt usageLimit asyncUsageCount
                    codes(first: 1) { edges { node { code } } }
                  }
                  ... on DiscountCodeFreeShipping {
                    title status summary startsAt endsAt createdAt updatedAt usageLimit asyncUsageCount
                    codes(first: 1) { edges { node { code } } }
                  }
                  ... on DiscountCodeBxgy {
                    title status summary startsAt endsAt createdAt updatedAt usageLimit asyncUsageCount
                    codes(first: 1) { edges { node { code } } }
                  }
                  ... on DiscountAutomaticBasic { title status startsAt endsAt createdAt updatedAt }
                  ... on DiscountAutomaticFreeShipping { title status startsAt endsAt createdAt updatedAt }
                  ... on DiscountAutomaticBxgy { title status startsAt endsAt createdAt updatedAt }
                }
              }
            }
          }
        }
    ",

    BaseVariables = [first = 250],

    Nodes = fn_ShopifyPagedConnection(GraphQLQuery, BaseVariables, {"discountNodes"}),

    ToTable = Table.FromRecords(Nodes, {"id", "discount"}, MissingField.UseNull),

    AddTypename = Table.AddColumn(ToTable, "Typename", each [discount][__typename], type text),
    AddTitle = Table.AddColumn(AddTypename, "Title", each try [discount][title] otherwise null, type text),
    AddStatus = Table.AddColumn(AddTitle, "Status", each try [discount][status] otherwise null, type text),
    AddSummary = Table.AddColumn(AddStatus, "Summary", each try [discount][summary] otherwise null, type text),
    AddCode = Table.AddColumn(AddSummary, "Code",
        each try List.First([discount][codes][edges])[node][code] otherwise null, type text),
    AddStartsAt = Table.AddColumn(AddCode, "StartsAt", each try [discount][startsAt] otherwise null, type datetime),
    AddEndsAt = Table.AddColumn(AddStartsAt, "EndsAt", each try [discount][endsAt] otherwise null, type datetime),
    AddUsageLimit = Table.AddColumn(AddEndsAt, "UsageLimit", each try [discount][usageLimit] otherwise null, Int64.Type),
    AddAsyncUsage = Table.AddColumn(AddUsageLimit, "AsyncUsageCount", each try [discount][asyncUsageCount] otherwise null, Int64.Type),
    AddCreatedAt = Table.AddColumn(AddAsyncUsage, "CreatedAt", each try [discount][createdAt] otherwise null, type datetime),
    AddUpdatedAt = Table.AddColumn(AddCreatedAt, "UpdatedAt", each try [discount][updatedAt] otherwise null, type datetime),

    Renamed = Table.RenameColumns(AddUpdatedAt, {{"id", "DiscountNodeID"}}),

    Reordered = Table.SelectColumns(Renamed,
        {"DiscountNodeID", "Typename", "Title", "Status", "Summary", "Code",
         "StartsAt", "EndsAt", "UsageLimit", "AsyncUsageCount", "CreatedAt", "UpdatedAt"})
in
    Reordered
