# Stage 01 - DATA SOURCE. Pure transformation: Shopify GraphQL nodes + ORDER_CLASSIFICATION -> normalized tables.
# No cost logic here (cost lives in 02 to avoid a circular dependency).

function Resolve-PassressClassification {
    param([AllowEmptyCollection()][object[]]$ClassificationRows, [string]$RunId)
    $byGid = @{}; $byName = @{}; $ex = New-List
    foreach ($r in @($ClassificationRows)) {
        $gid = [string](Get-RowValue $r 'OrderGID'); $name = [string](Get-RowValue $r 'OrderName')
        $cls = ([string](Get-RowValue $r 'Classification')).Trim().ToUpperInvariant()
        $key = if ($gid) { $gid } else { $name }
        if (-not $key) { continue }
        $entry = [pscustomobject]@{ Classification = $cls; Valid = ($cls -eq 'TEST' -or $cls -eq 'REAL'); Reason = (Get-RowValue $r 'Reason') }
        if (-not $entry.Valid) {
            $ex.Add((New-PassressException -CheckName 'CLASSIFICATION_INVALID_VALUE' -Severity ERROR -AffectedRecord $key -OrderName $name -ExpectedValue 'TEST or REAL' -ActualValue $cls -RecommendedAction 'Fix the Classification value in ORDER_CLASSIFICATION. The order is excluded from reports until fixed.' -RunId $RunId))
        }
        $target = if ($gid) { $byGid } else { $byName }
        if ($target.ContainsKey($key) -and $target[$key].Classification -ne $entry.Classification) {
            $ex.Add((New-PassressException -CheckName 'CLASSIFICATION_CONFLICT' -Severity ERROR -AffectedRecord $key -OrderName $name -ExpectedValue $target[$key].Classification -ActualValue $entry.Classification -RecommendedAction 'Keep a single classification row per order.' -RunId $RunId))
            $entry = [pscustomobject]@{ Classification = 'CONFLICT'; Valid = $false; Reason = 'Conflicting rows' }
        }
        $target[$key] = $entry
    }
    return [pscustomobject]@{ ByGid = $byGid; ByName = $byName; Exceptions = $ex }
}

function Get-OrderClassification {
    param($Resolved, [string]$OrderGID, [string]$OrderName, [bool]$ShopifyTest, [string]$Tags, [string]$TestTag)
    $entry = $null
    if ($OrderGID -and $Resolved.ByGid.ContainsKey($OrderGID)) { $entry = $Resolved.ByGid[$OrderGID] }
    elseif ($OrderName -and $Resolved.ByName.ContainsKey($OrderName)) { $entry = $Resolved.ByName[$OrderName] }
    if ($null -ne $entry) {
        if ($entry.Valid) { return @{ Classification = $entry.Classification; Source = 'MANUAL' } }
        return @{ Classification = 'UNCLASSIFIED'; Source = 'INVALID_ENTRY' }
    }
    if ($ShopifyTest) { return @{ Classification = 'TEST'; Source = 'SHOPIFY_TEST_FLAG' } }
    if ($TestTag -and $Tags) {
        foreach ($t in $Tags.Split(',')) { if ($t.Trim() -ieq $TestTag) { return @{ Classification = 'TEST'; Source = 'TEST_TAG' } } }
    }
    return @{ Classification = 'REAL'; Source = 'DEFAULT' }   # new orders are never silently TEST
}

