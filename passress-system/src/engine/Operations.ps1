# Stage 02 - OPERATIONS. Costing (effective-dated), physical returns + inspection, inventory ledger.
# RULES (mandatory):
#  * A financial refund alone NEVER reverses COGS and NEVER increases inventory.
#  * COGS is reversed only for quantity physically RECEIVED, inspection COMPLETE + approved, decided SELLABLE,
#    at the ORIGINAL sale's effective unit cost.
#  * DAMAGED / WRITE_OFF returns keep the original COGS and go to separate memo buckets (no sellable stock).
#  * Missing cost is never zero-filled; the line stays visible and is flagged.

function Get-CostRecordHash {
    param($Row)
    $parts = @('SKU', 'VariantGID', 'UnitCost', 'EffectiveFrom', 'EffectiveTo', 'ApprovedBy') | ForEach-Object { Format-PassressValue -Value (Get-RowValue $Row $_) -Type $(if ($_ -like 'Effective*') { 'date' } elseif ($_ -eq 'UnitCost') { 'number' } else { 'text' }) }
    return ($parts -join '|')
}

function Initialize-PassressCostBook {
    # Validates COST_MASTER, enforces append-only against the previous state, returns a lookup object.
    param([AllowEmptyCollection()][object[]]$CostRows, $PreviousState, [string]$RunId)
    $ex = New-List; $approved = New-List; $seenIds = @{}; $state = @{}
    foreach ($r in @($CostRows)) {
        $id = [string]$r.CostRecordID; $sku = [string]$r.SKU
        if (Test-Blank $id) { $ex.Add((New-PassressException -CheckName 'COST_RECORD_WITHOUT_ID' -Severity ERROR -AffectedRecord $sku -RecommendedAction 'Give every COST_MASTER row a unique CostRecordID. Row ignored.' -RunId $RunId)); continue }
        if ($seenIds.ContainsKey($id)) { $ex.Add((New-PassressException -CheckName 'DUPLICATE_COST_RECORD_ID' -Severity ERROR -AffectedRecord $id -RecommendedAction 'CostRecordID must be unique. Later row ignored.' -RunId $RunId)); continue }
        $seenIds[$id] = $true
        $components = @('FabricCost', 'ManufacturingCost', 'AccessoriesCost', 'PackagingCost', 'OtherDirectCost')
        $hasComp = $false; $compSum = 0.0
        foreach ($c in $components) { $v = $r.$c; if ($null -ne $v) { $hasComp = $true; $compSum += [double]$v } }
        $unit = $r.UnitCost
        if ($null -eq $unit -and $hasComp) { $unit = Get-RoundedMoney $compSum }
        if ($hasComp -and $null -ne $r.UnitCost -and -not (Test-MoneyEqual ([double]$r.UnitCost) $compSum)) {
            $ex.Add((New-PassressException -CheckName 'COST_COMPONENT_MISMATCH' -Severity WARNING -AffectedRecord $id -ExpectedValue (Get-RoundedMoney $compSum) -ActualValue $r.UnitCost -Difference (Get-RoundedMoney ([double]$r.UnitCost - $compSum)) -RecommendedAction 'UnitCost differs from the sum of components; UnitCost is used. Correct by adding a NEW cost row.' -RunId $RunId))
        }
        $problems = @()
        if (Test-Blank $sku) { $problems += 'SKU' }
        if ($null -eq $unit -or [double]$unit -le 0) { $problems += 'UnitCost' }
        if ($null -eq $r.EffectiveFrom) { $problems += 'EffectiveFrom' }
        if (Test-Blank $r.ApprovedBy) { $problems += 'ApprovedBy' }
        if ($null -ne $r.EffectiveTo -and $null -ne $r.EffectiveFrom -and $r.EffectiveTo -lt $r.EffectiveFrom) { $problems += 'EffectiveTo<EffectiveFrom' }
        if ($problems.Count -gt 0) {
            $ex.Add((New-PassressException -CheckName 'COST_RECORD_NOT_USABLE' -Severity WARNING -AffectedRecord $id -ActualValue ('missing/invalid: ' + ($problems -join ', ')) -RecommendedAction 'Row is ignored until complete and approved. Costs are never assumed.' -RunId $RunId))
            continue
        }
        $hash = Get-CostRecordHash $r
        $state[$id] = $hash
        $approved.Add([pscustomobject]@{ CostRecordID = $id; SKU = $sku; UnitCost = [double]$unit; From = [datetime]$r.EffectiveFrom; To = $r.EffectiveTo })
    }
    # Append-only enforcement: an approved row that changed or disappeared since the last run is flagged.
    if ($null -ne $PreviousState) {
        foreach ($p in $PreviousState.PSObject.Properties) {
            if (-not $state.ContainsKey($p.Name)) {
                $ex.Add((New-PassressException -CheckName 'COST_RECORD_DELETED_OR_UNAPPROVED' -Severity ERROR -AffectedRecord $p.Name -ExpectedValue $p.Value -ActualValue 'missing' -RecommendedAction 'An approved cost row was removed or un-approved. Restore it: history must stay traceable (add a new row with a later EffectiveFrom instead).' -RunId $RunId))
                $state[$p.Name] = $p.Value   # keep flagging until restored
            } elseif ($state[$p.Name] -ne $p.Value) {
                $ex.Add((New-PassressException -CheckName 'COST_RECORD_MODIFIED' -Severity ERROR -AffectedRecord $p.Name -ExpectedValue $p.Value -ActualValue $state[$p.Name] -RecommendedAction 'An approved cost row was edited. This silently changes historical COGS. Revert the edit and add a new row with a new EffectiveFrom.' -RunId $RunId))
            }
        }
    }
    # Overlaps
    $bySku = @{}; foreach ($a in $approved) { if (-not $bySku.ContainsKey($a.SKU)) { $bySku[$a.SKU] = New-List }; $bySku[$a.SKU].Add($a) }
    foreach ($sku in $bySku.Keys) {
        $list = @($bySku[$sku] | Sort-Object From)
        for ($i = 0; $i -lt $list.Count - 1; $i++) {
            $cur = $list[$i]; $nxt = $list[$i + 1]
            # An open-ended row (EffectiveTo blank) is simply superseded by a later EffectiveFrom - that is the normal
            # append-only pattern. An explicit EffectiveTo that runs past the next row's start is a real overlap.
            if ($null -ne $cur.To -and $cur.To -ge $nxt.From) {
                $ex.Add((New-PassressException -CheckName 'COST_PERIOD_OVERLAP' -Severity ERROR -AffectedRecord ($cur.CostRecordID + ' / ' + $nxt.CostRecordID) -RecommendedAction 'Two approved costs cover the same dates for this SKU. The most recent EffectiveFrom is used; fix EffectiveTo.' -RunId $RunId))
            }
            if ($cur.From -eq $nxt.From) {
                $ex.Add((New-PassressException -CheckName 'COST_SAME_EFFECTIVE_DATE' -Severity ERROR -AffectedRecord ($cur.CostRecordID + ' / ' + $nxt.CostRecordID) -RecommendedAction 'Two approved costs for this SKU start on the same date; the result is ambiguous. Keep one.' -RunId $RunId))
            }
        }
    }
    return [pscustomobject]@{ Records = $bySku; State = $state; Exceptions = $ex }
}

