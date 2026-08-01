// fn_ShopifyGraphQL
// -----------------------------------------------------------------------------
// Single authenticated POST to the Shopify Admin GraphQL API — the only
// query in this project that calls Web.Contents. Same proven design as the
// retired Excel MIS project's version of this function (that one was
// carefully built with retry/backoff/auth-error handling; no reason to
// simplify a function that was already correct).
//
// READ-ONLY BY DESIGN: only ever sends GraphQL `query` documents, never
// `mutation`. Pair with a Shopify custom-app token scoped to read_*
// permissions only (read_products, read_orders, read_customers,
// read_inventory) for defense in depth.
//
// AUTHENTICATION — NO HARDCODED TOKENS: the access token is never typed
// into this file. Power BI Desktop prompts for it the first time this
// query refreshes: when prompted for credentials on this Web source, choose
// "Web API" and paste the Shopify Admin API access token into the Key
// field. Power BI stores it in your OS credential store, not in the report.
//
// Inputs:
//   query      (text)   - GraphQL query document (must be `query`, not `mutation`)
//   variables  (record) - GraphQL variables, e.g. [first = 100, after = null]
//   attempt    (number, optional) - internal retry counter; callers omit or pass 1
// Output: record [data = <parsed GraphQL data object>, cost = <throttleStatus or null>]
// -----------------------------------------------------------------------------
let
    fn_ShopifyGraphQL = (query as text, variables as record, optional attempt as number) as record =>
    let
        attemptNumber = if attempt = null then 1 else attempt,
        maxAttempts = 5,

        url = "https://" & Param_ShopifyStoreDomain & "/admin/api/" & Param_ShopifyAPIVersion & "/graphql.json",
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
                ManualStatusHandling = {401, 402, 403, 404, 429, 500, 502, 503, 504},
                Timeout = #duration(0, 0, 1, 0)
            ]
        ),
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
                Function.InvokeAfter(
                    () => fn_ShopifyGraphQL(query, variables, attemptNumber + 1),
                    #duration(0, 0, 0, Number.Power(2, attemptNumber))
                )
            else if statusCode = 401 or statusCode = 403 then
                error Error.Record(
                    "Shopify.AuthError",
                    "Authentication to the Shopify Admin API failed (HTTP " & Text.From(statusCode) &
                    "). In Power BI Desktop: File > Options and settings > Data source settings > "
                    & "find this source > Edit Permissions, and re-enter the Shopify Admin API access "
                    & "token (Web API credential). Confirm the token has the required read_* scopes.",
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
