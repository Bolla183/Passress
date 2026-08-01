// fn_ShopifyPagedConnection
// -----------------------------------------------------------------------------
// Fully paginates a Shopify GraphQL connection (edges / pageInfo) by
// repeatedly calling fn_ShopifyGraphQL and following pageInfo.endCursor,
// until hasNextPage = false. Same design as the Excel MIS project's version
// — no per-refresh page cap parameter here (that existed in the Excel
// project as a safety net against a runaway refresh inside a single Excel
// session; Power BI's own refresh timeout serves the same purpose without
// needing a separate setting to maintain).
//
// Inputs:
//   query          (text)   - GraphQL document. Must declare $first, $after,
//                              select pageInfo { hasNextPage endCursor } and
//                              edges { node { ... } } on the target connection.
//   baseVariables  (record) - every GraphQL variable except $after
//   connectionPath (list)   - field names from `data` down to the connection,
//                              e.g. {"orders"}
// Output: list of edge `node` records, across every page, in API order.
// -----------------------------------------------------------------------------
let
    fn_ShopifyPagedConnection = (query as text, baseVariables as record, connectionPath as list) as list =>
    let
        GetConnection = (dataRecord as record) as record =>
            List.Accumulate(connectionPath, dataRecord, (state, key) => Record.Field(state, key)),

        Seed = [ Cursor = null, HasNext = true, Nodes = {} ],

        Pages = List.Generate(
            () => Seed,
            each _[HasNext],
            each
                let
                    variables = baseVariables & [after = _[Cursor]],
                    response = fn_ShopifyGraphQL(query, variables, 1),
                    connection = GetConnection(response[data]),
                    newNodes = List.Transform(connection[edges], each _[node])
                in
                    [
                        Cursor = connection[pageInfo][endCursor],
                        HasNext = connection[pageInfo][hasNextPage],
                        Nodes = newNodes
                    ]
        ),

        AllNodes = List.Combine(List.Transform(Pages, each _[Nodes]))
    in
        AllNodes
in
    fn_ShopifyPagedConnection