function Invoke-PassressDataSourceStage {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()][object[]]$OrderNodes, [AllowEmptyCollection()][object[]]$CustomerNodes, [AllowEmptyCollection()][object[]]$VariantNodes,
        [AllowEmptyCollection()][object[]]$ClassificationRows, [Parameter(Mandatory)]$Config, [Parameter(Mandatory)][string]$RunId
    )
    $tz = Get-ShopTimeZone $Config
    $testTag = if ($Config.PSObject.Properties.Name -contains 'TestOrderTag') { [string]$Config.TestOrderTag } else { '' }
    $currency = [string]$Config.Currency

    $T = @{}
    foreach ($n in @('RAW_ORDERS', 'ORDER_LINE_ITEMS', 'ORDER_TRANSACTIONS', 'RAW_REFUNDS', 'REFUND_LINE_ITEMS', 'REFUND_TRANSACTIONS', 'RAW_CUSTOMERS', 'RAW_PRODUCTS', 'RAW_VARIANTS', 'SALES_FACT', 'REVENUE_EVENTS', 'REFUND_RECONCILIATION')) { $T[$n] = New-List }
    $ex = New-List

    $resolved = Resolve-PassressClassification -ClassificationRows $ClassificationRows -RunId $RunId
    foreach ($e in $resolved.Exceptions) { $ex.Add($e) }

    $seenOrders = @{}; $seenLines = @{}; $seenRefunds = @{}; $seenTx = @{}; $matchedClassKeys = @{}

    foreach ($o in @($OrderNodes)) {
        $gid = [string](Get-JsonValue $o 'id'); $name = [string](Get-JsonValue $o 'name')
        if (-not $gid) { $ex.Add((New-PassressException -CheckName 'ORDER_WITHOUT_ID' -Severity ERROR -AffectedRecord $name -OrderName $name -RecommendedAction 'Check the API response; the order was skipped.' -RunId $RunId)); continue }
        if ($seenOrders.ContainsKey($gid)) { $ex.Add((New-PassressException -CheckName 'DUPLICATE_ORDER' -Severity WARNING -AffectedRecord $gid -OrderName $name -RecommendedAction 'Duplicate API record ignored (first occurrence kept).' -RunId $RunId)); continue }
        $seenOrders[$gid] = $true

        $createdUtc = Get-JsonValue $o 'createdAt'; $cancelledUtc = Get-JsonValue $o 'cancelledAt'
        $tagsVal = Get-JsonValue $o 'tags'; $tags = if ($tagsVal -is [System.Array]) { ($tagsVal -join ', ') } else { [string]$tagsVal }
        $shopTest = ConvertTo-PassressBool (Get-JsonValue $o 'test')
        $cls = Get-OrderClassification -Resolved $resolved -OrderGID $gid -OrderName $name -ShopifyTest $shopTest -Tags $tags -TestTag $testTag
        if ($resolved.ByGid.ContainsKey($gid)) { $matchedClassKeys[$gid] = $true }
        if ($name -and $resolved.ByName.ContainsKey($name)) { $matchedClassKeys[$name] = $true }
        $classification = $cls.Classification; $reportable = ($classification -eq 'REAL')
        $sev = if ($reportable) { 'ERROR' } else { 'INFO' }

        if ($classification -eq 'TEST') {
            $ex.Add((New-PassressException -CheckName 'TEST_ORDER_EXCLUDED' -Severity INFO -AffectedRecord $gid -OrderName $name -Classification 'TEST' -ActualValue $cls.Source -RecommendedAction 'None - kept in raw data for audit, excluded from all sales, revenue, COGS, inventory and KPIs.' -RunId $RunId))
        } elseif ($classification -eq 'UNCLASSIFIED') {
            $ex.Add((New-PassressException -CheckName 'UNCLASSIFIED_ORDER' -Severity ERROR -AffectedRecord $gid -OrderName $name -Classification 'UNCLASSIFIED' -RecommendedAction 'Fix ORDER_CLASSIFICATION. Order excluded from reports until classified.' -RunId $RunId))
        }

        $orderDate = $null
        if (Test-Blank $createdUtc) { $ex.Add((New-PassressException -CheckName 'MISSING_ORDER_DATE' -Severity ERROR -AffectedRecord $gid -OrderName $name -Classification $classification -RecommendedAction 'Order has no createdAt; it cannot be placed in a month.' -RunId $RunId)) }
        else { $orderDate = ConvertTo-ShopLocalDate -UtcValue $createdUtc -TimeZone $tz }
        $cancelDate = if (Test-Blank $cancelledUtc) { $null } else { ConvertTo-ShopLocalDate -UtcValue $cancelledUtc -TimeZone $tz }
        $isCancelled = ($null -ne $cancelDate)
        $customerGid = [string](Get-JsonValue $o 'customer.id')
        if ($reportable -and -not $customerGid) { $ex.Add((New-PassressException -CheckName 'MISSING_CUSTOMER_ID' -Severity WARNING -AffectedRecord $gid -OrderName $name -Classification $classification -RecommendedAction 'Order has no customer; customer KPIs will not include it.' -RunId $RunId)) }

        $finStatus = [string](Get-JsonValue $o 'displayFinancialStatus'); $fulStatus = [string](Get-JsonValue $o 'displayFulfillmentStatus')
        $shipping = Get-MoneyValue $o 'totalShippingPriceSet'
        $subtotal = Get-MoneyValue $o 'subtotalPriceSet'; $orderDiscounts = Get-MoneyValue $o 'totalDiscountsSet'
        $received = Get-MoneyValue $o 'totalReceivedSet'; $refundedReported = Get-MoneyValue $o 'totalRefundedSet'

        $T.RAW_ORDERS.Add([ordered]@{
            OrderGID = $gid; OrderName = $name; CreatedAtUtc = $createdUtc; ProcessedAtUtc = (Get-JsonValue $o 'processedAt'); UpdatedAtUtc = (Get-JsonValue $o 'updatedAt')
            CancelledAtUtc = $cancelledUtc; CancelReason = (Get-JsonValue $o 'cancelReason'); ShopifyTestFlag = $shopTest
            FinancialStatus = $finStatus; FulfillmentStatus = $fulStatus; Currency = (Get-JsonValue $o 'currencyCode')
            Subtotal = $subtotal; Discounts = $orderDiscounts; Shipping = $shipping; Taxes = (Get-MoneyValue $o 'totalTaxSet')
            TotalPrice = (Get-MoneyValue $o 'totalPriceSet'); TotalReceived = $received; TotalRefunded = $refundedReported
            NetPayment = (Get-MoneyValue $o 'netPaymentSet'); CustomerGID = $customerGid; SourceName = (Get-JsonValue $o 'sourceName'); Tags = $tags; ExtractRunId = $RunId
        })

        # ---------------- line items
        $lineConn = Get-JsonValue $o 'lineItems'
        if (ConvertTo-PassressBool (Get-JsonValue $lineConn 'pageInfo.hasNextPage')) {
            $ex.Add((New-PassressException -CheckName 'LINE_ITEMS_TRUNCATED' -Severity ERROR -AffectedRecord $gid -OrderName $name -Classification $classification -RecommendedAction 'The extractor did not fetch all line items for this order. Re-run the refresh; report if it persists.' -RunId $RunId))
        }
        $lines = @{}; $lineOrder = New-List
        foreach ($li in (Get-ConnectionNodes $lineConn)) {
            $lgid = [string](Get-JsonValue $li 'id')
            if (-not $lgid) { continue }
            if ($seenLines.ContainsKey($lgid)) { $ex.Add((New-PassressException -CheckName 'DUPLICATE_LINE_ITEM' -Severity ERROR -AffectedRecord $lgid -OrderName $name -Classification $classification -RecommendedAction 'Duplicate line item ignored.' -RunId $RunId)); continue }
            $seenLines[$lgid] = $true
            $qty = [int](Get-Money (Get-JsonValue $li 'quantity'))
            $unit = Get-MoneyValue $li 'originalUnitPriceSet'
            $disc = 0.0; foreach ($d in @(Get-JsonValue $li 'discountAllocations')) { if ($null -ne $d) { $disc += (Get-MoneyValue $d 'allocatedAmountSet') } }
            $tax = 0.0; foreach ($t in @(Get-JsonValue $li 'taxLines')) { if ($null -ne $t) { $tax += (Get-MoneyValue $t 'priceSet') } }
            $gross = Get-RoundedMoney ($qty * $unit); $disc = Get-RoundedMoney $disc; $tax = Get-RoundedMoney $tax
            $sku = [string](Get-JsonValue $li 'sku')
            $line = [ordered]@{
                LineItemGID = $lgid; OrderGID = $gid; OrderName = $name; ProductGID = [string](Get-JsonValue $li 'product.id'); VariantGID = [string](Get-JsonValue $li 'variant.id')
                SKU = $sku; ProductTitle = [string](Get-JsonValue $li 'title'); VariantTitle = [string](Get-JsonValue $li 'variantTitle')
                Quantity = $qty; CurrentQuantity = (Get-JsonValue $li 'currentQuantity'); UnitPrice = $unit; LineDiscount = $disc
                GrossLineAmount = $gross; NetLineAmount = (Get-RoundedMoney ($gross - $disc)); LineTax = $tax; CreatedAtUtc = $createdUtc
            }
            $T.ORDER_LINE_ITEMS.Add($line); $lines[$lgid] = $line; $lineOrder.Add($lgid)
            if (Test-Blank $sku) {
                $ex.Add((New-PassressException -CheckName 'MISSING_SKU' -Severity $sev -AffectedRecord $lgid -OrderName $name -Classification $classification -ActualValue ([string](Get-JsonValue $li 'name')) -RecommendedAction 'Set a SKU on this variant in Shopify (the system will not invent one). Costing and inventory cannot be applied to this line.' -RunId $RunId))
            }
        }
        $sumNet = Get-SumOf -Items @($lines.Values) -Property 'NetLineAmount'
        if ($lines.Count -gt 0 -and -not (Test-MoneyEqual $sumNet $subtotal)) {
            $ex.Add((New-PassressException -CheckName 'ORDER_SUBTOTAL_VS_LINES' -Severity WARNING -AffectedRecord $gid -OrderName $name -Classification $classification -ExpectedValue $subtotal -ActualValue $sumNet -Difference (Get-RoundedMoney ($sumNet - $subtotal)) -RecommendedAction 'Order subtotal differs from the sum of line amounts (check order-level or shipping discounts / order edits).' -RunId $RunId))
        }
        $sumDisc = Get-SumOf -Items @($lines.Values) -Property 'LineDiscount'
        if (-not (Test-MoneyEqual $sumDisc $orderDiscounts)) {
            $ex.Add((New-PassressException -CheckName 'ORDER_DISCOUNT_VS_LINES' -Severity WARNING -AffectedRecord $gid -OrderName $name -Classification $classification -ExpectedValue $orderDiscounts -ActualValue $sumDisc -Difference (Get-RoundedMoney ($sumDisc - $orderDiscounts)) -RecommendedAction 'Order discount total differs from line discount allocations (shipping discounts are not line-level).' -RunId $RunId))
        }

        # ---------------- transactions (order level)
        $refundTxIds = @{}
        foreach ($rf in @(Get-JsonValue $o 'refunds')) { if ($null -eq $rf) { continue }; foreach ($rt in (Get-ConnectionNodes (Get-JsonValue $rf 'transactions'))) { $refundTxIds[[string](Get-JsonValue $rt 'id')] = [string](Get-JsonValue $rf 'id') } }
        $orderTx = @(Get-JsonValue $o 'transactions' | Where-Object { $null -ne $_ })   # plain list in the API (not a connection)
        if ($orderTx.Count -ge [int](Get-PassressConfigValue $Config 'MaxTransactionsPerOrder' 250)) {
            $ex.Add((New-PassressException -CheckName 'TRANSACTIONS_POSSIBLY_TRUNCATED' -Severity ERROR -AffectedRecord $gid -OrderName $name -Classification $classification -ActualValue $orderTx.Count -RecommendedAction 'Order has as many transactions as the fetch limit; raise MaxTransactionsPerOrder in config.' -RunId $RunId))
        }
        foreach ($tx in $orderTx) {
            $txid = [string](Get-JsonValue $tx 'id'); if (-not $txid -or $seenTx.ContainsKey($txid)) { continue }; $seenTx[$txid] = $true
            $kind = ([string](Get-JsonValue $tx 'kind')).ToUpperInvariant(); $status = ([string](Get-JsonValue $tx 'status')).ToUpperInvariant()
            $pAt = Get-JsonValue $tx 'processedAt'; $pDate = if (Test-Blank $pAt) { $null } else { ConvertTo-ShopLocalDate -UtcValue $pAt -TimeZone $tz }
            $T.ORDER_TRANSACTIONS.Add([ordered]@{
                TransactionGID = $txid; OrderGID = $gid; OrderName = $name; RefundGID = (Get-MapValue $refundTxIds $txid $null)
                Kind = $kind; Status = $status; Gateway = (Get-JsonValue $tx 'gateway'); ProcessedAtUtc = $pAt; ProcessedDateLocal = $pDate
                Amount = (Get-MoneyValue $tx 'amountSet')
                IsSuccessfulCollection = (($kind -eq 'SALE' -or $kind -eq 'CAPTURE') -and $status -eq 'SUCCESS')
                IsSuccessfulRefund = ($kind -eq 'REFUND' -and $status -eq 'SUCCESS')
            })
        }

        # ---------------- refunds
        $moneyQty = @{}; $moneyAmt = @{}; $moneyTax = @{}; $zeroQty = @{}; $cancelUnshipped = @{}; $cancelZero = @{}; $orderRefundEventsTotal = 0.0
        $refunds = @(Get-JsonValue $o 'refunds' | Where-Object { $null -ne $_ })
        if ($refunds.Count -ge [int](Get-PassressConfigValue $Config 'MaxRefundsPerOrder' 250)) {
            $ex.Add((New-PassressException -CheckName 'REFUNDS_POSSIBLY_TRUNCATED' -Severity ERROR -AffectedRecord $gid -OrderName $name -Classification $classification -ActualValue $refunds.Count -RecommendedAction 'Order has as many refunds as the fetch limit; raise MaxRefundsPerOrder in config.' -RunId $RunId))
        }
        foreach ($rf in $refunds) {
            $rgid = [string](Get-JsonValue $rf 'id')
            if (-not $rgid) { continue }
            if ($seenRefunds.ContainsKey($rgid)) { $ex.Add((New-PassressException -CheckName 'DUPLICATE_REFUND' -Severity ERROR -AffectedRecord $rgid -OrderName $name -Classification $classification -RecommendedAction 'Duplicate refund ignored (refunds are processed once per id).' -RunId $RunId)); continue }
            $seenRefunds[$rgid] = $true

            $rTx = Get-ConnectionNodes (Get-JsonValue $rf 'transactions')
            $successTotal = 0.0; $nonSuccess = 0; $latestSuccess = $null
            foreach ($tx in $rTx) {
                $kind = ([string](Get-JsonValue $tx 'kind')).ToUpperInvariant(); $status = ([string](Get-JsonValue $tx 'status')).ToUpperInvariant()
                $pAt = Get-JsonValue $tx 'processedAt'; $pDate = if (Test-Blank $pAt) { $null } else { ConvertTo-ShopLocalDate -UtcValue $pAt -TimeZone $tz }
                $isOk = ($kind -eq 'REFUND' -and $status -eq 'SUCCESS'); $amt = Get-MoneyValue $tx 'amountSet'
                if ($isOk) { $successTotal += $amt; if ($null -ne $pDate -and ($null -eq $latestSuccess -or $pDate -gt $latestSuccess)) { $latestSuccess = $pDate } } elseif ($kind -eq 'REFUND') { $nonSuccess++ }
                $T.REFUND_TRANSACTIONS.Add([ordered]@{ TransactionGID = [string](Get-JsonValue $tx 'id'); RefundGID = $rgid; OrderGID = $gid; Kind = $kind; Status = $status; Gateway = (Get-JsonValue $tx 'gateway'); ProcessedAtUtc = $pAt; ProcessedDateLocal = $pDate; Amount = $amt; IsSuccessfulRefund = $isOk })
            }
            $successTotal = Get-RoundedMoney $successTotal
            $refCreated = Get-JsonValue $rf 'createdAt'
            if ($successTotal -gt 0 -and $null -eq $latestSuccess -and -not (Test-Blank $refCreated)) { $latestSuccess = ConvertTo-ShopLocalDate -UtcValue $refCreated -TimeZone $tz }
            $recMonth = Get-MonthKey $latestSuccess
            $reported = Get-MoneyValue $rf 'totalRefundedSet'

            $rlConn = Get-JsonValue $rf 'refundLineItems'
            if (ConvertTo-PassressBool (Get-JsonValue $rlConn 'pageInfo.hasNextPage')) {
                $ex.Add((New-PassressException -CheckName 'REFUND_LINE_ITEMS_TRUNCATED' -Severity ERROR -AffectedRecord $rgid -OrderName $name -Classification $classification -RecommendedAction 'Not all refund line items were fetched. Re-run the refresh.' -RunId $RunId))
            }
            $rLines = Get-ConnectionNodes $rlConn
            $lineAllocTotal = 0.0; $refQty = 0
            foreach ($rl in $rLines) {
                $origLine = [string](Get-JsonValue $rl 'lineItem.id'); $q = [int](Get-Money (Get-JsonValue $rl 'quantity'))
                $sub = Get-MoneyValue $rl 'subtotalSet'; $tx2 = Get-MoneyValue $rl 'totalTaxSet'; $restock = ([string](Get-JsonValue $rl 'restockType')).ToUpperInvariant()
                $lineAllocTotal += ($sub + $tx2); $refQty += $q
                $skuOrig = if ($lines.ContainsKey($origLine)) { $lines[$origLine].SKU } else { [string](Get-JsonValue $rl 'lineItem.sku') }
                $T.REFUND_LINE_ITEMS.Add([ordered]@{ RefundLineItemGID = [string](Get-JsonValue $rl 'id'); RefundGID = $rgid; OrderGID = $gid; LineItemGID = $origLine; SKU = $skuOrig; Quantity = $q; Subtotal = $sub; Tax = $tx2; Total = (Get-RoundedMoney ($sub + $tx2)); RestockType = $restock; Restocked = (ConvertTo-PassressBool (Get-JsonValue $rl 'restocked')); LocationName = (Get-JsonValue $rl 'location.name') })
                if (-not $lines.ContainsKey($origLine)) {
                    $ex.Add((New-PassressException -CheckName 'REFUND_LINE_NOT_LINKED' -Severity ERROR -AffectedRecord ([string](Get-JsonValue $rl 'id')) -OrderName $name -Classification $classification -ActualValue $origLine -RecommendedAction 'Refund line item does not match any original line item of the order.' -RunId $RunId))
                    continue
                }
                # restockType CANCEL = item removed before it shipped -> never costed, whether or not money moved
                if ($restock -eq 'CANCEL') { Add-ToMap $cancelUnshipped $origLine $q }
                if ($successTotal -gt 0) {
                    Add-ToMap $moneyQty $origLine $q; Add-ToMap $moneyAmt $origLine $sub; Add-ToMap $moneyTax $origLine $tx2
                } else {
                    Add-ToMap $zeroQty $origLine $q
                    if ($restock -eq 'CANCEL') { Add-ToMap $cancelZero $origLine $q }
                }
            }
            $lineAllocTotal = Get-RoundedMoney $lineAllocTotal
            $shipRefund = 0.0; foreach ($sl in (Get-ConnectionNodes (Get-JsonValue $rf 'refundShippingLines'))) { $shipRefund += (Get-MoneyValue $sl 'subtotalAmountSet') }
            $adjust = 0.0; foreach ($aj in (Get-ConnectionNodes (Get-JsonValue $rf 'orderAdjustments'))) { $adjust += (Get-MoneyValue $aj 'amountSet') }
            $shipRefund = Get-RoundedMoney $shipRefund; $adjust = Get-RoundedMoney $adjust

            $status = ''; $unalloc = 0.0
            if ($successTotal -eq 0) {
                $status = if ($rLines.Count -gt 0) { 'QUANTITY_ONLY' } else { 'NO_MONEY' }
                if ($reported -gt 0) { $ex.Add((New-PassressException -CheckName 'REFUND_REPORTED_WITHOUT_SUCCESSFUL_TRANSACTION' -Severity WARNING -AffectedRecord $rgid -OrderName $name -Classification $classification -ExpectedValue 0 -ActualValue $reported -Difference $reported -RecommendedAction 'Shopify reports a refunded amount but no SUCCESS refund transaction exists; nothing is recognised until a transaction succeeds.' -RunId $RunId)) }
            } else {
                $allocated = Get-RoundedMoney ($lineAllocTotal + $shipRefund + $adjust)
                $unalloc = Get-RoundedMoney ($successTotal - $allocated)
                if (Test-MoneyEqual $unalloc 0) { $status = 'ALLOCATED'; $unalloc = 0.0 }
                elseif ($rLines.Count -eq 0 -and $shipRefund -eq 0 -and $adjust -eq 0) {
                    $status = 'UNALLOCATED'
                    $ex.Add((New-PassressException -CheckName 'REFUND_WITHOUT_LINE_ITEM' -Severity $sev -AffectedRecord $rgid -OrderName $name -Classification $classification -ExpectedValue 'Refund line items linked to original line items' -ActualValue 'none' -Difference $successTotal -RecommendedAction 'Money was refunded without selecting products. Kept as an UNALLOCATED order-level refund (never assigned to a product by matching amounts). Record the evidence; no automatic allocation.' -RunId $RunId))
                    $ex.Add((New-PassressException -CheckName 'UNALLOCATED_REFUND' -Severity $sev -AffectedRecord $rgid -OrderName $name -Classification $classification -ExpectedValue 0 -ActualValue $unalloc -Difference $unalloc -RecommendedAction 'Unallocated refund reduces order revenue but cannot be attributed to a product.' -RunId $RunId))
                } else {
                    $status = 'MISMATCH'
                    $ex.Add((New-PassressException -CheckName 'REFUND_AMOUNT_MISMATCH' -Severity $sev -AffectedRecord $rgid -OrderName $name -Classification $classification -ExpectedValue $successTotal -ActualValue $allocated -Difference $unalloc -RecommendedAction 'Successful refund transactions differ from Shopify line/shipping/adjustment allocations. The difference is kept UNALLOCATED.' -RunId $RunId))
                }
                if (-not (Test-MoneyEqual $reported $successTotal)) {
                    $ex.Add((New-PassressException -CheckName 'REFUND_TOTAL_VS_TRANSACTIONS' -Severity WARNING -AffectedRecord $rgid -OrderName $name -Classification $classification -ExpectedValue $successTotal -ActualValue $reported -Difference (Get-RoundedMoney ($reported - $successTotal)) -RecommendedAction 'Shopify refund total differs from successful transactions (pending/failed transaction?). Only successful money is recognised.' -RunId $RunId))
                }
                # revenue events, recognised in the month the successful refund transaction occurred
                foreach ($rl in $rLines) {
                    $origLine = [string](Get-JsonValue $rl 'lineItem.id'); if (-not $lines.ContainsKey($origLine)) { continue }
                    $q = [int](Get-Money (Get-JsonValue $rl 'quantity')); $sub = Get-MoneyValue $rl 'subtotalSet'; $tx2 = Get-MoneyValue $rl 'totalTaxSet'
                    $T.REVENUE_EVENTS.Add([ordered]@{ EventID = 'REV-RL-' + [string](Get-JsonValue $rl 'id'); EventType = 'REFUND_LINE'; OrderGID = $gid; OrderName = $name; LineItemGID = $origLine; RefundGID = $rgid; SKU = $lines[$origLine].SKU; EventDateLocal = $latestSuccess; EventMonth = $recMonth; Quantity = (-1 * $q); GrossAmount = 0; DiscountAmount = 0; TaxAmount = (-1 * $tx2); NetAmount = (-1 * $sub); Classification = $classification; IsReportable = $reportable })
                }
                if ($shipRefund -ne 0) { $T.REVENUE_EVENTS.Add([ordered]@{ EventID = 'REV-RS-' + $rgid; EventType = 'REFUND_SHIPPING'; OrderGID = $gid; OrderName = $name; LineItemGID = $null; RefundGID = $rgid; SKU = $null; EventDateLocal = $latestSuccess; EventMonth = $recMonth; Quantity = 0; GrossAmount = 0; DiscountAmount = 0; TaxAmount = 0; NetAmount = (-1 * $shipRefund); Classification = $classification; IsReportable = $reportable }) }
                if ($adjust -ne 0) { $T.REVENUE_EVENTS.Add([ordered]@{ EventID = 'REV-RA-' + $rgid; EventType = 'REFUND_ADJUSTMENT'; OrderGID = $gid; OrderName = $name; LineItemGID = $null; RefundGID = $rgid; SKU = $null; EventDateLocal = $latestSuccess; EventMonth = $recMonth; Quantity = 0; GrossAmount = 0; DiscountAmount = 0; TaxAmount = 0; NetAmount = (-1 * $adjust); Classification = $classification; IsReportable = $reportable }) }
                if ($unalloc -ne 0) { $T.REVENUE_EVENTS.Add([ordered]@{ EventID = 'REV-RU-' + $rgid; EventType = 'REFUND_UNALLOCATED'; OrderGID = $gid; OrderName = $name; LineItemGID = $null; RefundGID = $rgid; SKU = $null; EventDateLocal = $latestSuccess; EventMonth = $recMonth; Quantity = 0; GrossAmount = 0; DiscountAmount = 0; TaxAmount = 0; NetAmount = (-1 * $unalloc); Classification = $classification; IsReportable = $reportable }) }
                $orderRefundEventsTotal += $successTotal
            }
            if ($nonSuccess -gt 0) { $ex.Add((New-PassressException -CheckName 'REFUND_TRANSACTION_NOT_SUCCESSFUL' -Severity WARNING -AffectedRecord $rgid -OrderName $name -Classification $classification -ActualValue $nonSuccess -RecommendedAction 'One or more refund transactions are pending/failed; they are logged but not recognised.' -RunId $RunId)) }

            $T.RAW_REFUNDS.Add([ordered]@{ RefundGID = $rgid; OrderGID = $gid; OrderName = $name; RefundCreatedAtUtc = $refCreated; Note = (Get-JsonValue $rf 'note'); TotalRefundedReported = $reported; SuccessfulTransactionTotal = $successTotal; NonSuccessfulTransactionCount = $nonSuccess; RecognitionDateLocal = $latestSuccess; RecognitionMonth = $recMonth; Currency = $currency })
            $T.REFUND_RECONCILIATION.Add([ordered]@{ RefundGID = $rgid; OrderGID = $gid; OrderName = $name; Classification = $classification; RecognitionMonth = $recMonth; SuccessfulTransactionTotal = $successTotal; TotalRefundedReported = $reported; LineAllocatedTotal = $lineAllocTotal; ShippingRefund = $shipRefund; Adjustments = $adjust; Unallocated = $unalloc; RefundedQuantity = $refQty; Status = $status })
        }

        # ---------------- sales fact + sale / cancellation events
        $orderMonth = Get-MonthKey $orderDate
        foreach ($lgid in $lineOrder) {
            $l = $lines[$lgid]
            $qOrd = [int]$l.Quantity
            $qMoney = [int](Get-MapValue $moneyQty $lgid 0); $refAmt = Get-RoundedMoney (Get-MapValue $moneyAmt $lgid 0)
            $qZero = [int](Get-MapValue $zeroQty $lgid 0); $qCancelUnship = [int](Get-MapValue $cancelUnshipped $lgid 0)
            # Revenue cancellation = no-money quantity reversal (all no-money lines on a cancelled order, CANCEL lines otherwise)
            $qCancelled = if ($isCancelled) { $qZero } else { [int](Get-MapValue $cancelZero $lgid 0) }
            if (($qMoney + $qCancelled) -gt $qOrd -or $qCancelUnship -gt $qOrd) {
                $ex.Add((New-PassressException -CheckName 'LINE_REFUND_QTY_MISMATCH' -Severity $sev -AffectedRecord $lgid -OrderName $name -Classification $classification -ExpectedValue ('<= ' + $qOrd) -ActualValue ($qMoney + $qCancelled) -Difference ($qMoney + $qCancelled - $qOrd) -RecommendedAction 'Refunded + cancelled quantity exceeds the ordered quantity. Investigate in Shopify.' -RunId $RunId))
                if ($qCancelUnship -gt $qOrd) { $qCancelUnship = $qOrd }
            }
            $netSales = [double]$l.NetLineAmount
            $unitNet = if ($qOrd -gt 0) { $netSales / $qOrd } else { 0 }
            $cancelRev = Get-RoundedMoney ([math]::Max(0, [math]::Min($qCancelled * $unitNet, $netSales - $refAmt)))
            $netRev = Get-RoundedMoney ($netSales - $refAmt - $cancelRev)
            $qShipped = $qOrd - $qCancelUnship
            $T.SALES_FACT.Add([ordered]@{
                LineItemGID = $lgid; OrderGID = $gid; OrderName = $name; CustomerGID = $customerGid; OrderDateLocal = $orderDate; OrderMonth = $orderMonth
                SKU = $l.SKU; VariantGID = $l.VariantGID; ProductTitle = $l.ProductTitle; VariantTitle = $l.VariantTitle
                Classification = $classification; ClassificationSource = $cls.Source; IsReportable = $reportable; OrderCancelled = $isCancelled
                QtyOrdered = $qOrd; QtyCancelled = $qCancelled; QtyCancelledUnshipped = $qCancelUnship; QtyShipped = $qShipped; QtyRefunded = $qMoney
                UnitPrice = $l.UnitPrice; GrossSales = $l.GrossLineAmount; LineDiscount = $l.LineDiscount; NetSales = $netSales
                RefundAllocated = $refAmt; CancellationReversal = $cancelRev; NetRevenue = $netRev
                FinancialStatus = $finStatus; FulfillmentStatus = $fulStatus; MissingSKU = (Test-Blank $l.SKU)
            })
            if ($null -ne $orderDate) {
                $T.REVENUE_EVENTS.Add([ordered]@{ EventID = 'REV-S-' + $lgid; EventType = 'SALE'; OrderGID = $gid; OrderName = $name; LineItemGID = $lgid; RefundGID = $null; SKU = $l.SKU; EventDateLocal = $orderDate; EventMonth = $orderMonth; Quantity = $qOrd; GrossAmount = $l.GrossLineAmount; DiscountAmount = $l.LineDiscount; TaxAmount = $l.LineTax; NetAmount = $netSales; Classification = $classification; IsReportable = $reportable })
            }
            if ($cancelRev -gt 0) {
                $cancelTax = if ($qOrd -gt 0) { Get-RoundedMoney ([double]$l.LineTax * $qCancelled / $qOrd) } else { 0 }
                $evDate = if ($null -ne $cancelDate) { $cancelDate } else { $orderDate }
                $T.REVENUE_EVENTS.Add([ordered]@{ EventID = 'REV-C-' + $lgid; EventType = 'CANCELLATION'; OrderGID = $gid; OrderName = $name; LineItemGID = $lgid; RefundGID = $null; SKU = $l.SKU; EventDateLocal = $evDate; EventMonth = (Get-MonthKey $evDate); Quantity = (-1 * $qCancelled); GrossAmount = 0; DiscountAmount = 0; TaxAmount = (-1 * $cancelTax); NetAmount = (-1 * $cancelRev); Classification = $classification; IsReportable = $reportable })
            }
        }
        if ($shipping -gt 0 -and $null -ne $orderDate) {
            $T.REVENUE_EVENTS.Add([ordered]@{ EventID = 'REV-SS-' + $gid; EventType = 'SALE_SHIPPING'; OrderGID = $gid; OrderName = $name; LineItemGID = $null; RefundGID = $null; SKU = $null; EventDateLocal = $orderDate; EventMonth = $orderMonth; Quantity = 0; GrossAmount = 0; DiscountAmount = 0; TaxAmount = 0; NetAmount = $shipping; Classification = $classification; IsReportable = $reportable })
        }
        if ($isCancelled) {
            # Money kept on a cancelled order must equal what the revenue ledger leaves; never auto-adjust.
            $orderEvents = @($T.REVENUE_EVENTS | Where-Object { $_.OrderGID -eq $gid })
            $ledgerNet = 0.0; foreach ($ev in $orderEvents) { $ledgerNet += [double]$ev.NetAmount + [double]$ev.TaxAmount }
            $kept = Get-RoundedMoney ($received - $orderRefundEventsTotal)
            if (-not (Test-MoneyEqual $ledgerNet $kept)) {
                $ex.Add((New-PassressException -CheckName 'CANCELLED_ORDER_RESIDUAL' -Severity $sev -AffectedRecord $gid -OrderName $name -Classification $classification -ExpectedValue $kept -ActualValue (Get-RoundedMoney $ledgerNet) -Difference (Get-RoundedMoney ($ledgerNet - $kept)) -RecommendedAction 'Cancelled order still carries revenue that does not match money kept (e.g. cancellation without refund line items, or unrefunded shipping). Not adjusted automatically.' -RunId $RunId))
            }
        }
    }

    foreach ($k in @($resolved.ByGid.Keys) + @($resolved.ByName.Keys)) {
        if (-not $matchedClassKeys.ContainsKey($k)) { $ex.Add((New-PassressException -CheckName 'CLASSIFICATION_ORDER_NOT_FOUND' -Severity WARNING -AffectedRecord $k -RecommendedAction 'ORDER_CLASSIFICATION row matches no extracted order (typo, or order outside the extraction window).' -RunId $RunId)) }
    }

    # ---------------- customers / products / variants
    foreach ($c in @($CustomerNodes)) {
        if ($null -eq $c) { continue }
        $email = Get-JsonValue $c 'defaultEmailAddress.emailAddress'; if (Test-Blank $email) { $email = Get-JsonValue $c 'email' }
        $phone = Get-JsonValue $c 'defaultPhoneNumber.phoneNumber'; if (Test-Blank $phone) { $phone = Get-JsonValue $c 'phone' }
        $T.RAW_CUSTOMERS.Add([ordered]@{ CustomerGID = [string](Get-JsonValue $c 'id'); DisplayName = (Get-JsonValue $c 'displayName'); Email = $email; Phone = $phone; CreatedAtUtc = (Get-JsonValue $c 'createdAt'); NumberOfOrders = (Get-JsonValue $c 'numberOfOrders'); AmountSpent = (Get-MoneyValue2 $c 'amountSpent'); City = (Get-JsonValue $c 'defaultAddress.city'); Province = (Get-JsonValue $c 'defaultAddress.province'); Country = (Get-JsonValue $c 'defaultAddress.country'); MarketingConsent = (Get-JsonValue $c 'defaultEmailAddress.marketingState') })
    }
    $seenProducts = @{}
    foreach ($v in @($VariantNodes)) {
        if ($null -eq $v) { continue }
        $pg = [string](Get-JsonValue $v 'product.id')
        if ($pg -and -not $seenProducts.ContainsKey($pg)) {
            $seenProducts[$pg] = $true
            $T.RAW_PRODUCTS.Add([ordered]@{ ProductGID = $pg; ProductTitle = (Get-JsonValue $v 'product.title'); ProductType = (Get-JsonValue $v 'product.productType'); Vendor = (Get-JsonValue $v 'product.vendor'); Status = (Get-JsonValue $v 'product.status') })
        }
        $opts = @(Get-JsonValue $v 'selectedOptions') | Where-Object { $null -ne $_ } | ForEach-Object { '{0}={1}' -f (Get-JsonValue $_ 'name'), (Get-JsonValue $_ 'value') }
        $uc = Get-JsonValue $v 'inventoryItem.unitCost.amount'
        $T.RAW_VARIANTS.Add([ordered]@{ VariantGID = [string](Get-JsonValue $v 'id'); ProductGID = $pg; SKU = (Get-JsonValue $v 'sku'); ProductTitle = (Get-JsonValue $v 'product.title'); VariantTitle = (Get-JsonValue $v 'title'); OptionValues = (@($opts) -join '; '); Price = (Get-Money (Get-JsonValue $v 'price')); ShopifyUnitCost = $(if (Test-Blank $uc) { $null } else { Get-Money $uc }); ShopifyInventoryQty = (Get-JsonValue $v 'inventoryQuantity') })
    }

    $tables = @{}; foreach ($k in $T.Keys) { $tables[$k] = $T[$k].ToArray() }
    return [pscustomobject]@{ Tables = $tables; Exceptions = (Get-UniqueExceptions $ex.ToArray()) }
}

function Get-MoneyValue2 { param($Object, [string]$Path) $v = Get-JsonValue $Object ($Path + '.amount'); if (Test-Blank $v) { return $null } return (Get-Money $v) }
