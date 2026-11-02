#Requires -Version 5.1
<#
  Passress.Shopify - READ-ONLY Shopify Admin GraphQL extraction.
  * Credentials: client id + client secret stored with Windows DPAPI (Export-Clixml of a PSCredential) in
    %LOCALAPPDATA%\Passress\shopify_credential.xml - encrypted for the current Windows user on this PC only,
    outside the project folder and outside git. Never written to workbooks, M code, logs or reports.
  * Token: OAuth client-credentials grant on every run (Dev Dashboard app tokens expire ~24h).
  * Every document sent is checked: anything that is not a pure `query` is refused before any network call.
  Field names verified against the Admin GraphQL schema (2026-07) with Shopify's schema tool.
#>
Set-StrictMode -Version 2.0
Import-Module (Join-Path $PSScriptRoot 'Passress.Common.psm1') -Force -DisableNameChecking

$credBase = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME '.local/share' }
$script:CredentialPath = Join-Path (Join-Path $credBase 'Passress') 'shopify_credential.xml'

$script:LineFields = 'id sku name title variantTitle quantity currentQuantity product { id } variant { id } originalUnitPriceSet { shopMoney { amount } } discountAllocations { allocatedAmountSet { shopMoney { amount } } } taxLines { priceSet { shopMoney { amount } } }'
$script:RefundLineFields = 'id quantity restockType restocked location { id name } subtotalSet { shopMoney { amount } } totalTaxSet { shopMoney { amount } } lineItem { id sku }'
$script:TxFields = 'id kind status gateway processedAt amountSet { shopMoney { amount } }'
$script:RefundFields = "id createdAt processedAt note totalRefundedSet { shopMoney { amount } } refundLineItems(first: 50) { pageInfo { hasNextPage endCursor } nodes { $($script:RefundLineFields) } } refundShippingLines(first: 10) { nodes { subtotalAmountSet { shopMoney { amount } } } } orderAdjustments(first: 20) { nodes { id reason amountSet { shopMoney { amount } } } } transactions(first: 20) { nodes { $($script:TxFields) } }"

function Get-PassressCredentialPath { return $script:CredentialPath }

function Set-PassressShopifyCredential {
    # Interactive: prompts for client id + secret (secret typed as SecureString, never echoed).
    [CmdletBinding()] param()
    $id = Read-Host 'Shopify app Client ID (Dev Dashboard > PASSRESS_DATA > Settings)'
    $sec = Read-Host 'NEW (rotated) Client Secret' -AsSecureString
    if ([string]::IsNullOrWhiteSpace($id) -or $sec.Length -eq 0) { throw 'Client ID and secret are required.' }
    $dir = Split-Path $script:CredentialPath -Parent
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $cred = New-Object System.Management.Automation.PSCredential ($id.Trim(), $sec)
    $cred | Export-Clixml -LiteralPath $script:CredentialPath   # DPAPI: only this Windows user on this PC can decrypt
    # Restrict the file to the current user only (remove inherited permissions).
    $acl = Get-Acl -LiteralPath $script:CredentialPath
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($rule in @($acl.Access)) { [void]$acl.RemoveAccessRule($rule) }
    $me = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($me, 'FullControl', 'Allow')))
    Set-Acl -LiteralPath $script:CredentialPath -AclObject $acl
    Write-PassressLog -Level OK -Message "Shopify credential stored (encrypted for $me) at $($script:CredentialPath). The secret is not displayed or logged."
}

function Test-PassressShopifyCredential { return (Test-Path -LiteralPath $script:CredentialPath) }

function Get-PassressShopifyToken {
    param([Parameter(Mandatory)]$Config)
    if (-not (Test-PassressShopifyCredential)) { throw "No Shopify credential found. Rotate the old secret in the Shopify Dev Dashboard, then run scripts\Set-PassressShopifyCredential.ps1." }
    $cred = Import-Clixml -LiteralPath $script:CredentialPath
    $secretPlain = $cred.GetNetworkCredential().Password
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $body = 'grant_type=client_credentials&client_id=' + [uri]::EscapeDataString($cred.UserName) + '&client_secret=' + [uri]::EscapeDataString($secretPlain)
        $uri = 'https://{0}/admin/oauth/access_token' -f $Config.ShopDomain
        $resp = Invoke-RestMethod -Method Post -Uri $uri -Body $body -ContentType 'application/x-www-form-urlencoded' -Headers @{ Accept = 'application/json' } -TimeoutSec 60 -ErrorAction Stop
        if (-not $resp.access_token) { throw 'Token response did not contain an access token.' }
        return $resp.access_token
    } catch {
        # Never include the request body (it contains the secret) in the error.
        $code = $null; try { $code = [int]$_.Exception.Response.StatusCode } catch { }
        throw ("SHOPIFY_AUTH_FAILED: token request rejected (HTTP {0}). Check the client id/secret (was the secret rotated and re-entered?) and the app's read scopes." -f $code)
    } finally { $secretPlain = $null }
}

