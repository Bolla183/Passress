# Test helpers for the PASSRESS offline test suite (dot-sourced by scripts\Invoke-PassressOfflineTests.ps1).

function New-TestConfig {
    param([string]$Root = (Join-Path ([System.IO.Path]::GetTempPath()) 'passress_test_root'))
    return [pscustomobject]@{
        RootFolder = $Root; ShopDomain = 'example.myshopify.com'; ApiVersion = '2026-07'; Currency = 'EGP'
        TimeZoneWindows = 'Egypt Standard Time'; TimeZoneIana = 'Africa/Cairo'; FinancialYearStartMonth = 1; HistoryStartDate = ''
        TestOrderTag = 'TEST'; MaxRefundsPerOrder = 250; MaxTransactionsPerOrder = 250; CogsRecognitionTrigger = 'DELIVERY'
    }
}

function M { param([double]$a) return @{ shopMoney = @{ amount = $a.ToString([System.Globalization.CultureInfo]::InvariantCulture) } } }
function LG { param($OrderId, [string]$Line) return ('gid://shopify/LineItem/{0}-{1}' -f $OrderId, $Line) }
function OG { param($OrderId) return ('gid://shopify/Order/{0}' -f $OrderId) }
function RG { param($OrderId, [string]$Refund) return ('gid://shopify/Refund/{0}-{1}' -f $OrderId, $Refund) }

