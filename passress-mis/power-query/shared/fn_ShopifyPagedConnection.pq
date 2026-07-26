// fn_ShopifyPagedConnection
// -----------------------------------------------------------------------------
// Fully paginates a Shopify GraphQL connection (edges / pageInfo) by repeatedly
// calling fn_ShopifyGraphQL and following pageInfo.endCursor, until either
// hasNextPage = false or Param_MaxPages is reached (automatic pagination +
// guaranteed termination).
//
// Inputs:
//   query          (text)   - GraphQL document. Must declare $first, $after,
//                              and whatever else baseVariables supplies (e.g. $query).
//                              Must select `pageInfo { hasNextPage endCursor }`
//                              and `edges { node { ... } }` on the target connection.
//   baseVariables  (record) - every GraphQL variable except $after, e.g.
//                              [first = 250, query = "updated_at:>='2026-01-01'"]
//   connectionPath (list)   - field names from the `data` object down to the
//                              connection, e.g. {"orders"} or {"inventoryItems"}
//
// Output: list of edge `node` records, across every page, in API order.
// -----------------------------------------------------------------------------
let
    fn_ShopifyPagedConnection = (query as text, baseVariables as record, connectionPath as list) as list =>
    let
        maxPages = Param_MaxPages,

        GetConnection = (dataRecord as record) as record =>
            List.Accumulate(connectionPath, dataRecord, (state, key) => Record.Field(state, key)),

        Seed = [
            PageIndex = 0,
            Cursor = null,
            HasNext = true,
            Nodes = {}
        ],

        Pages = List.Generate(
            () => Seed,
            each _[HasNext] and _[PageIndex] < maxPages,
            each
                let
                    variables = baseVariables & [after = _[Cursor]],
                    response = fn_ShopifyGraphQL(query, variables, 1),
                    connection = GetConnection(response[data]),
                    newNodes = List.Transform(connection[edges], each _[node])
                in
                    [
                        PageIndex = _[PageIndex] + 1,
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