function Get-PassressEffectiveCost {
    # Most recent approved record whose EffectiveFrom <= date and (EffectiveTo blank or >= date). Open-ended earlier rows
    # are naturally superseded by a later EffectiveFrom.
    param($CostBook, [string]$SKU, $Date)
    if ((Test-Blank $SKU) -or $null -eq $Date -or -not $CostBook.Records.ContainsKey($SKU)) { return $null }
    $best = $null
    foreach ($r in $CostBook.Records[$SKU]) {
        if ($r.From -le $Date -and ($null -eq $r.To -or $r.To -ge $Date)) { if ($null -eq $best -or $r.From -gt $best.From) { $best = $r } }
    }
    return $best
}

function Invoke-PassressOperationsStage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Upstream,   # SALES_FACT, REVENUE_EVENTS, RAW_CUSTOMERS, RAW_VARIANTS, REFUND_RECONCILIATION (from 01)
        [Parameter(Mandatory)][hashtable]$Inputs,     # HEIRARCHY, COST_MASTER, OPENING_INVENTORY, PRODUCTION, SUPPLIERS, PURCHASES, RETURNS, RETURN_INSPECTIONS, INVENTORY_ADJUSTMENTS
        $PreviousCostState, [Parameter(Mandatory)]$Config, [Parameter(Mandatory)][string]$RunId
    )
    $Upstream = ConvertTo-PassressRowSet $Upstream @('SALES_FACT', 'REVENUE_EVENTS', 'RAW_CUSTOMERS', 'RAW_VARIANTS', 'REFUND_RECONCILIATION')
    $Inputs = ConvertTo-PassressRowSet $Inputs @('HEIRARCHY', 'COST_MASTER', 'OPENING_INVENTORY', 'PRODUCTION', 'SUPPLIERS', 'PURCHASES', 'RETURNS', 'RETURN_INSPECTIONS', 'INVENTORY_ADJUSTMENTS')
    $T = @{}; foreach ($n in @('SALES', 'CUSTOMER_BASE', 'SALES_COSTED', 'COGS_EVENTS', 'INVENTORY_MOVEMENTS', 'INVENTORY', 'REFUND_RETURN_RECONCILIATION')) { $T[$n] = New-List }
    $costEx = New-List; $invEx = New-List

    $facts = @($Upstream.SALES_FACT); $events = @($Upstream.REVENUE_EVENTS)
    $factByLine = @{}; foreach ($f in $facts) { $factByLine[[string]$f.LineItemGID] = $f }
    $customers = @{}; foreach ($c in @($Upstream.RAW_CUSTOMERS)) { $customers[[string]$c.CustomerGID] = $c }
    $real = @($facts | Where-Object { $_.IsReportable })

    $book = Initialize-PassressCostBook -CostRows @($Inputs.COST_MASTER) -PreviousState $PreviousCostState -RunId $RunId
    foreach ($e in $book.Exceptions) { $costEx.Add($e) }

    # ------------------------------------------------ SALES view + CUSTOMER_BASE (REAL only)
    foreach ($f in $real) {
        $c = Get-MapValue $customers ([string]$f.CustomerGID) $null
        $T.SALES.Add([ordered]@{ OrderName = $f.OrderName; OrderDateLocal = $f.OrderDateLocal; CustomerGID = $f.CustomerGID; CustomerName = $(if ($c) { $c.DisplayName } else { $null }); City = $(if ($c) { $c.City } else { $null }); SKU = $f.SKU; ProductTitle = $f.ProductTitle; VariantTitle = $f.VariantTitle; QtyOrdered = $f.QtyOrdered; UnitPrice = $f.UnitPrice; LineDiscount = $f.LineDiscount; GrossSales = $f.GrossSales; QtyRefunded = $f.QtyRefunded; RefundAllocated = $f.RefundAllocated; NetRevenue = $f.NetRevenue; FinancialStatus = $f.FinancialStatus; FulfillmentStatus = $f.FulfillmentStatus; LineItemGID = $f.LineItemGID })
    }
    $realEvents = @($events | Where-Object { $_.IsReportable })
    $orderCustomer = @{}; $orderDate = @{}; $orderCancelled = @{}
    foreach ($f in $real) { $orderCustomer[[string]$f.OrderGID] = [string]$f.CustomerGID; $orderDate[[string]$f.OrderGID] = $f.OrderDateLocal; $orderCancelled[[string]$f.OrderGID] = [bool]$f.OrderCancelled }
    $custAgg = @{}
    foreach ($ev in $realEvents) {
        $cg = Get-MapValue $orderCustomer ([string]$ev.OrderGID) ''
        if (-not $cg) { continue }
        if (-not $custAgg.ContainsKey($cg)) { $custAgg[$cg] = @{ Gross = 0.0; Refunds = 0.0; Net = 0.0; Orders = @{}; Dates = New-List } }
        $a = $custAgg[$cg]
        $a.Net += [double]$ev.NetAmount
        if ($ev.EventType -eq 'SALE') { $a.Gross += [double]$ev.GrossAmount }
        if ($ev.EventType -like 'REFUND_*') { $a.Refunds += -1 * [double]$ev.NetAmount }
    }
    foreach ($og in $orderCustomer.Keys) {
        $cg = $orderCustomer[$og]; if (-not $cg -or -not $custAgg.ContainsKey($cg)) { continue }
        if (-not $orderCancelled[$og]) { $custAgg[$cg].Orders[$og] = $true; $custAgg[$cg].Dates.Add($orderDate[$og]) }
    }
    foreach ($cg in $custAgg.Keys) {
        $a = $custAgg[$cg]; $c = Get-MapValue $customers $cg $null
        $n = $a.Orders.Count; $dates = @($a.Dates | Where-Object { $null -ne $_ } | Sort-Object)
        $seg = if ($n -eq 0) { 'CANCELLED_ONLY' } elseif ($a.Net -le 0) { 'REFUNDED_ONLY' } elseif ($n -eq 1) { 'NEW' } elseif ($n -le 3) { 'REPEAT' } else { 'LOYAL' }
        $T.CUSTOMER_BASE.Add([ordered]@{ CustomerGID = $cg; CustomerName = $(if ($c) { $c.DisplayName } else { $null }); Phone = $(if ($c) { $c.Phone } else { $null }); Email = $(if ($c) { $c.Email } else { $null }); City = $(if ($c) { $c.City } else { $null }); FirstOrderDate = $(if ($dates.Count) { $dates[0] } else { $null }); LastOrderDate = $(if ($dates.Count) { $dates[$dates.Count - 1] } else { $null }); TotalOrders = $n; TotalGrossSales = (Get-RoundedMoney $a.Gross); TotalRefunds = (Get-RoundedMoney $a.Refunds); TotalNetRevenue = (Get-RoundedMoney $a.Net); AverageOrderValue = $(if ($n -gt 0) { Get-RoundedMoney ($a.Net / $n) } else { $null }); Segment = $seg; RepeatCustomer = ($n -ge 2) })
    }

    # ------------------------------------------------ SALES_COSTED + COGS events (sale side)
    $costed = @{}
    foreach ($f in $real) {
        $lg = [string]$f.LineItemGID; $q = [int]$f.QtyShipped
        $unit = $null; $rec = $null; $status = 'OK'; $cogs = $null
        if ($q -le 0) { $status = 'NOT_SHIPPED'; $cogs = 0.0 }
        elseif (Test-Blank $f.SKU) {
            $status = 'MISSING_SKU'
            $costEx.Add((New-PassressException -CheckName 'MISSING_SKU_FOR_COSTING' -Severity ERROR -AffectedRecord $lg -OrderName $f.OrderName -Classification 'REAL' -ActualValue $f.ProductTitle -RecommendedAction 'Line has no SKU; COGS cannot be computed (not assumed zero). Set the SKU in Shopify.' -RunId $RunId))
        } else {
            $rec = Get-PassressEffectiveCost -CostBook $book -SKU $f.SKU -Date $f.OrderDateLocal
            if ($null -eq $rec) {
                $status = 'MISSING_COST'
                $costEx.Add((New-PassressException -CheckName 'MISSING_EFFECTIVE_COST' -Severity ERROR -AffectedRecord $lg -OrderName $f.OrderName -Classification 'REAL' -ExpectedValue ('approved cost for ' + $f.SKU + ' valid on ' + (Format-PassressValue $f.OrderDateLocal 'date')) -ActualValue 'none' -RecommendedAction 'Add an approved COST_MASTER row (EffectiveFrom on/before the sale date). COGS stays blank until then.' -RunId $RunId))
            } else { $unit = $rec.UnitCost; $cogs = Get-RoundedMoney ($q * $unit) }
        }
        $costed[$lg] = [ordered]@{ LineItemGID = $lg; OrderGID = $f.OrderGID; OrderName = $f.OrderName; OrderDateLocal = $f.OrderDateLocal; OrderMonth = $f.OrderMonth; SKU = $f.SKU; ProductTitle = $f.ProductTitle; QtyShipped = $q; NetRevenue = $f.NetRevenue; EffectiveUnitCost = $unit; CostRecordID = $(if ($rec) { $rec.CostRecordID } else { $null }); CostStatus = $status; COGS = $cogs; SellableReturnedQty = 0; COGSReversal = 0.0; NetCOGS = $null; GrossProfit = $null }
        if ($q -gt 0) {
            $T.COGS_EVENTS.Add([ordered]@{ EventID = 'COGS-' + $lg; EventType = 'COGS'; LineItemGID = $lg; OrderName = $f.OrderName; SKU = $f.SKU; EventDateLocal = $f.OrderDateLocal; EventMonth = $f.OrderMonth; Quantity = $q; UnitCost = $unit; Amount = $cogs; SourceID = $lg; CostStatus = $(if ($null -eq $cogs) { 'MISSING_COST' } else { 'OK' }) })
        }
    }

    # ------------------------------------------------ physical returns + inspections
    $validStatus = @('NOT_RETURNED', 'RETURN_REQUESTED', 'IN_TRANSIT', 'RECEIVED', 'INSPECTION_PENDING', 'CLOSED')
    $receivedStatus = @('RECEIVED', 'INSPECTION_PENDING', 'CLOSED')
    $returns = @{}; $receivedByLine = @{}; $seenReturn = @{}
    foreach ($r in @($Inputs.RETURNS | Sort-Object { if ($_.ReceivedDate) { $_.ReceivedDate } else { [datetime]::MaxValue } })) {
        $rid = [string]$r.ReturnID
        if (Test-Blank $rid) { $invEx.Add((New-PassressException -CheckName 'RETURN_WITHOUT_ID' -Severity ERROR -AffectedRecord ([string]$r.LineItemGID) -RecommendedAction 'Give the return a ReturnID. Ignored.' -RunId $RunId)); continue }
        if ($seenReturn.ContainsKey($rid)) { $invEx.Add((New-PassressException -CheckName 'DUPLICATE_RETURN_ID' -Severity ERROR -AffectedRecord $rid -RecommendedAction 'ReturnID must be unique; later row ignored (prevents double stock/COGS).' -RunId $RunId)); continue }
        $seenReturn[$rid] = $true
        $lg = [string]$r.LineItemGID; $f = Get-MapValue $factByLine $lg $null
        if ($null -eq $f) { $invEx.Add((New-PassressException -CheckName 'RETURN_LINE_NOT_FOUND' -Severity ERROR -AffectedRecord $rid -OrderName $r.OrderName -ActualValue $lg -RecommendedAction 'LineItemGID must be the ORIGINAL Shopify line item id. Ignored.' -RunId $RunId)); continue }
        if (-not $f.IsReportable) { $invEx.Add((New-PassressException -CheckName 'RETURN_ON_NON_REAL_ORDER_IGNORED' -Severity INFO -AffectedRecord $rid -OrderName $f.OrderName -Classification $f.Classification -RecommendedAction 'Returns on TEST/unclassified orders do not affect stock or COGS.' -RunId $RunId)); continue }
        $st = ([string]$r.PhysicalReturnStatus).ToUpperInvariant()
        if ($validStatus -notcontains $st) { $invEx.Add((New-PassressException -CheckName 'RETURN_STATUS_INVALID' -Severity ERROR -AffectedRecord $rid -OrderName $f.OrderName -ActualValue $st -ExpectedValue ($validStatus -join '/') -RecommendedAction 'Fix PhysicalReturnStatus. Treated as not received.' -RunId $RunId)); $st = 'INVALID' }
        $qty = if ($null -eq $r.Quantity) { 0 } else { [int]$r.Quantity }
        if ($qty -le 0) { $invEx.Add((New-PassressException -CheckName 'RETURN_QTY_INVALID' -Severity ERROR -AffectedRecord $rid -OrderName $f.OrderName -ActualValue $qty -RecommendedAction 'Quantity must be positive. Ignored.' -RunId $RunId)); continue }
        $isReceived = ($receivedStatus -contains $st)
        if ($isReceived -and $null -eq $r.ReceivedDate) { $invEx.Add((New-PassressException -CheckName 'RETURN_RECEIVED_DATE_MISSING' -Severity ERROR -AffectedRecord $rid -OrderName $f.OrderName -RecommendedAction 'Enter ReceivedDate. Treated as not received.' -RunId $RunId)); $isReceived = $false }
        if ($isReceived) {
            $already = [int](Get-MapValue $receivedByLine $lg 0)
            if (($already + $qty) -gt [int]$f.QtyShipped) {
                $invEx.Add((New-PassressException -CheckName 'RETURN_QTY_EXCEEDS_SHIPPED' -Severity ERROR -AffectedRecord $rid -OrderName $f.OrderName -ExpectedValue ('<= ' + ([int]$f.QtyShipped - $already)) -ActualValue $qty -Difference ($already + $qty - [int]$f.QtyShipped) -RecommendedAction 'More units received than were shipped on this line. Return ignored until corrected.' -RunId $RunId))
                continue
            }
            Add-ToMap $receivedByLine $lg $qty
        }
        $returns[$rid] = [pscustomobject]@{ Row = $r; Fact = $f; Qty = $qty; Received = $isReceived; Inspected = 0 }
    }

    $sellableByLine = @{}; $damagedByLine = @{}; $writeoffByLine = @{}; $seenIns = @{}
    foreach ($i in @($Inputs.RETURN_INSPECTIONS | Sort-Object { if ($_.InspectionDate) { $_.InspectionDate } else { [datetime]::MaxValue } })) {
        $iid = [string]$i.InspectionID; $rid = [string]$i.ReturnID
        if (Test-Blank $iid) { $invEx.Add((New-PassressException -CheckName 'INSPECTION_WITHOUT_ID' -Severity ERROR -AffectedRecord $rid -RecommendedAction 'Give the inspection an InspectionID. Ignored.' -RunId $RunId)); continue }
        if ($seenIns.ContainsKey($iid)) { $invEx.Add((New-PassressException -CheckName 'DUPLICATE_INSPECTION' -Severity ERROR -AffectedRecord $iid -RecommendedAction 'Duplicate InspectionID ignored (prevents a second COGS reversal).' -RunId $RunId)); continue }
        $seenIns[$iid] = $true
        if (-not $returns.ContainsKey($rid)) { $invEx.Add((New-PassressException -CheckName 'INSPECTION_RETURN_NOT_FOUND' -Severity ERROR -AffectedRecord $iid -ActualValue $rid -RecommendedAction 'Inspection refers to an unknown/ignored ReturnID.' -RunId $RunId)); continue }
        $ret = $returns[$rid]; $f = $ret.Fact
        if (-not $ret.Received) { $invEx.Add((New-PassressException -CheckName 'INSPECTION_BEFORE_RECEIPT' -Severity ERROR -AffectedRecord $iid -OrderName $f.OrderName -RecommendedAction 'Goods must be physically RECEIVED (status + date) before an inspection counts. Ignored.' -RunId $RunId)); continue }
        $sell = [int](Get-Money $i.SellableQty); $dmg = [int](Get-Money $i.DamagedQty); $wo = [int](Get-Money $i.WriteOffQty)
        if ($sell -lt 0 -or $dmg -lt 0 -or $wo -lt 0) { $invEx.Add((New-PassressException -CheckName 'INSPECTION_NEGATIVE_QTY' -Severity ERROR -AffectedRecord $iid -OrderName $f.OrderName -RecommendedAction 'Quantities cannot be negative. Ignored.' -RunId $RunId)); continue }
        $complete = (([string]$i.InspectionStatus).ToUpperInvariant() -eq 'COMPLETE' -and -not (Test-Blank $i.ApprovedBy) -and $null -ne $i.InspectionDate)
        if (-not $complete) {
            if (([string]$i.InspectionStatus).ToUpperInvariant() -eq 'COMPLETE') { $invEx.Add((New-PassressException -CheckName 'INSPECTION_NOT_APPROVED' -Severity WARNING -AffectedRecord $iid -OrderName $f.OrderName -RecommendedAction 'COMPLETE inspections need ApprovedBy and InspectionDate. Treated as pending: no COGS reversal, no stock.' -RunId $RunId)) }
            continue
        }
        if (($ret.Inspected + $sell + $dmg + $wo) -gt $ret.Qty) {
            $invEx.Add((New-PassressException -CheckName 'INSPECTION_QTY_EXCEEDS_RETURN' -Severity ERROR -AffectedRecord $iid -OrderName $f.OrderName -ExpectedValue ('<= ' + ($ret.Qty - $ret.Inspected)) -ActualValue ($sell + $dmg + $wo) -RecommendedAction 'Inspected quantity exceeds the returned quantity. Inspection ignored until corrected.' -RunId $RunId))
            continue
        }
        $ret.Inspected += ($sell + $dmg + $wo)
        $lg = [string]$f.LineItemGID; $cl = Get-MapValue $costed $lg $null
        $unit = if ($cl) { $cl.EffectiveUnitCost } else { $null }
        $d = $i.InspectionDate; $m = Get-MonthKey $d
        if ($sell -gt 0) {
            Add-ToMap $sellableByLine $lg $sell
            $amt = if ($null -ne $unit) { Get-RoundedMoney (-1 * $sell * $unit) } else { $null }
            if ($null -eq $unit) { $costEx.Add((New-PassressException -CheckName 'COGS_REVERSAL_MISSING_COST' -Severity ERROR -AffectedRecord $iid -OrderName $f.OrderName -Classification 'REAL' -RecommendedAction 'Sellable return accepted but the original sale has no cost; reversal value pending the cost.' -RunId $RunId)) }
            $T.COGS_EVENTS.Add([ordered]@{ EventID = 'COGSREV-' + $iid; EventType = 'COGS_REVERSAL'; LineItemGID = $lg; OrderName = $f.OrderName; SKU = $f.SKU; EventDateLocal = $d; EventMonth = $m; Quantity = (-1 * $sell); UnitCost = $unit; Amount = $amt; SourceID = $iid; CostStatus = $(if ($null -eq $amt) { 'MISSING_COST' } else { 'OK' }) })
            $T.INVENTORY_MOVEMENTS.Add([ordered]@{ MovementID = 'MOV-RS-' + $iid; MovementDate = $d; MovementMonth = $m; SKU = $f.SKU; MovementType = 'RETURN_SELLABLE'; Bucket = 'SELLABLE'; Quantity = $sell; UnitCost = $unit; Value = $(if ($null -ne $unit) { Get-RoundedMoney ($sell * $unit) } else { $null }); SourceTable = 'RETURN_INSPECTIONS'; SourceID = $iid })
        }
        if ($dmg -gt 0) {
            Add-ToMap $damagedByLine $lg $dmg
            $T.INVENTORY_MOVEMENTS.Add([ordered]@{ MovementID = 'MOV-RD-' + $iid; MovementDate = $d; MovementMonth = $m; SKU = $f.SKU; MovementType = 'RETURN_DAMAGED'; Bucket = 'DAMAGED'; Quantity = $dmg; UnitCost = 0; Value = 0; SourceTable = 'RETURN_INSPECTIONS'; SourceID = $iid })
        }
        if ($wo -gt 0) {
            Add-ToMap $writeoffByLine $lg $wo
            $T.INVENTORY_MOVEMENTS.Add([ordered]@{ MovementID = 'MOV-RW-' + $iid; MovementDate = $d; MovementMonth = $m; SKU = $f.SKU; MovementType = 'RETURN_WRITE_OFF'; Bucket = 'WRITTEN_OFF'; Quantity = $wo; UnitCost = 0; Value = 0; SourceTable = 'RETURN_INSPECTIONS'; SourceID = $iid })
        }
    }
    foreach ($rid in $returns.Keys) {
        $ret = $returns[$rid]
        if ($ret.Received -and $ret.Inspected -lt $ret.Qty) {
            $invEx.Add((New-PassressException -CheckName 'RETURN_PENDING_INSPECTION' -Severity WARNING -AffectedRecord $rid -OrderName $ret.Fact.OrderName -ExpectedValue $ret.Qty -ActualValue $ret.Inspected -Difference ($ret.Qty - $ret.Inspected) -RecommendedAction 'Units received but not yet inspected/approved: no COGS reversal and no sellable stock until decided.' -RunId $RunId))
        }
    }

    # finalize SALES_COSTED
    foreach ($lg in $costed.Keys) {
        $cl = $costed[$lg]; $s = [int](Get-MapValue $sellableByLine $lg 0)
        $cl.SellableReturnedQty = $s
        if ($null -ne $cl.EffectiveUnitCost) { $cl.COGSReversal = Get-RoundedMoney ($s * $cl.EffectiveUnitCost) } else { $cl.COGSReversal = $(if ($s -gt 0) { $null } else { 0.0 }) }
        if ($null -ne $cl.COGS -and $null -ne $cl.COGSReversal) { $cl.NetCOGS = Get-RoundedMoney ($cl.COGS - $cl.COGSReversal); $cl.GrossProfit = Get-RoundedMoney ([double]$cl.NetRevenue - $cl.NetCOGS) }
        $T.SALES_COSTED.Add($cl)
    }

    # ------------------------------------------------ inventory ledger (other movements)
    $openingSku = @{}
    foreach ($o in @($Inputs.OPENING_INVENTORY)) {
        $sku = [string]$o.SKU; if (Test-Blank $sku) { continue }
        if ($openingSku.ContainsKey($sku)) { $invEx.Add((New-PassressException -CheckName 'DUPLICATE_OPENING_INVENTORY' -Severity ERROR -AffectedRecord $sku -RecommendedAction 'One opening row per SKU. Later row ignored.' -RunId $RunId)); continue }
        if ($null -eq $o.AsOfDate) { $invEx.Add((New-PassressException -CheckName 'OPENING_INVENTORY_DATE_MISSING' -Severity ERROR -AffectedRecord $sku -RecommendedAction 'Enter AsOfDate. Row ignored.' -RunId $RunId)); continue }
        $openingSku[$sku] = $true
        $uc = $o.UnitCost
        if ($null -eq $uc) { $invEx.Add((New-PassressException -CheckName 'OPENING_INVENTORY_COST_MISSING' -Severity WARNING -AffectedRecord $sku -RecommendedAction 'Opening stock has no unit cost; stock value stays blank.' -RunId $RunId)) }
        $sq = [int](Get-Money $o.SellableQty); $dq = [int](Get-Money $o.DamagedQty)
        $T.INVENTORY_MOVEMENTS.Add([ordered]@{ MovementID = 'MOV-OPEN-' + $sku; MovementDate = $o.AsOfDate; MovementMonth = (Get-MonthKey $o.AsOfDate); SKU = $sku; MovementType = 'OPENING'; Bucket = 'SELLABLE'; Quantity = $sq; UnitCost = $uc; Value = $(if ($null -ne $uc) { Get-RoundedMoney ($sq * [double]$uc) } else { $null }); SourceTable = 'OPENING_INVENTORY'; SourceID = $sku })
        if ($dq -ne 0) { $T.INVENTORY_MOVEMENTS.Add([ordered]@{ MovementID = 'MOV-OPEN-D-' + $sku; MovementDate = $o.AsOfDate; MovementMonth = (Get-MonthKey $o.AsOfDate); SKU = $sku; MovementType = 'OPENING'; Bucket = 'DAMAGED'; Quantity = $dq; UnitCost = 0; Value = 0; SourceTable = 'OPENING_INVENTORY'; SourceID = $sku }) }
    }
    foreach ($p in @($Inputs.PRODUCTION)) {
        $id = [string]$p.ProductionID; $st = ([string]$p.Status).ToUpperInvariant(); $q = [int](Get-Money $p.QtyCompleted)
        if ($st -ne 'RECEIVED' -or $q -le 0) { continue }
        if ($null -eq $p.ReceivedDate -or (Test-Blank $p.SKU)) { $invEx.Add((New-PassressException -CheckName 'PRODUCTION_RECEIPT_INCOMPLETE' -Severity ERROR -AffectedRecord $id -RecommendedAction 'RECEIVED production needs SKU and ReceivedDate. Not added to stock.' -RunId $RunId)); continue }
        $uc = $p.UnitProductionCost
        if ($null -eq $uc) { $rec = Get-PassressEffectiveCost -CostBook $book -SKU $p.SKU -Date $p.ReceivedDate; if ($rec) { $uc = $rec.UnitCost } }
        if ($null -eq $uc) { $costEx.Add((New-PassressException -CheckName 'PRODUCTION_COST_MISSING' -Severity ERROR -AffectedRecord $id -RecommendedAction 'No UnitProductionCost and no approved COST_MASTER cost: stock quantity added, value blank.' -RunId $RunId)) }
        $T.INVENTORY_MOVEMENTS.Add([ordered]@{ MovementID = 'MOV-PRD-' + $id; MovementDate = $p.ReceivedDate; MovementMonth = (Get-MonthKey $p.ReceivedDate); SKU = $p.SKU; MovementType = 'PRODUCTION_RECEIPT'; Bucket = 'SELLABLE'; Quantity = $q; UnitCost = $uc; Value = $(if ($null -ne $uc) { Get-RoundedMoney ($q * [double]$uc) } else { $null }); SourceTable = 'PRODUCTION'; SourceID = $id })
    }
    foreach ($p in @($Inputs.PURCHASES)) {
        $id = [string]$p.PurchaseID; $q = [int](Get-Money $p.ReceivedQty)
        if (([string]$p.ItemType).ToUpperInvariant() -ne 'SKU' -or $q -le 0) { continue }
        if ($null -eq $p.ActualDelivery -or (Test-Blank $p.SKUOrMaterial)) { $invEx.Add((New-PassressException -CheckName 'PURCHASE_RECEIPT_INCOMPLETE' -Severity ERROR -AffectedRecord $id -RecommendedAction 'Received SKU purchase needs SKUOrMaterial and ActualDelivery. Not added to stock.' -RunId $RunId)); continue }
        $uc = $p.UnitCost
        $T.INVENTORY_MOVEMENTS.Add([ordered]@{ MovementID = 'MOV-PUR-' + $id; MovementDate = $p.ActualDelivery; MovementMonth = (Get-MonthKey $p.ActualDelivery); SKU = $p.SKUOrMaterial; MovementType = 'PURCHASE_RECEIPT'; Bucket = 'SELLABLE'; Quantity = $q; UnitCost = $uc; Value = $(if ($null -ne $uc) { Get-RoundedMoney ($q * [double]$uc) } else { $null }); SourceTable = 'PURCHASES'; SourceID = $id })
    }
    foreach ($f in $real) {
        $q = [int]$f.QtyShipped; if ($q -le 0 -or (Test-Blank $f.SKU)) { continue }
        $cl = $costed[[string]$f.LineItemGID]; $uc = $cl.EffectiveUnitCost
        $T.INVENTORY_MOVEMENTS.Add([ordered]@{ MovementID = 'MOV-SALE-' + $f.LineItemGID; MovementDate = $f.OrderDateLocal; MovementMonth = $f.OrderMonth; SKU = $f.SKU; MovementType = 'SALE'; Bucket = 'SELLABLE'; Quantity = (-1 * $q); UnitCost = $uc; Value = $(if ($null -ne $uc) { Get-RoundedMoney (-1 * $q * $uc) } else { $null }); SourceTable = 'SALES_FACT'; SourceID = $f.LineItemGID })
    }
    $seenAdj = @{}
    foreach ($a in @($Inputs.INVENTORY_ADJUSTMENTS)) {
        $id = [string]$a.AdjustmentID
        if ((Test-Blank $id) -or $seenAdj.ContainsKey($id)) { $invEx.Add((New-PassressException -CheckName 'ADJUSTMENT_ID_INVALID' -Severity ERROR -AffectedRecord $id -RecommendedAction 'Missing or duplicate AdjustmentID; ignored.' -RunId $RunId)); continue }
        $seenAdj[$id] = $true
        if ((Test-Blank $a.ApprovedBy) -or $null -eq $a.AdjustmentDate -or (Test-Blank $a.SKU) -or $null -eq $a.Quantity) { $invEx.Add((New-PassressException -CheckName 'ADJUSTMENT_INCOMPLETE' -Severity ERROR -AffectedRecord $id -RecommendedAction 'Adjustments need date, SKU, quantity and ApprovedBy. Ignored.' -RunId $RunId)); continue }
        $bucket = ([string]$a.Bucket).ToUpperInvariant(); if ($bucket -ne 'DAMAGED') { $bucket = 'SELLABLE' }
        $q = [int]$a.Quantity; $uc = $null
        if ($bucket -eq 'SELLABLE') { $rec = Get-PassressEffectiveCost -CostBook $book -SKU $a.SKU -Date $a.AdjustmentDate; if ($rec) { $uc = $rec.UnitCost } } else { $uc = 0 }
        $T.INVENTORY_MOVEMENTS.Add([ordered]@{ MovementID = 'MOV-ADJ-' + $id; MovementDate = $a.AdjustmentDate; MovementMonth = (Get-MonthKey $a.AdjustmentDate); SKU = $a.SKU; MovementType = 'ADJUSTMENT'; Bucket = $bucket; Quantity = $q; UnitCost = $uc; Value = $(if ($null -ne $uc) { Get-RoundedMoney ($q * [double]$uc) } else { $null }); SourceTable = 'INVENTORY_ADJUSTMENTS'; SourceID = $id })
    }

    # ------------------------------------------------ INVENTORY per SKU
    $hier = @{}; foreach ($h in @($Inputs.HEIRARCHY)) { if (-not (Test-Blank $h.SKU)) { $hier[[string]$h.SKU] = $h } }
    $shop = @{}; foreach ($v in @($Upstream.RAW_VARIANTS)) { if (-not (Test-Blank $v.SKU) -and $null -ne $v.ShopifyInventoryQty) { Add-ToMap $shop ([string]$v.SKU) ([double]$v.ShopifyInventoryQty) } }
    $names = @{}; foreach ($v in @($Upstream.RAW_VARIANTS)) { if (-not (Test-Blank $v.SKU)) { $names[[string]$v.SKU] = $v.ProductTitle } }
    $skus = @{}
    foreach ($m in $T.INVENTORY_MOVEMENTS) { $skus[[string]$m.SKU] = $true }
    foreach ($k in $hier.Keys) { $skus[$k] = $true }; foreach ($k in $shop.Keys) { $skus[$k] = $true }
    foreach ($sku in @($skus.Keys | Sort-Object)) {
        if (Test-Blank $sku) { continue }
        $mv = @($T.INVENTORY_MOVEMENTS | Where-Object { $_.SKU -eq $sku })
        $sumQ = { param($type, $bucket) $s = 0; foreach ($x in $mv) { if (($null -eq $type -or $x.MovementType -eq $type) -and ($null -eq $bucket -or $x.Bucket -eq $bucket)) { $s += [int]$x.Quantity } }; $s }
        $hasOpening = $openingSku.ContainsKey($sku)
        $closing = & $sumQ $null 'SELLABLE'; $damaged = & $sumQ $null 'DAMAGED'
        $value = 0.0; $valueKnown = $true
        foreach ($x in $mv) { if ($x.Bucket -eq 'SELLABLE') { if ($null -eq $x.Value) { $valueKnown = $false } else { $value += [double]$x.Value } } }
        $cur = Get-PassressEffectiveCost -CostBook $book -SKU $sku -Date (Get-Date).Date
        $reorder = if ($hier.ContainsKey($sku)) { $hier[$sku].ReorderLevel } else { $null }
        $status = 'OK'
        if ($closing -lt 0) {
            $status = 'NEGATIVE'
            $invEx.Add((New-PassressException -CheckName 'NEGATIVE_INVENTORY' -Severity ERROR -AffectedRecord $sku -ExpectedValue '>= 0' -ActualValue $closing -Difference $closing -RecommendedAction 'More units sold than recorded as received/opening. Record opening stock, production receipts or adjustments.' -RunId $RunId))
        } elseif (-not $hasOpening -and $mv.Count -gt 0) { $status = 'INCOMPLETE' }
        elseif ($null -ne $reorder -and $closing -le [int]$reorder) { $status = 'LOW' }
        if (-not $hasOpening -and ($mv.Count -gt 0 -or $shop.ContainsKey($sku))) {
            $invEx.Add((New-PassressException -CheckName 'MISSING_OPENING_INVENTORY' -Severity ERROR -AffectedRecord $sku -RecommendedAction 'Enter the counted opening stock in OPENING_INVENTORY (never assumed zero). Stock figures for this SKU are INCOMPLETE.' -RunId $RunId))
            if ($status -eq 'OK' -or $status -eq 'LOW') { $status = 'INCOMPLETE' }
        }
        if (-not $valueKnown -and $status -ne 'NEGATIVE') { $status = 'INCOMPLETE' }
        if ($hasOpening -and $shop.ContainsKey($sku) -and [int]$shop[$sku] -ne $closing) {
            $invEx.Add((New-PassressException -CheckName 'INVENTORY_QTY_MISMATCH_SHOPIFY' -Severity WARNING -AffectedRecord $sku -ExpectedValue $closing -ActualValue ([int]$shop[$sku]) -Difference ([int]$shop[$sku] - $closing) -RecommendedAction 'Ledger closing stock differs from Shopify stock. Count physically and record an approved adjustment (or fix Shopify).' -RunId $RunId))
        }
        $T.INVENTORY.Add([ordered]@{ SKU = $sku; ProductName = $(if ($hier.ContainsKey($sku) -and $hier[$sku].ProductName) { $hier[$sku].ProductName } else { Get-MapValue $names $sku $null }); OpeningStock = $(if ($hasOpening) { & $sumQ 'OPENING' 'SELLABLE' } else { $null }); ProductionReceived = (& $sumQ 'PRODUCTION_RECEIPT' $null); PurchasesReceived = (& $sumQ 'PURCHASE_RECEIPT' $null); SalesQty = (-1 * (& $sumQ 'SALE' $null)); CustomerReturnsSellable = (& $sumQ 'RETURN_SELLABLE' $null); DamagedReturns = (& $sumQ 'RETURN_DAMAGED' $null); WrittenOffReturns = (& $sumQ 'RETURN_WRITE_OFF' $null); Adjustments = (& $sumQ 'ADJUSTMENT' 'SELLABLE'); ClosingSellable = $closing; DamagedOnHand = $damaged; CurrentUnitCost = $(if ($cur) { $cur.UnitCost } else { $null }); StockValue = $(if ($valueKnown) { Get-RoundedMoney $value } else { $null }); ReorderLevel = $reorder; ShopifyInventoryQty = $(if ($shop.ContainsKey($sku)) { [int]$shop[$sku] } else { $null }); StockStatus = $status })
    }
    # control: sales movements = shipped quantity of REAL lines with SKU
    $shippedReal = 0; foreach ($f in $real) { if (-not (Test-Blank $f.SKU)) { $shippedReal += [int]$f.QtyShipped } }
    $saleMov = 0; foreach ($m in $T.INVENTORY_MOVEMENTS) { if ($m.MovementType -eq 'SALE') { $saleMov += -1 * [int]$m.Quantity } }
    if ($shippedReal -ne $saleMov) { $invEx.Add((New-PassressException -CheckName 'SALES_VS_INVENTORY_MOVEMENTS' -Severity ERROR -AffectedRecord 'ALL' -ExpectedValue $shippedReal -ActualValue $saleMov -Difference ($saleMov - $shippedReal) -RecommendedAction 'Internal control failed: sales quantity and inventory sale movements differ.' -RunId $RunId)) }

    # ------------------------------------------------ refund vs return reconciliation
    $returnedByLine = @{}; foreach ($k in $receivedByLine.Keys) { $returnedByLine[$k] = $receivedByLine[$k] }
    $lineKeys = @{}
    foreach ($f in $facts) { if ([int]$f.QtyRefunded -gt 0 -or [double]$f.RefundAllocated -ne 0 -or $returnedByLine.ContainsKey([string]$f.LineItemGID)) { $lineKeys[[string]$f.LineItemGID] = $f } }
    foreach ($lg in $lineKeys.Keys) {
        $f = $lineKeys[$lg]
        $recv = [int](Get-MapValue $returnedByLine $lg 0); $sell = [int](Get-MapValue $sellableByLine $lg 0); $dmg = [int](Get-MapValue $damagedByLine $lg 0); $wo = [int](Get-MapValue $writeoffByLine $lg 0)
        $pending = [math]::Max(0, $recv - $sell - $dmg - $wo); $refQ = [int]$f.QtyRefunded
        $status = if ($refQ -gt 0 -and $recv -eq 0) { 'REFUND_ONLY' } elseif ($pending -gt 0) { 'PENDING_INSPECTION' } elseif ($refQ -eq 0 -and $recv -gt 0) { 'RETURN_WITHOUT_REFUND' } else { 'RESOLVED' }
        $T.REFUND_RETURN_RECONCILIATION.Add([ordered]@{ LineItemGID = $lg; OrderName = $f.OrderName; SKU = $f.SKU; Classification = $f.Classification; RefundedQty = $refQ; RefundedValue = $f.RefundAllocated; ReceivedQty = $recv; PendingInspectionQty = $pending; SellableQty = $sell; DamagedQty = $dmg; WriteOffQty = $wo; RefundedNotReturnedQty = [math]::Max(0, $refQ - $recv); UnallocatedRefundValue = 0; Status = $status })
    }
    foreach ($ev in @($events | Where-Object { $_.EventType -eq 'REFUND_UNALLOCATED' })) {
        $T.REFUND_RETURN_RECONCILIATION.Add([ordered]@{ LineItemGID = $null; OrderName = $ev.OrderName; SKU = $null; Classification = $ev.Classification; RefundedQty = 0; RefundedValue = 0; ReceivedQty = 0; PendingInspectionQty = 0; SellableQty = 0; DamagedQty = 0; WriteOffQty = 0; RefundedNotReturnedQty = 0; UnallocatedRefundValue = (-1 * [double]$ev.NetAmount); Status = 'UNALLOCATED' })
    }

    $tables = @{}; foreach ($k in $T.Keys) { $tables[$k] = $T[$k].ToArray() }
    $stateObj = New-Object psobject; foreach ($k in $book.State.Keys) { $stateObj | Add-Member -NotePropertyName $k -NotePropertyValue $book.State[$k] }
    return [pscustomobject]@{ Tables = $tables; CostExceptions = (Get-UniqueExceptions $costEx.ToArray()); InventoryExceptions = (Get-UniqueExceptions $invEx.ToArray()); CostState = $stateObj }
}