function New-TOrder {
    <# Builds an order node shaped exactly like the Shopify Admin GraphQL response used by the extractor.
       Lines:   @{ Id='L1'; Sku='SKU-A'; Qty=1; Price=2500; Title='..'; Variant='..'; Discount=0; Tax=0 }
       Refunds: @{ Id='R1'; At='2026-10-10T10:00:00Z'; Amount=2500; Status='SUCCESS'; Lines=@(@{ Id='RL1'; Line='L1'; Qty=1; Subtotal=2500; Tax=0; Restock='RETURN' }); Shipping=0; Adjust=0 } #>
    param([Parameter(Mandatory)]$Id, [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Created, [object[]]$Lines,
          [double]$Received = 0, [object[]]$Refunds = @(), [string]$Cancelled = $null, [bool]$ShopifyTest = $false, [string[]]$Tags = @(),
          [double]$Shipping = 0, [string]$Customer = 'gid://shopify/Customer/T1',
          [string]$Fulfilled = '', [string]$Delivered = '', [switch]$NotFulfilled, [switch]$NotDelivered, [switch]$FulfillmentTwice)
    $lineNodes = @(); $sub = 0.0; $disc = 0.0; $tax = 0.0
    foreach ($l in $Lines) {
        $d = if ($l.ContainsKey('Discount')) { [double]$l.Discount } else { 0 }; $t = if ($l.ContainsKey('Tax')) { [double]$l.Tax } else { 0 }
        $sub += [double]$l.Qty * [double]$l.Price - $d; $disc += $d; $tax += $t
        $lineNodes += @{ id = (LG $Id $l.Id); sku = $l.Sku; name = [string]$l.Title; title = $(if ($l.Title) { $l.Title } else { 'Test product' }); variantTitle = $l.Variant
            quantity = [int]$l.Qty; currentQuantity = [int]$l.Qty; product = @{ id = 'gid://shopify/Product/T' }; variant = @{ id = ('gid://shopify/ProductVariant/' + $l.Sku) }
            originalUnitPriceSet = (M $l.Price); discountAllocations = @(@{ allocatedAmountSet = (M $d) }); taxLines = @(@{ priceSet = (M $t) }) }
    }
    $txs = @(); if ($Received -gt 0) { $txs += @{ id = ('gid://shopify/OrderTransaction/{0}-S' -f $Id); kind = 'SALE'; status = 'SUCCESS'; gateway = 'Cash on Delivery (COD)'; processedAt = $Created; amountSet = (M $Received) } }
    $refundNodes = @(); $refunded = 0.0
    foreach ($r in $Refunds) {
        $rl = @(); foreach ($x in @($r.Lines)) { if ($null -eq $x) { continue }; $rl += @{ id = ('gid://shopify/RefundLineItem/{0}-{1}' -f $Id, $x.Id); quantity = [int]$x.Qty; restockType = $x.Restock; restocked = ($x.Restock -ne 'NO_RESTOCK'); location = @{ id = 'gid://shopify/Location/1'; name = 'Passress' }; subtotalSet = (M $x.Subtotal); totalTaxSet = (M $(if ($x.ContainsKey('Tax')) { $x.Tax } else { 0 })); lineItem = @{ id = (LG $Id $x.Line); sku = $null } } }
        $status = if ($r.ContainsKey('Status')) { $r.Status } else { 'SUCCESS' }
        $rtx = @(); if ([double]$r.Amount -gt 0) { $rtx += @{ id = ('gid://shopify/OrderTransaction/{0}-{1}' -f $Id, $r.Id); kind = 'REFUND'; status = $status; gateway = 'Cash on Delivery (COD)'; processedAt = $r.At; amountSet = (M $r.Amount) } }
        if ($status -eq 'SUCCESS') { $refunded += [double]$r.Amount }
        $ship = @(); if ($r.ContainsKey('Shipping') -and [double]$r.Shipping -ne 0) { $ship += @{ subtotalAmountSet = (M $r.Shipping) } }
        $adj = @(); if ($r.ContainsKey('Adjust') -and [double]$r.Adjust -ne 0) { $adj += @{ id = 'gid://shopify/OrderAdjustment/1'; reason = 'REFUND_DISCREPANCY'; amountSet = (M $r.Adjust) } }
        $refundNodes += @{ id = (RG $Id $r.Id); createdAt = $r.At; processedAt = $r.At; note = $null; totalRefundedSet = (M $r.Amount)
            refundLineItems = @{ pageInfo = @{ hasNextPage = $false; endCursor = $null }; nodes = $rl }; refundShippingLines = @{ nodes = $ship }; orderAdjustments = @{ nodes = $adj }; transactions = @{ nodes = $rtx } }
        $txs += $rtx
    }
    # Default: one SUCCESS fulfillment of every line on the order date, delivered the same day (so COGS is recognised at the
    # order date under the DELIVERY trigger). -NotDelivered / -NotFulfilled / -FulfillmentTwice drive the recognition tests.
    $ful = @()
    if (-not $NotFulfilled) {
        $fAt = if ($Fulfilled) { $Fulfilled } else { $Created }; $dAt = if ($NotDelivered) { $null } elseif ($Delivered) { $Delivered } else { $Created }
        $fli = @(); foreach ($l in $Lines) { $fli += @{ quantity = [int]$l.Qty; lineItem = @{ id = (LG $Id $l.Id) } } }
        $one = @{ id = ('gid://shopify/Fulfillment/{0}-F1' -f $Id); status = 'SUCCESS'; displayStatus = $(if ($dAt) { 'DELIVERED' } else { 'FULFILLED' }); createdAt = $fAt; deliveredAt = $dAt; fulfillmentLineItems = @{ pageInfo = @{ hasNextPage = $false; endCursor = $null }; nodes = $fli } }
        $ful += $one; if ($FulfillmentTwice) { $ful += $one }
    }
    $node = @{ id = (OG $Id); name = $Name; fulfillments = $ful; createdAt = $Created; processedAt = $Created; updatedAt = $Created; cancelledAt = $(if ($Cancelled) { $Cancelled } else { $null }); cancelReason = $(if ($Cancelled) { 'CUSTOMER' } else { $null })
        test = $ShopifyTest; displayFinancialStatus = 'PAID'; displayFulfillmentStatus = 'FULFILLED'; currencyCode = 'EGP'; tags = $Tags; sourceName = 'web'; customer = @{ id = $Customer }
        subtotalPriceSet = (M $sub); totalDiscountsSet = (M $disc); totalShippingPriceSet = (M $Shipping); totalTaxSet = (M $tax); totalPriceSet = (M ($sub + $tax + $Shipping))
        totalReceivedSet = (M $Received); totalRefundedSet = (M $refunded); netPaymentSet = (M ($Received - $refunded))
        lineItems = @{ pageInfo = @{ hasNextPage = $false; endCursor = $null }; nodes = $lineNodes }; transactions = $txs; refunds = $refundNodes }
    # JSON round trip so the engine sees exactly what ConvertFrom-Json produces from a real API response
    return ($node | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
}

function New-BaseInputs {
    param([switch]$NoOpening, [switch]$NoGL)
    $i = @{
        COST_MASTER = @(@{ CostRecordID = 'C-A1'; SKU = 'SKU-A'; UnitCost = 1000; Currency = 'EGP'; EffectiveFrom = [datetime]'2026-01-01'; ApprovedBy = 'Finance'; Source = 'test' })
        OPENING_INVENTORY = @(); OPENING_BALANCES = @(); DATA_ENTRY = @(); RETURNS = @(); RETURN_INSPECTIONS = @()
    }
    if (-not $NoOpening) { $i.OPENING_INVENTORY = @(@{ SKU = 'SKU-A'; AsOfDate = [datetime]'2026-09-01'; SellableQty = 5; DamagedQty = 0; UnitCost = 1000; CountedBy = 'test' }) }
    if (-not $NoGL) { $i.OPENING_BALANCES = @(
        @{ AccountCode = '1010'; AsOfDate = [datetime]'2026-09-01'; Debit = 5000; Credit = 0; Source = 'test' },
        @{ AccountCode = '1300'; AsOfDate = [datetime]'2026-09-01'; Debit = 5000; Credit = 0; Source = 'test' },
        @{ AccountCode = '3000'; AsOfDate = [datetime]'2026-09-01'; Debit = 0; Credit = 10000; Counterparty = 'Partners'; Source = 'test' }) }
    return $i
}

function A { param([string]$Id, [string]$Desc, [string]$Table, [hashtable]$Where = @{}, [string]$Agg = 'count', [string]$Column, $Expected, [double]$Tol = 0.005)
    return @{ Type = 'match'; Id = $Id; Desc = $Desc; Table = $Table; Where = $Where; Agg = $Agg; Column = $Column; Expected = $Expected; Tol = $Tol } }
function ASum { param([string]$Id, [string]$Desc, [string]$Table, [string]$ColumnA, [string]$ColumnB) return @{ Type = 'equalSums'; Id = $Id; Desc = $Desc; Table = $Table; ColumnA = $ColumnA; ColumnB = $ColumnB } }

# -------------------------------------------------------------------------------------------- runner
function ConvertTo-RoundTrip {
    param([string]$Stage, [string]$Table, [object[]]$Rows, [string]$Dir)
    $null = Export-PassressTable -Workbook $Stage -Table $Table -Rows @($Rows | Where-Object { $null -ne $_ }) -Directory $Dir
    $back = Import-PassressTable -Workbook $Stage -Table $Table -Directory $Dir
    return , $back
}

function Invoke-TestPipeline {
    param([Parameter(Mandatory)][hashtable]$Scenario, [Parameter(Mandatory)]$Config, [Parameter(Mandatory)][string]$TempDir, [string]$RunId = 'RUN-TEST')
    $all = @{}; $sch = Get-PassressSchema
    if ($Scenario.ContainsKey('Config')) { $c2 = $Config.PSObject.Copy(); foreach ($k in $Scenario.Config.Keys) { $c2 | Add-Member -NotePropertyName $k -NotePropertyValue $Scenario.Config[$k] -Force }; $Config = $c2 }
    $inputsFor = {
        param($stage)
        $h = @{}
        foreach ($t in @($sch.workbooks.$stage.tables | Where-Object { $_.kind -eq 'input' })) {
            $rows = if ($Scenario.Inputs.ContainsKey($t.name)) { @($Scenario.Inputs[$t.name]) } else { @() }
            $h[$t.name] = ConvertTo-RoundTrip $stage $t.name $rows (Join-Path $TempDir "$stage\in")
        }
        return $h
    }
    $in1 = & $inputsFor '01_DATA_SOURCE'
    $s1 = Invoke-PassressDataSourceStage -OrderNodes @($Scenario.Orders) -CustomerNodes @() -VariantNodes @() -ClassificationRows $in1.ORDER_CLASSIFICATION -Config $Config -RunId $RunId
    foreach ($k in $s1.Tables.Keys) { $all[$k] = ConvertTo-RoundTrip '01_DATA_SOURCE' $k $s1.Tables[$k] (Join-Path $TempDir '01') }
    $all['EXCEPTIONS'] = ConvertTo-RoundTrip '01_DATA_SOURCE' 'EXCEPTIONS' $s1.Exceptions (Join-Path $TempDir '01')

    $in2 = & $inputsFor '02_OPERATIONS'
    $prev = if ($Scenario.ContainsKey('PreviousCostState')) { [pscustomobject]$Scenario.PreviousCostState } else { $null }
    $s2 = Invoke-PassressOperationsStage -Upstream @{ SALES_FACT = $all.SALES_FACT; REVENUE_EVENTS = $all.REVENUE_EVENTS; RAW_CUSTOMERS = $all.RAW_CUSTOMERS; RAW_VARIANTS = $all.RAW_VARIANTS; REFUND_RECONCILIATION = $all.REFUND_RECONCILIATION; FULFILLMENT_EVENTS = $all.FULFILLMENT_EVENTS; ORDER_TRANSACTIONS = $all.ORDER_TRANSACTIONS } -Inputs $in2 -PreviousCostState $prev -Config $Config -RunId $RunId
    foreach ($k in $s2.Tables.Keys) { $all[$k] = ConvertTo-RoundTrip '02_OPERATIONS' $k $s2.Tables[$k] (Join-Path $TempDir '02') }
    $all['COST_EXCEPTIONS'] = ConvertTo-RoundTrip '02_OPERATIONS' 'COST_EXCEPTIONS' $s2.CostExceptions (Join-Path $TempDir '02')
    $all['INVENTORY_EXCEPTIONS'] = ConvertTo-RoundTrip '02_OPERATIONS' 'INVENTORY_EXCEPTIONS' $s2.InventoryExceptions (Join-Path $TempDir '02')

    $in3 = & $inputsFor '03_FINANCE'
    $s3 = Invoke-PassressFinanceStage -Upstream @{ SALES_FACT = $all.SALES_FACT; REVENUE_EVENTS = $all.REVENUE_EVENTS; ORDER_TRANSACTIONS = $all.ORDER_TRANSACTIONS; SALES_COSTED = $all.SALES_COSTED; COGS_EVENTS = $all.COGS_EVENTS; INVENTORY_MOVEMENTS = $all.INVENTORY_MOVEMENTS; INVENTORY = $all.INVENTORY; REFUND_RETURN_RECONCILIATION = $all.REFUND_RETURN_RECONCILIATION } -Inputs $in3 -CloseSnapshots $null -Config $Config -RunId $RunId
    foreach ($k in $s3.Tables.Keys) { $all[$k] = ConvertTo-RoundTrip '03_FINANCE' $k $s3.Tables[$k] (Join-Path $TempDir '03') }
    $all['FINANCE_EXCEPTIONS'] = ConvertTo-RoundTrip '03_FINANCE' 'FINANCE_EXCEPTIONS' $s3.Exceptions (Join-Path $TempDir '03')

    $in4 = & $inputsFor '04_MANAGEMENT'
    $s4 = Invoke-PassressManagementStage -Upstream @{ SALES_FACT = $all.SALES_FACT; SALES_COSTED = $all.SALES_COSTED; INVENTORY = $all.INVENTORY; CUSTOMER_BASE = $all.CUSTOMER_BASE; REFUND_RETURN_RECONCILIATION = $all.REFUND_RETURN_RECONCILIATION; PROFIT_AND_LOSS = $all.PROFIT_AND_LOSS; BALANCE_SHEET = $all.BALANCE_SHEET; CASH_FLOW = $all.CASH_FLOW; PRODUCT_PL = $all.PRODUCT_PL; FINANCE_EXCEPTIONS = $all.FINANCE_EXCEPTIONS } -Inputs $in4 -Config $Config -RunId $RunId
    foreach ($k in $s4.Tables.Keys) { $all[$k] = ConvertTo-RoundTrip '04_MANAGEMENT' $k $s4.Tables[$k] (Join-Path $TempDir '04') }
    $all['MANAGEMENT_EXCEPTIONS'] = ConvertTo-RoundTrip '04_MANAGEMENT' 'MANAGEMENT_EXCEPTIONS' $s4.Exceptions (Join-Path $TempDir '04')
    return $all
}

function Test-ValueMatch {
    param($Actual, $Expected, [double]$Tol = 0.005)
    if ($null -eq $Expected) { return ($null -eq $Actual -or "$Actual" -eq '') }
    if ($Expected -is [bool]) { return ((ConvertTo-PassressBool $Actual) -eq $Expected) }
    if ($Expected -is [int] -or $Expected -is [long] -or $Expected -is [double] -or $Expected -is [decimal]) { if ($null -eq $Actual -or "$Actual" -eq '') { return $false }; return ([math]::Abs([double]$Actual - [double]$Expected) -le $Tol) }
    if ($Actual -is [datetime]) { return ($Actual.ToString('yyyy-MM-dd') -eq [string]$Expected) }
    return ([string]$Actual -eq [string]$Expected)
}

function Invoke-Assertion {
    param([hashtable]$Assertion, [hashtable]$Tables)
    $a = $Assertion
    $rows = if ($Tables.ContainsKey($a.Table)) { @($Tables[$a.Table]) } else { $null }
    if ($null -eq $rows) { return [pscustomobject]@{ Id = $a.Id; Desc = $a.Desc; Expected = 'table ' + $a.Table; Actual = 'table missing'; Result = 'FAIL' } }
    if ($a.Type -eq 'equalSums') {
        $sa = 0.0; $sb = 0.0; foreach ($r in $rows) { if ($null -ne $r.($a.ColumnA)) { $sa += [double]$r.($a.ColumnA) }; if ($null -ne $r.($a.ColumnB)) { $sb += [double]$r.($a.ColumnB) } }
        $ok = [math]::Abs($sa - $sb) -lt 0.005
        return [pscustomobject]@{ Id = $a.Id; Desc = $a.Desc; Expected = "sum($($a.ColumnA)) = sum($($a.ColumnB))"; Actual = ('{0} / {1}' -f [math]::Round($sa, 2), [math]::Round($sb, 2)); Result = $(if ($ok) { 'PASS' } else { 'FAIL' }) }
    }
    $m = @($rows | Where-Object { $r = $_; $ok = $true; foreach ($k in $a.Where.Keys) { if (-not (Test-ValueMatch $r.$k $a.Where[$k])) { $ok = $false; break } }; $ok })
    $actual = $null
    switch ($a.Agg) {
        'count' { $actual = $m.Count; $ok = ($m.Count -eq [int]$a.Expected) }
        'sum' { $s = 0.0; foreach ($r in $m) { if ($null -ne $r.($a.Column)) { $s += [double]$r.($a.Column) } }; $actual = [math]::Round($s, 2); $ok = Test-ValueMatch $s $a.Expected $a.Tol }
        'value' { if ($m.Count -ne 1) { $actual = "$($m.Count) matching rows"; $ok = $false } else { $actual = $m[0].($a.Column); $ok = Test-ValueMatch $actual $a.Expected $a.Tol } }
    }
    $fmt = { param($v) if ($null -eq $v) { '(blank)' } elseif ($v -is [datetime]) { $v.ToString('yyyy-MM-dd') } else { [string]$v } }
    return [pscustomobject]@{ Id = $a.Id; Desc = $a.Desc; Expected = (& $fmt $a.Expected); Actual = (& $fmt $actual); Result = $(if ($ok) { 'PASS' } else { 'FAIL' }) }
}
