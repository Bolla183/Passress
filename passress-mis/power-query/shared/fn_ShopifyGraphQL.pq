// fn_ShopifyGraphQL
// -----------------------------------------------------------------------------
// Single authenticated POST to the Shopify Admin GraphQL API, with GraphQL-level
// and HTTP-level error handling and cost-based throttle backoff.
//
// READ-ONLY BY DESIGN: this project only ever sends GraphQL `query` documents
// through this function, never `mutation`. Pair that with a Shopify custom-app
// token scoped to read_* permissions only (read_products, read_orders,
// read_customers, read_inventory, read_discounts) for defense in depth — even
// if a query were ever mistakenly changed to a mutation, the token itself
// would reject the write.
//
// AUTHENTICATION — NO HARDCODED TOKENS:
// The access token never appears anywhere in this file. Excel prompts for it
// the first time this query (or any query calling it) is refreshed:
//   Data > Get Data > Data Source Settings > select this Web source > Edit
//   Permissions > Credentials > Edit... > choose "Web API" > paste the
//   Shopify Admin API access token into the Key field.
// Excel stores that token in the OS credential vault (Windows Credential
// Manager / macOS Keychain), not in the workbook. Extension.CurrentCredential()
// retrieves it at refresh time.
//
// Inputs:
//   query      (text)   - GraphQL query document (must be a `query`, not `mutation`)
//   variables  (record) - GraphQL variables, e.g. [first = 250, after = null, query = "..."]
//   attempt    (number, optional) - internal retry counter; callers should omit it or pass 1
//
// Output: record [data = <parsed GraphQL data object>, cost = <throttleStatus record or null>]
//
// Errors raised (all as Error.Record so Excel/Query Diagnostics show a clear reason):
//   Shopify.AuthError    - HTTP 401/403: bad/missing/under-scoped token
//   Shopify.GraphQLError - HTTP 200 but the `errors` array is non-empty
//   Shopify.HttpError    - any other non-2xx status after retries are exhausted
// -----------------------------------------------------------------------------
let
    fn_ShopifyGraphQL = (query as text, variables as record, optional attempt as number) as record =>
    let
        attemptNumber = if attempt = null then 1 else attempt,
        maxAttempts = 5,

        storeDomain = Param_ShopifyStoreDomain,
        apiVersion = Param_ShopifyAPIVersion,
        url = "https://" & storeDomain & "/admin/api/" & apiVersion & "/graphql.json",
        requestBody = Json.FromValue([query = query, variables = variables]),

        rawResponse = Web.Contents(
            url,
            [
                Headers = [
                    #"X-Shopify-Access-Token" = Extension.CurrentCredential()[Key],
                    #"Content-Type" = "application/json",
                    Accept = "application/json"
                ],
                Content = requestBody,
                // ManualStatusHandling means Web.Contents returns the body instead of
                // throwing on these codes, so we can branch on status ourselves below.
                ManualStatusHandling = {401, 402, 403, 404, 429, 500, 502, 503, 504},
                Timeout = #duration(0, 0, 1, 0)
            ]
        ),
        // Standard idiom for reading the HTTP status Web.Contents attaches as
        // metadata when ManualStatusHandling is set (present for every status
        // code we listed above, including 200 — there is no null case here).
        statusCode = Value.Metadata(rawResponse)[Response.Status],
        responseHeaders = Value.Metadata(rawResponse)[Headers],

        result =
            if statusCode = 200 then
                let
                    parsed = Json.Document(rawResponse),
                    hasGraphQLErrors = Record.HasFields(parsed, "errors") and List.Count(parsed[errors]) > 0,
                    throttle = try parsed[extensions][cost][throttleStatus] otherwise null,
                    currentlyAvailable = if throttle <> null then throttle[currentlyAvailable] else 1000,
                    restoreRate = if throttle <> null then throttle[restoreRate] else 50,
                    lowOnBudget = currentlyAvailable < 100
                in
                    if hasGraphQLErrors then
                        error Error.Record(
                            "Shopify.GraphQLError",
                            "The Shopify GraphQL API returned one or more errors for this query.",
                            Text.Combine(List.Transform(parsed[errors], each Record.Field(_, "message")), " | ")
                        )
                    else if lowOnBudget and attemptNumber < maxAttempts then
                        // Cost-based throttling: pause long enough for the point bucket to
                        // refill before retrying, instead of burning through the API limit.
                        let
                            waitSeconds = Number.RoundUp((100 - currentlyAvailable) / restoreRate) + 1
                        in
                            Function.InvokeAfter(
                                () => fn_ShopifyGraphQL(query, variables, attemptNumber + 1),
                                #duration(0, 0, 0, waitSeconds)
                            )
                    else
                        [data = parsed[data], cost = throttle]
            else if statusCode = 429 and attemptNumber < maxAttempts then
                let
                    retryAfterText = try Record.Field(responseHeaders, "Retry-After") otherwise "2",
                    waitSeconds = try Number.From(Text.From(retryAfterText)) otherwise 2
                in
                    Function.InvokeAfter(
                        () => fn_ShopifyGraphQL(query, variables, attemptNumber + 1),
                        #duration(0, 0, 0, waitSeconds)
                    )
            else if List.Contains({500, 502, 503, 504}, statusCode) and attemptNumber < maxAttempts then
                // Exponential backoff for transient server-side failures: 2s, 4s, 8s, 16s.
                Function.InvokeAfter(
                    () => fn_ShopifyGraphQL(query, variables, attemptNumber + 1),
                    #duration(0, 0, 0, Number.Power(2, attemptNumber))
                )
            else if statusCode = 401 or statusCode = 403 then
                error Error.Record(
                    "Shopify.AuthError",
                    "Authentication to the Shopify Admin API failed (HTTP " & Text.From(statusCode) &
                    "). In Excel: Data > Get Data > Data Source Settings > Edit Permissions for this " &
                    "source, and re-enter the Shopify Admin API access token (Web API credential). " &
                    "Also confirm the token has the required read_* scopes for this query.",
                    Text.FromBinary(rawResponse)
                )
            else
                error Error.Record(
                    "Shopify.HttpError",
                    "The Shopify Admin API returned HTTP " & Text.From(statusCode) &
                    " after " & Text.From(attemptNumber) & " attempt(s).",
                    Text.FromBinary(rawResponse)
                )
    in
        result
in
    fn_ShopifyGraphQL
