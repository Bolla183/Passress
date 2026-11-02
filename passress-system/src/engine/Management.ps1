# Stage 04 - MANAGEMENT. Decision-support views. REAL orders only; every value carries a data status.

function Invoke-PassressManagementStage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Upstream,   # 01 SALES_FACT ; 02 SALES_COSTED, INVENTORY, CUSTOMER_BASE, REFUND_RETURN_RECONCILIATION ; 03 PROFIT_AND_LOSS, BALANCE_SHEET, CASH_FLOW, PRODUCT_PL, FINANCE_EXCEPTIONS
        [Parameter(Mandatory)][hashtable]$Inputs,     # MARKETING_INPUT, BUDGET_INPUT
        [Parameter(Mandatory)]$Config, [Parameter(Mandatory)][string]$RunId
    )
    $Upstream = ConvertTo-PassressRowSet $Upstream @('SALES_FACT', 'SALES_COSTED', 'INVENTORY', 'CUSTOMER_BASE', 'REFUND_RETURN_RECONCILIATION', 'PROFIT_AND_LOSS', 'BALANCE_SHEET', 'CASH_FLOW', 'PRODUCT_PL', 'FINANCE_EXCEPTIONS')
    $Inputs = ConvertTo-PassressRowSet $Inputs @('MARKETING_INPUT', 'BUDGET_INPUT')
    $ex = New-List
    $facts = @($Upstream.SALES_FACT | Where-Object { $_.IsReportable })
    $pl = @($Upstream.PROFIT_AND_LOSS); $bs = @($Upstream.BALANCE_SHEET); $cf = @($Upstream.CASH_FLOW)
    $plv = { param($m, $line) $r = @($pl | Where-Object { $_.Month -eq $m -and $_.LineItem -eq $line } | Select-Object -First 1); if ($r.Count) { return $r[0].Amount } return $null }
    $plStatus = { param($m) $r = @($pl | Where-Object { $_.Month -eq $m } | Select-Object -First 1); if ($r.Count) { return $r[0].Status } return 'INCOMPLETE' }
    $months = @($pl | ForEach-Object { $_.Month } | Sort-Object -Unique)

    # customer first-order month (REAL, non-cancelled)
    $firstMonth = @{}
    foreach ($f in ($facts | Where-Object { -not $_.OrderCancelled -and $_.CustomerGID } | Sort-Object { $_.OrderDateLocal })) { $cg = [string]$f.CustomerGID; if (-not $firstMonth.ContainsKey($cg)) { $firstMonth[$cg] = $f.OrderMonth } }
    $recvByLine = @{}; foreach ($r in @($Upstream.REFUND_RETURN_RECONCILIATION)) { if ($r.LineItemGID) { $recvByLine[[string]$r.LineItemGID] = [int]$r.ReceivedQty } }

    $KPI = New-List; $prevRev = $null; $prevNp = $null; $newByMonth = @{}
    foreach ($m in $months) {
        $mf = @($facts | Where-Object { $_.OrderMonth -eq $m })
        $orders = @($mf | Where-Object { -not $_.OrderCancelled } | ForEach-Object { $_.OrderGID } | Sort-Object -Unique).Count
        $units = 0; $recv = 0; foreach ($f in $mf) { $units += [int]$f.QtyShipped; $recv += [int](Get-MapValue $recvByLine ([string]$f.LineItemGID) 0) }
        $custs = @($mf | Where-Object { -not $_.OrderCancelled -and $_.CustomerGID } | ForEach-Object { [string]$_.CustomerGID } | Sort-Object -Unique)
        $new = @($custs | Where-Object { $firstMonth[$_] -eq $m }).Count; $ret = $custs.Count - $new; $newByMonth[$m] = $new
        $shippedLines = @(@($Upstream.SALES_COSTED) | Where-Object { $_.OrderMonth -eq $m -and [int]$_.QtyShipped -gt 0 })
        $okLines = @($shippedLines | Where-Object { $_.CostStatus -eq 'OK' }).Count
        $coverage = Get-SafeDivide $okLines $shippedLines.Count
        $rev = & $plv $m 'Net Revenue'; $gross = & $plv $m 'Gross Sales'; $gp = & $plv $m 'Gross Profit'; $np = & $plv $m 'Net Profit'
        $refunds = -1 * ([double](& $plv $m 'Refunds (line-item allocated)') + [double](& $plv $m 'Refunds (unallocated)'))
        $status = & $plStatus $m; if ($null -ne $coverage -and $coverage -lt 1) { $status = 'INCOMPLETE' }
        $KPI.Add([ordered]@{ Month = $m; Orders = $orders; UnitsSold = $units; GrossSales = $gross; NetRevenue = $rev; RevenueGrowthPct = $(if ($null -ne $prevRev -and $prevRev -ne 0) { Get-SafeDivide ($rev - $prevRev) ([math]::Abs($prevRev)) } else { $null }); GrossProfit = $gp; GrossMarginPct = (Get-SafeDivide $gp $rev); NetProfit = $np; NetProfitGrowthPct = $(if ($null -ne $prevNp -and $prevNp -ne 0) { Get-SafeDivide ($np - $prevNp) ([math]::Abs($prevNp)) } else { $null }); NetMarginPct = (Get-SafeDivide $np $rev); AverageOrderValue = $(if ($orders -gt 0) { Get-RoundedMoney ($rev / $orders) } else { $null }); NewCustomers = $new; ReturningCustomers = $ret; RepeatPurchaseRatePct = (Get-SafeDivide $ret $custs.Count); RefundRatePct = (Get-SafeDivide $refunds $gross); ReturnRatePct = (Get-SafeDivide $recv $units); CostCoveragePct = $coverage; DataStatus = $status })
        $prevRev = $rev; $prevNp = $np
    }

    # executive dashboard: latest month + YTD of its year
    $DASH = New-List
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $invRows = @($Upstream.INVENTORY)
    $invValue = 0.0; $invIncomplete = $false; foreach ($i in $invRows) { if ($null -eq $i.StockValue -or $i.StockStatus -eq 'INCOMPLETE' -or $i.StockStatus -eq 'NEGATIVE') { $invIncomplete = $true }; if ($null -ne $i.StockValue) { $invValue += [double]$i.StockValue } }
    if ($months.Count -gt 0) {
        $latest = $months[$months.Count - 1]; $year = $latest.Substring(0, 4)
        $k = @($KPI | Where-Object { $_.Month -eq $latest })[0]
        $ytdMonths = @($months | Where-Object { $_.StartsWith($year) })
        $ytd = { param($line) $s = 0.0; foreach ($m in $ytdMonths) { $v = & $plv $m $line; if ($null -ne $v) { $s += [double]$v } }; return (Get-RoundedMoney $s) }
        $ytdStatus = if (@($KPI | Where-Object { $ytdMonths -contains $_.Month -and $_.DataStatus -eq 'INCOMPLETE' }).Count -gt 0) { 'INCOMPLETE' } else { 'PRELIMINARY' }
        $cov = $k.CostCoveragePct
        $covWarn = if ($null -ne $cov -and $cov -lt 1) { ('Cost coverage {0:P0}: COGS/profit understated until costs are entered.' -f $cov) } else { '' }
        $ytdOrders = 0; $ytdUnits = 0; foreach ($x in @($KPI | Where-Object { $ytdMonths -contains $_.Month })) { $ytdOrders += [int]$x.Orders; $ytdUnits += [int]$x.UnitsSold }
        $ytdRev = & $ytd 'Net Revenue'; $ytdGP = & $ytd 'Gross Profit'; $ytdNP = & $ytd 'Net Profit'; $ytdGross = & $ytd 'Gross Sales'
        $ytdRefunds = -1 * ((& $ytd 'Refunds (line-item allocated)') + (& $ytd 'Refunds (unallocated)'))
        $bsCash = @($bs | Where-Object { $_.Month -eq $latest -and $_.LineItem -eq 'Cash & Bank' })
        $cashVal = if ($bsCash.Count) { $bsCash[0].Amount } else { $null }; $cashStatus = if ($bsCash.Count) { $bsCash[0].Status } else { 'INCOMPLETE' }
        $add = { param($metric, $period, $label, $value, $unit, $status, $warning) $DASH.Add([ordered]@{ Metric = $metric; Period = $period; PeriodLabel = $label; Value = $value; Unit = $unit; DataStatus = $status; Warning = $warning }) }
        $lbl = $latest; $ylbl = $year + ' YTD'
        & $add 'Gross Sales' 'LATEST_MONTH' $lbl $k.GrossSales 'EGP' $k.DataStatus ''
        & $add 'Net Revenue' 'LATEST_MONTH' $lbl $k.NetRevenue 'EGP' $k.DataStatus ''
        & $add 'Gross Profit' 'LATEST_MONTH' $lbl $k.GrossProfit 'EGP' $k.DataStatus $covWarn
        & $add 'Gross Margin %' 'LATEST_MONTH' $lbl $k.GrossMarginPct '%' $k.DataStatus $covWarn
        & $add 'Net Profit' 'LATEST_MONTH' $lbl $k.NetProfit 'EGP' $k.DataStatus $covWarn
        & $add 'Net Profit Margin %' 'LATEST_MONTH' $lbl $k.NetMarginPct '%' $k.DataStatus $covWarn
        & $add 'Orders' 'LATEST_MONTH' $lbl $k.Orders 'count' 'OK' ''
        & $add 'Units Sold' 'LATEST_MONTH' $lbl $k.UnitsSold 'count' 'OK' ''
        & $add 'Average Order Value' 'LATEST_MONTH' $lbl $k.AverageOrderValue 'EGP' $k.DataStatus ''
        & $add 'Returning Customer %' 'LATEST_MONTH' $lbl $k.RepeatPurchaseRatePct '%' 'OK' ''
        & $add 'Refund Rate %' 'LATEST_MONTH' $lbl $k.RefundRatePct '%' 'OK' ''
        & $add 'Net Revenue' 'YTD' $ylbl $ytdRev 'EGP' $ytdStatus ''
        & $add 'Gross Profit' 'YTD' $ylbl $ytdGP 'EGP' $ytdStatus $covWarn
        & $add 'Gross Margin %' 'YTD' $ylbl (Get-SafeDivide $ytdGP $ytdRev) '%' $ytdStatus $covWarn
        & $add 'Net Profit' 'YTD' $ylbl $ytdNP 'EGP' $ytdStatus $covWarn
        & $add 'Net Profit Margin %' 'YTD' $ylbl (Get-SafeDivide $ytdNP $ytdRev) '%' $ytdStatus $covWarn
        & $add 'Orders' 'YTD' $ylbl $ytdOrders 'count' 'OK' ''
        & $add 'Units Sold' 'YTD' $ylbl $ytdUnits 'count' 'OK' ''
        & $add 'Average Order Value' 'YTD' $ylbl $(if ($ytdOrders -gt 0) { Get-RoundedMoney ($ytdRev / $ytdOrders) } else { $null }) 'EGP' $ytdStatus ''
        & $add 'Refund Rate %' 'YTD' $ylbl (Get-SafeDivide $ytdRefunds $ytdGross) '%' 'OK' ''
        & $add 'Inventory Value' 'LATEST_MONTH' 'current' (Get-RoundedMoney $invValue) 'EGP' $(if ($invIncomplete) { 'INCOMPLETE' } else { 'PRELIMINARY' }) $(if ($invIncomplete) { 'Opening stock and/or unit costs missing for some SKUs - value understated.' } else { '' })
        & $add 'Cash Position' 'LATEST_MONTH' $lbl $cashVal 'EGP' $cashStatus $(if ($cashStatus -eq 'INCOMPLETE') { 'Opening cash/bank balances not entered - cash figure is not a real balance yet.' } else { '' })
        # reconciliation: dashboard YTD vs Finance
        $finYtd = 0.0; foreach ($m in $ytdMonths) { $finYtd += [double](& $plv $m 'Net Profit') }
        if (-not (Test-MoneyEqual $finYtd $ytdNP)) { $ex.Add((New-PassressException -CheckName 'DASHBOARD_PROFIT_VS_FINANCE' -Severity ERROR -AffectedRecord $ylbl -ExpectedValue $finYtd -ActualValue $ytdNP -RecommendedAction 'Dashboard profit does not match Finance.' -RunId $RunId)) }
    }
    $kpiRev = 0.0; foreach ($x in $KPI) { if ($null -ne $x.NetRevenue) { $kpiRev += [double]$x.NetRevenue } }
    $plRev = 0.0; foreach ($m in $months) { $v = & $plv $m 'Net Revenue'; if ($null -ne $v) { $plRev += [double]$v } }
    if (-not (Test-MoneyEqual $kpiRev $plRev)) { $ex.Add((New-PassressException -CheckName 'KPI_REVENUE_VS_FINANCE' -Severity ERROR -AffectedRecord 'ALL' -ExpectedValue $plRev -ActualValue $kpiRev -RecommendedAction 'Monthly KPI revenue does not reconcile to the P&L.' -RunId $RunId)) }

    # product performance
    $PERF = New-List; $invBySku = @{}; foreach ($i in $invRows) { $invBySku[[string]$i.SKU] = $i }
    $prodRows = @($Upstream.PRODUCT_PL | Where-Object { $_.SKU -ne 'SHIPPING_INCOME' -and $_.SKU -ne 'UNALLOCATED_REFUNDS' } | Sort-Object { [double]$_.NetRevenue } -Descending)
    $rank = 0
    foreach ($p in $prodRows) {
        $rank++; $i = Get-MapValue $invBySku ([string]$p.SKU) $null
        $closing = if ($i) { $i.ClosingSellable } else { $null }
        $st = if ($null -ne $closing -and $i.StockStatus -ne 'INCOMPLETE' -and $i.StockStatus -ne 'NEGATIVE') { Get-SafeDivide $p.UnitsSold ([double]$p.UnitsSold + [double]$closing) } else { $null }
        $PERF.Add([ordered]@{ Rank = $rank; SKU = $p.SKU; ProductTitle = $p.ProductTitle; UnitsSold = $p.UnitsSold; NetRevenue = $p.NetRevenue; GrossProfit = $p.GrossProfit; GrossMarginPct = $p.GrossMarginPct; ReturnRatePct = $p.ReturnRatePct; ClosingSellable = $closing; SellThroughPct = $st; CostStatus = $p.CostStatus })
    }

    # customer analytics (cohorts)
    $CA = New-List; $groups = @{}
    foreach ($c in @($Upstream.CUSTOMER_BASE)) {
        $cohort = if ($null -ne $c.FirstOrderDate) { Get-MonthKey $c.FirstOrderDate } else { '(none)' }
        $key = $cohort + '|' + $c.Segment
        if (-not $groups.ContainsKey($key)) { $groups[$key] = @{ Cohort = $cohort; Segment = $c.Segment; N = 0; Orders = 0; Net = 0.0 } }
        $g = $groups[$key]; $g.N++; $g.Orders += [int]$c.TotalOrders; $g.Net += [double]$c.TotalNetRevenue
    }
    foreach ($key in @($groups.Keys | Sort-Object)) { $g = $groups[$key]; $CA.Add([ordered]@{ CohortMonth = $g.Cohort; Segment = $g.Segment; Customers = $g.N; Orders = $g.Orders; NetRevenue = (Get-RoundedMoney $g.Net); AvgLifetimeValue = (Get-SafeDivide $g.Net $g.N); AvgOrdersPerCustomer = (Get-SafeDivide $g.Orders $g.N) }) }

    # marketing (manual only; nothing fabricated)
    $MK = New-List; $spendByMonth = @{}
    foreach ($r in @($Inputs.MARKETING_INPUT)) { if ($r.Month -and $null -ne $r.Spend) { Add-ToMap $spendByMonth ([string]$r.Month) ([double]$r.Spend) } }
    foreach ($r in @($Inputs.MARKETING_INPUT)) {
        if (Test-Blank $r.Month) { continue }
        $m = [string]$r.Month; $newC = Get-MapValue $newByMonth $m 0
        $MK.Add([ordered]@{ Month = $m; Channel = $r.Channel; Campaign = $r.Campaign; Spend = $r.Spend; Impressions = $r.Impressions; Clicks = $r.Clicks; Sessions = $r.Sessions; AttributedOrders = $r.AttributedOrders; AttributedRevenue = $r.AttributedRevenue; ROAS = (Get-SafeDivide $r.AttributedRevenue $r.Spend); CPA = (Get-SafeDivide $r.Spend $r.AttributedOrders); ConversionRatePct = (Get-SafeDivide $r.AttributedOrders $r.Sessions); ShopifyNetRevenueMonth = (& $plv $m 'Net Revenue'); BlendedCAC = (Get-SafeDivide (Get-MapValue $spendByMonth $m $null) $newC); DataSource = $(if ($r.DataSource) { $r.DataSource } else { 'MANUAL' }) })
    }

    $IO = New-List; foreach ($i in $invRows) { $IO.Add([ordered]@{ SKU = $i.SKU; ProductName = $i.ProductName; ClosingSellable = $i.ClosingSellable; DamagedOnHand = $i.DamagedOnHand; StockValue = $i.StockValue; StockStatus = $i.StockStatus }) }

    # budget vs actual (assumptions are never shown as actuals)
    $BVA = New-List; $bk = @{}
    foreach ($b in @($Inputs.BUDGET_INPUT)) { if ($b.Month -and $b.LineItem) { $key = [string]$b.Month + '|' + [string]$b.LineItem; if (-not $bk.ContainsKey($key)) { $bk[$key] = @{ Budget = $null; Forecast = $null } }; if (([string]$b.ValueType).ToUpperInvariant() -eq 'FORECAST') { $bk[$key].Forecast = $b.Amount } else { $bk[$key].Budget = $b.Amount } } }
    foreach ($key in @($bk.Keys | Sort-Object)) {
        $parts = $key.Split('|'); $m = $parts[0]; $line = $parts[1]
        $actual = switch ($line) {
            'Net Revenue' { & $plv $m 'Net Revenue' } 'COGS' { $v = & $plv $m 'Cost of Goods Sold'; if ($null -ne $v) { -1 * [double]$v } else { $null } }
            'Gross Profit' { & $plv $m 'Gross Profit' } 'Net Profit' { & $plv $m 'Net Profit' }
            'Marketing' { $v = & $plv $m 'Marketing'; if ($null -ne $v) { -1 * [double]$v } else { $null } }
            'Operating Expenses' { $v = & $plv $m 'Total Operating Expenses'; if ($null -ne $v) { -1 * [double]$v } else { $null } }
            'Closing Cash' { $r = @($cf | Where-Object { $_.Month -eq $m -and $_.LineItem -eq 'Closing Cash' }); if ($r.Count) { $r[0].Amount } else { $null } }
            default { $null }
        }
        $b = $bk[$key]
        $BVA.Add([ordered]@{ Month = $m; LineItem = $line; Actual = $actual; Budget = $b.Budget; Forecast = $b.Forecast; VarianceToBudget = $(if ($null -ne $actual -and $null -ne $b.Budget) { Get-RoundedMoney ([double]$actual - [double]$b.Budget) } else { $null }); ActualStatus = $(if ($null -eq $actual) { 'NO_ACTUAL' } else { & $plStatus $m }) })
    }

    # test-order leakage guard: management inputs must only contain REAL lines
    $nonReal = @{}; foreach ($f in @($Upstream.SALES_FACT)) { if (-not $f.IsReportable) { $nonReal[[string]$f.OrderGID] = $true } }
    $leak = @(@($Upstream.SALES_COSTED) | Where-Object { $null -ne $_ -and $nonReal.ContainsKey([string]$_.OrderGID) })
    foreach ($l in $leak) { $ex.Add((New-PassressException -CheckName 'TEST_ORDER_IN_MANAGEMENT' -Severity ERROR -AffectedRecord ([string]$l.LineItemGID) -OrderName $l.OrderName -Classification 'TEST' -RecommendedAction 'A non-REAL order reached management data. Must never happen - report it.' -RunId $RunId)) }
    $finErrors = @($Upstream.FINANCE_EXCEPTIONS | Where-Object { $_.Severity -eq 'ERROR' }).Count
    if ($finErrors -gt 0) { $ex.Add((New-PassressException -CheckName 'UPSTREAM_FINANCE_ERRORS' -Severity WARNING -AffectedRecord '03_FINANCE' -ActualValue $finErrors -RecommendedAction 'Finance has open ERROR exceptions; affected figures are marked INCOMPLETE.' -RunId $RunId)) }

    $tables = @{ KPI_MONTHLY = $KPI.ToArray(); EXECUTIVE_DASHBOARD = $DASH.ToArray(); PRODUCT_PERFORMANCE = $PERF.ToArray(); CUSTOMER_ANALYTICS = $CA.ToArray(); MARKETING_PERFORMANCE = $MK.ToArray(); INVENTORY_OVERVIEW = $IO.ToArray(); BUDGET_VS_ACTUAL = $BVA.ToArray() }
    return [pscustomobject]@{ Tables = $tables; Exceptions = (Get-UniqueExceptions $ex.ToArray()) }
}