function Assert-PassressReadOnlyQuery {
    param([Parameter(Mandatory)][string]$Document)
    $clean = ($Document -replace '#[^\r\n]*', '')
    if ($clean -match '(?i)\bmutation\b' -or $clean -match '(?i)\bsubscription\b' -or -not ($clean.TrimStart() -match '^(?i)(query\b|\{)')) {
        throw 'READ_ONLY_GUARD: only GraphQL queries are allowed in this phase. Document refused before sending.'
    }
}

function Invoke-PassressShopifyGraphQL {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Config, [Parameter(Mandatory)][string]$Token, [Parameter(Mandatory)][string]$Query, [hashtable]$Variables = @{})
    Assert-PassressReadOnlyQuery -Document $Query
    $uri = 'https://{0}/admin/api/{1}/graphql.json' -f $Config.ShopDomain, $Config.ApiVersion
    $payload = @{ query = $Query; variables = $Variables } | ConvertTo-Json -Depth 10 -Compress
    $maxAttempts = [int](Get-PassressConfigValue $Config 'ApiMaxRetries' 6)
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        $status = $null; $resp = $null; $retryAfter = $null
        try {
            $resp = Invoke-RestMethod -Method Post -Uri $uri -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) -ContentType 'application/json' -Headers @{ 'X-Shopify-Access-Token' = $Token; Accept = 'application/json' } -TimeoutSec 120 -ErrorAction Stop
        } catch {
            try { $status = [int]$_.Exception.Response.StatusCode } catch { $status = 0 }
            try { $retryAfter = $_.Exception.Response.Headers['Retry-After'] } catch { }
            if ($status -eq 401 -or $status -eq 403) { throw "SHOPIFY_AUTH_FAILED: HTTP $status. Token rejected or missing read scope." }
            if ($status -eq 429 -or $status -ge 500 -or $status -eq 0) {
                $wait = if ($retryAfter) { [double]$retryAfter } else { [math]::Min(60, [math]::Pow(2, $attempt)) }
                Write-PassressLog -Level WARN -Message "Shopify HTTP $status (attempt $attempt/$maxAttempts); retrying in $wait s."
                Start-Sleep -Seconds $wait; continue
            }
            throw "SHOPIFY_HTTP_ERROR: HTTP $status - $($_.Exception.Message)"
        }
        $errs = $null; if ($resp.PSObject.Properties.Name -contains 'errors') { $errs = $resp.errors }
        if ($errs) {
            $throttled = @($errs | Where-Object { $_.PSObject.Properties.Name -contains 'extensions' -and $_.extensions.code -eq 'THROTTLED' }).Count -gt 0
            if ($throttled -and $attempt -lt $maxAttempts) {
                $wait = 2
                try { $ts = $resp.extensions.cost.throttleStatus; $need = [double]$resp.extensions.cost.requestedQueryCost; $wait = [math]::Ceiling([math]::Max(1, ($need - [double]$ts.currentlyAvailable) / [double]$ts.restoreRate)) } catch { }
                Write-PassressLog -Level WARN -Message "Shopify THROTTLED; waiting $wait s."
                Start-Sleep -Seconds $wait; continue
            }
            throw ('SHOPIFY_GRAPHQL_ERROR: ' + (($errs | ForEach-Object { $_.message }) -join ' | '))
        }
        # proactive backoff when the bucket is low
        try { $ts = $resp.extensions.cost.throttleStatus; if ([double]$ts.currentlyAvailable -lt 100) { Start-Sleep -Seconds ([math]::Ceiling((100 - [double]$ts.currentlyAvailable) / [double]$ts.restoreRate)) } } catch { }
        return $resp.data
    }
    throw "SHOPIFY_RETRIES_EXHAUSTED after $maxAttempts attempts."
}

function Get-PassressPagedNodes {
    param([Parameter(Mandatory)]$Config, [Parameter(Mandatory)][string]$Token, [Parameter(Mandatory)][string]$Query, [Parameter(Mandatory)][string]$ConnectionField, [hashtable]$Variables = @{})
    $all = New-Object System.Collections.Generic.List[object]; $after = $null; $page = 0
    $maxPages = [int](Get-PassressConfigValue $Config 'ApiMaxPages' 2000)
    do {
        $vars = @{}; foreach ($k in $Variables.Keys) { $vars[$k] = $Variables[$k] }; $vars['after'] = $after
        $data = Invoke-PassressShopifyGraphQL -Config $Config -Token $Token -Query $Query -Variables $vars
        $conn = $data.$ConnectionField
        foreach ($n in @($conn.nodes)) { if ($null -ne $n) { $all.Add($n) } }
        $after = $conn.pageInfo.endCursor; $page++
        if ($page -ge $maxPages -and $conn.pageInfo.hasNextPage) { throw "SHOPIFY_PAGINATION_LIMIT: more than $maxPages pages of $ConnectionField. Raise ApiMaxPages." }
    } while ($conn.pageInfo.hasNextPage)
    return , $all.ToArray()
}

function Complete-PassressOrderNode {
    # Fetches the remainder of nested lists that hit their first-page limit, so nothing is silently truncated.
    param([Parameter(Mandatory)]$Config, [Parameter(Mandatory)][string]$Token, [Parameter(Mandatory)]$Order)
    if ($Order.lineItems.pageInfo.hasNextPage) {
        $q = "query(`$id: ID!, `$after: String) { order(id: `$id) { lineItems(first: 100, after: `$after) { pageInfo { hasNextPage endCursor } nodes { $($script:LineFields) } } } }"
        $nodes = @($Order.lineItems.nodes); $after = $Order.lineItems.pageInfo.endCursor
        do { $d = Invoke-PassressShopifyGraphQL -Config $Config -Token $Token -Query $q -Variables @{ id = $Order.id; after = $after }; $c = $d.order.lineItems; $nodes += @($c.nodes); $after = $c.pageInfo.endCursor } while ($c.pageInfo.hasNextPage)
        $Order.lineItems = [pscustomobject]@{ pageInfo = [pscustomobject]@{ hasNextPage = $false; endCursor = $null }; nodes = $nodes }
    }
    $refundCap = [int](Get-PassressConfigValue $Config 'RefundsFirstPage' 20)
    $txCap = [int](Get-PassressConfigValue $Config 'TransactionsFirstPage' 50)
    if (@($Order.refunds).Count -ge $refundCap -or @($Order.transactions).Count -ge $txCap) {
        $big = [int](Get-PassressConfigValue $Config 'MaxRefundsPerOrder' 250); $bigTx = [int](Get-PassressConfigValue $Config 'MaxTransactionsPerOrder' 250)
        $q = "query(`$id: ID!) { order(id: `$id) { transactions(first: $bigTx) { $($script:TxFields) } refunds(first: $big) { $($script:RefundFields) } } }"
        $d = Invoke-PassressShopifyGraphQL -Config $Config -Token $Token -Query $q -Variables @{ id = $Order.id }
        $Order.refunds = $d.order.refunds; $Order.transactions = $d.order.transactions
    }
    foreach ($rf in @($Order.refunds)) {
        if ($null -eq $rf -or -not $rf.refundLineItems.pageInfo.hasNextPage) { continue }
        $q = "query(`$id: ID!, `$after: String) { node(id: `$id) { ... on Refund { refundLineItems(first: 100, after: `$after) { pageInfo { hasNextPage endCursor } nodes { $($script:RefundLineFields) } } } } }"
        $nodes = @($rf.refundLineItems.nodes); $after = $rf.refundLineItems.pageInfo.endCursor
        do { $d = Invoke-PassressShopifyGraphQL -Config $Config -Token $Token -Query $q -Variables @{ id = $rf.id; after = $after }; $c = $d.node.refundLineItems; $nodes += @($c.nodes); $after = $c.pageInfo.endCursor } while ($c.pageInfo.hasNextPage)
        $rf.refundLineItems = [pscustomobject]@{ pageInfo = [pscustomobject]@{ hasNextPage = $false; endCursor = $null }; nodes = $nodes }
    }
    return $Order
}

function Invoke-PassressShopifyExtract {
    <#
      Full read-only extract (orders incl. refunds/transactions, customers, variants) to JSON files in $OutFolder.
      Full refresh on purpose: Power Query/CSV outputs are rebuilt each run, so a partial "incremental" window would
      drop history. At Passress's volume a full extract takes seconds-minutes.
    #>
    [CmdletBinding()] param([Parameter(Mandatory)]$Config, [Parameter(Mandatory)][string]$OutFolder)
    if (-not (Test-Path -LiteralPath $OutFolder)) { New-Item -ItemType Directory -Path $OutFolder -Force | Out-Null }
    $token = Get-PassressShopifyToken -Config $Config
    $pageSize = [int](Get-PassressConfigValue $Config 'OrdersPageSize' 10)
    $refundCap = [int](Get-PassressConfigValue $Config 'RefundsFirstPage' 20); $txCap = [int](Get-PassressConfigValue $Config 'TransactionsFirstPage' 50)
    $since = [string](Get-PassressConfigValue $Config 'HistoryStartDate' '')
    $filter = if ($since) { "created_at:>='$since'" } else { $null }
    $ordersQ = @"
query(`$first: Int!, `$after: String, `$query: String) {
  orders(first: `$first, after: `$after, query: `$query, sortKey: CREATED_AT) {
    pageInfo { hasNextPage endCursor }
    nodes {
      id name createdAt processedAt updatedAt cancelledAt cancelReason test displayFinancialStatus displayFulfillmentStatus currencyCode tags sourceName
      customer { id }
      subtotalPriceSet { shopMoney { amount } } totalDiscountsSet { shopMoney { amount } } totalShippingPriceSet { shopMoney { amount } }
      totalTaxSet { shopMoney { amount } } totalPriceSet { shopMoney { amount } } totalReceivedSet { shopMoney { amount } }
      totalRefundedSet { shopMoney { amount } } netPaymentSet { shopMoney { amount } }
      lineItems(first: 50) { pageInfo { hasNextPage endCursor } nodes { $($script:LineFields) } }
      transactions(first: $txCap) { $($script:TxFields) }
      refunds(first: $refundCap) { $($script:RefundFields) }
    }
  }
}
"@
    Write-PassressLog -Message 'Extracting orders (read-only)...'
    $orders = Get-PassressPagedNodes -Config $Config -Token $token -Query $ordersQ -ConnectionField 'orders' -Variables @{ first = $pageSize; query = $filter }
    $complete = @(); foreach ($o in $orders) { $complete += (Complete-PassressOrderNode -Config $Config -Token $token -Order $o) }
    Write-PassressLog -Message ("Orders extracted: {0}" -f $complete.Count)

    $custQ = 'query($first: Int!, $after: String) { customers(first: $first, after: $after) { pageInfo { hasNextPage endCursor } nodes { id displayName createdAt numberOfOrders amountSpent { amount } defaultEmailAddress { emailAddress marketingState } defaultPhoneNumber { phoneNumber } defaultAddress { city province country } } } }'
    $customers = Get-PassressPagedNodes -Config $Config -Token $token -Query $custQ -ConnectionField 'customers' -Variables @{ first = 100 }
    $varQ = 'query($first: Int!, $after: String) { productVariants(first: $first, after: $after) { pageInfo { hasNextPage endCursor } nodes { id sku title price inventoryQuantity selectedOptions { name value } inventoryItem { unitCost { amount } } product { id title productType vendor status } } } }'
    $variants = Get-PassressPagedNodes -Config $Config -Token $token -Query $varQ -ConnectionField 'productVariants' -Variables @{ first = 100 }
    $token = $null

    Write-PassressJson -Object $complete -Path (Join-Path $OutFolder 'orders.json')
    Write-PassressJson -Object $customers -Path (Join-Path $OutFolder 'customers.json')
    Write-PassressJson -Object $variants -Path (Join-Path $OutFolder 'variants.json')
    return [pscustomobject]@{ Orders = $complete.Count; Customers = @($customers).Count; Variants = @($variants).Count; Folder = $OutFolder }
}

Export-ModuleMember -Function Set-PassressShopifyCredential, Test-PassressShopifyCredential, Get-PassressCredentialPath, Invoke-PassressShopifyExtract, Assert-PassressReadOnlyQuery, Invoke-PassressShopifyGraphQL
