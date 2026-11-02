# Offline regression scenarios. Expected values are derived by hand from the approved Phase 2 rules - not from engine output.
# Each scenario: Name, Rule (what it proves), Orders, Inputs (per input table), Assertions, optional Rerun / PreviousCostState.

function Get-PassressTestScenarios {
    param([Parameter(Mandatory)][string]$FixtureFolder)
    $S = @()
    $O = '2026-10-05T10:00:00Z'   # 13:00 Cairo, October

    # ---------------------------------------------------------------- S01 test orders #1001-#1009 (Phase 1 evidence)
    $fixture = Get-Content -LiteralPath (Join-Path $FixtureFolder 'orders.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $ids = [ordered]@{ '#1001' = '12203059675500'; '#1002' = '18928905683308'; '#1003' = '18928925802860'; '#1004' = '18947365962092'; '#1005' = '18953305129324'; '#1006' = '18953478603116'; '#1007' = '18968573641068'; '#1008' = '18971894907244'; '#1009' = '18981663048044' }
    $cls = @($ids.Keys | ForEach-Object { @{ OrderGID = ('gid://shopify/Order/' + $ids[$_]); OrderName = $_; Classification = 'TEST'; Reason = 'Approved: test orders'; EffectiveDate = [datetime]'2026-11-01' } })
    $sleeve = 'gid://shopify/LineItem/50857802596716'; $blazer = 'gid://shopify/LineItem/50857802629484'
    $S += @{ Name = 'S01_TEST_ORDERS_1001_1009'; Rule = 'Test orders stay in raw data, are excluded everywhere else; #1008/#1009 refund evidence preserved; no allocation by matching amounts.'
        Orders = @($fixture); Inputs = @{ ORDER_CLASSIFICATION = $cls }
        Assertions = @(
            (A 'S01-01' 'All 9 test orders retained in RAW_ORDERS' 'RAW_ORDERS' @{} 'count' -Expected 9),
            (A 'S01-02' 'No line is reportable' 'SALES_FACT' @{ IsReportable = $true } 'count' -Expected 0),
            (A 'S01-03' 'All 15 lines classified TEST (MANUAL)' 'SALES_FACT' @{ Classification = 'TEST'; ClassificationSource = 'MANUAL' } 'count' -Expected 15),
            (A 'S01-04' 'TEST_ORDER_EXCLUDED visible for each order' 'EXCEPTIONS' @{ CheckName = 'TEST_ORDER_EXCLUDED' } 'count' -Expected 9),
            (A 'S01-05' '#1008 refund 1 (Napoleon 2,199) is line-allocated' 'REFUND_RECONCILIATION' @{ RefundGID = 'gid://shopify/Refund/1114412974444' } 'value' 'Status' 'ALLOCATED'),
            (A 'S01-06' '#1008 refund 2 (2,250) stays UNALLOCATED' 'REFUND_RECONCILIATION' @{ RefundGID = 'gid://shopify/Refund/1115061617004' } 'value' 'Status' 'UNALLOCATED'),
            (A 'S01-07' '#1008 unallocated amount = 2,250' 'REFUND_RECONCILIATION' @{ RefundGID = 'gid://shopify/Refund/1115061617004' } 'value' 'Unallocated' 2250),
            (A 'S01-08' 'HIDEOUT sleeve NOT given the 2,250 refund' 'SALES_FACT' @{ LineItemGID = $sleeve } 'value' 'RefundAllocated' 0),
            (A 'S01-09' 'Napoleon blazer refund allocated 2,199' 'SALES_FACT' @{ LineItemGID = $blazer } 'value' 'RefundAllocated' 2199),
            (A 'S01-10' 'No refund event for the sleeve line' 'REVENUE_EVENTS' @{ LineItemGID = $sleeve; EventType = 'REFUND_LINE' } 'count' -Expected 0),
            (A 'S01-11' 'Exception raised for #1008 refund without line items' 'EXCEPTIONS' @{ CheckName = 'REFUND_WITHOUT_LINE_ITEM'; AffectedRecord = 'gid://shopify/Refund/1115061617004' } 'count' -Expected 1),
            (A 'S01-12' '#1009 3,150 refund kept UNALLOCATED' 'REFUND_RECONCILIATION' @{ OrderName = '#1009' } 'value' 'Unallocated' 3150),
            (A 'S01-13' 'Nothing posted to the journal' 'JOURNAL_ENTRIES' @{} 'count' -Expected 0),
            (A 'S01-14' 'No P&L rows (no REAL activity)' 'PROFIT_AND_LOSS' @{} 'count' -Expected 0),
            (A 'S01-15' 'No KPI rows from test orders' 'KPI_MONTHLY' @{} 'count' -Expected 0),
            (A 'S01-16' 'No operational SALES rows' 'SALES' @{} 'count' -Expected 0),
            (A 'S01-17' 'No test lines in SALES_COSTED' 'SALES_COSTED' @{} 'count' -Expected 0),
            (A 'S01-18' '#1005 refunds reconcile (no mismatch)' 'EXCEPTIONS' @{ CheckName = 'REFUND_AMOUNT_MISMATCH'; OrderName = '#1005' } 'count' -Expected 0),
            (A 'S01-19' '#1003 voided: cancellation reverses sleeve line' 'SALES_FACT' @{ LineItemGID = 'gid://shopify/LineItem/FIXTURE-1003-1' } 'value' 'NetRevenue' 0),
            (A 'S01-20' 'Missing SKU flagged (INFO for test orders)' 'EXCEPTIONS' @{ CheckName = 'MISSING_SKU'; Severity = 'INFO' } 'count' -Expected 4)
        ) }

    # ---------------------------------------------------------------- S02 new REAL order defaults to REAL
    $i = New-BaseInputs
    $S += @{ Name = 'S02_NEW_ORDER_DEFAULT_REAL'; Rule = 'A new order not in ORDER_CLASSIFICATION defaults to REAL and flows to revenue, COGS, stock, statements and KPIs.'
        Orders = @(New-TOrder -Id 2001 -Name '#2001' -Created $O -Lines @(@{ Id = 'L1'; Sku = 'SKU-A'; Qty = 1; Price = 2500 }) -Received 2500); Inputs = $i
        Assertions = @(
            (A 'S02-01' 'Classified REAL by DEFAULT' 'SALES_FACT' @{ OrderName = '#2001' } 'value' 'ClassificationSource' 'DEFAULT'),
            (A 'S02-02' 'Reportable' 'SALES_FACT' @{ OrderName = '#2001' } 'value' 'IsReportable' $true),
            (A 'S02-03' 'Net revenue Oct = 2,500' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Net Revenue' } 'value' 'Amount' 2500),
            (A 'S02-04' 'COGS Oct = 1,000' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Cost of Goods Sold' } 'value' 'Amount' -1000),
            (A 'S02-05' 'Gross profit Oct = 1,500' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Gross Profit' } 'value' 'Amount' 1500),
            (A 'S02-06' 'Stock 5 -> 4' 'INVENTORY' @{ SKU = 'SKU-A' } 'value' 'ClosingSellable' 4),
            (A 'S02-07' 'Stock value 4,000' 'INVENTORY' @{ SKU = 'SKU-A' } 'value' 'StockValue' 4000),
            (ASum 'S02-08' 'Journal debits = credits' 'JOURNAL_ENTRIES' 'Debit' 'Credit'),
            (A 'S02-09' 'Balance sheet balances (Oct)' 'BALANCE_SHEET' @{ Month = '2026-10'; Section = 'CHECK' } 'value' 'Amount' 0),
            (A 'S02-10' 'Cash = opening 5,000 (COD not yet remitted)' 'BALANCE_SHEET' @{ Month = '2026-10'; LineItem = 'Cash & Bank' } 'value' 'Amount' 5000),
            (A 'S02-11' 'COD clearing = 2,500 (received in Shopify, not remitted)' 'BALANCE_SHEET' @{ Month = '2026-10'; LineItem = 'COD / Payment Clearing (courier, gateway)' } 'value' 'Amount' 2500),
            (A 'S02-12' 'Cash flow reconciles to BS' 'CASH_FLOW' @{ Month = '2026-10'; LineItem = 'Check: Closing Cash - Balance Sheet Cash' } 'value' 'Amount' 0),
            (A 'S02-13' 'KPI orders = 1' 'KPI_MONTHLY' @{ Month = '2026-10' } 'value' 'Orders' 1),
            (A 'S02-14' 'KPI AOV = 2,500' 'KPI_MONTHLY' @{ Month = '2026-10' } 'value' 'AverageOrderValue' 2500),
            (A 'S02-15' 'Opening balances present -> no missing-opening exception' 'FINANCE_EXCEPTIONS' @{ CheckName = 'MISSING_OPENING_BALANCES' } 'count' -Expected 0),
            (A 'S02-16' 'Opening inventory = GL 1300' 'FINANCE_EXCEPTIONS' @{ CheckName = 'OPENING_INVENTORY_GL_MISMATCH' } 'count' -Expected 0),
            (A 'S02-17' 'Unremitted COD flagged' 'FINANCE_EXCEPTIONS' @{ CheckName = 'UNRECONCILED_COD_REMITTANCE' } 'count' -Expected 1)
        ) }

    # ---------------------------------------------------------------- S03 A/B/C (mandatory example: price 2,500, cost 1,000, full refund)
    $fullRefund = @(@{ Id = 'R1'; At = '2026-10-10T10:00:00Z'; Amount = 2500; Lines = @(@{ Id = 'RL1'; Line = 'L1'; Qty = 1; Subtotal = 2500; Restock = 'RETURN' }) })
    $mk = { param($id) New-TOrder -Id $id -Name ('#' + $id) -Created $O -Lines @(@{ Id = 'L1'; Sku = 'SKU-A'; Qty = 1; Price = 2500 }) -Received 2500 -Refunds $fullRefund }
    $S += @{ Name = 'S03A_REFUND_NOT_RETURNED'; Rule = 'Case A: refund, product not returned (Shopify says restockType RETURN - ignored): revenue -2,500, COGS stays 1,000, stock unchanged.'
        Orders = @(& $mk 3101); Inputs = (New-BaseInputs)
        Assertions = @(
            (A 'S03A-01' 'Refund recognised -2,500' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Refunds (line-item allocated)' } 'value' 'Amount' -2500),
            (A 'S03A-02' 'Net revenue 0 (2,500 - 2,500)' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Net Revenue' } 'value' 'Amount' 0),
            (A 'S03A-03' 'COGS remains 1,000' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Cost of Goods Sold' } 'value' 'Amount' -1000),
            (A 'S03A-04' 'Stock does not increase (5 -> 4)' 'INVENTORY' @{ SKU = 'SKU-A' } 'value' 'ClosingSellable' 4),
            (A 'S03A-05' 'No COGS reversal' 'COGS_EVENTS' @{ EventType = 'COGS_REVERSAL' } 'count' -Expected 0),
            (A 'S03A-06' 'Reconciliation: REFUND_ONLY' 'REFUND_RETURN_RECONCILIATION' @{ LineItemGID = (LG 3101 'L1') } 'value' 'Status' 'REFUND_ONLY'),
            (A 'S03A-07' 'Refunded-not-returned qty = 1' 'REFUND_RETURN_RECONCILIATION' @{ LineItemGID = (LG 3101 'L1') } 'value' 'RefundedNotReturnedQty' 1)
        ) }
    $iB = New-BaseInputs
    $iB.RETURNS = @(@{ ReturnID = 'RET-1'; OrderGID = (OG 3102); OrderName = '#3102'; LineItemGID = (LG 3102 'L1'); SKU = 'SKU-A'; Quantity = 1; PhysicalReturnStatus = 'RECEIVED'; ReceivedDate = [datetime]'2026-10-12' })
    $iB.RETURN_INSPECTIONS = @(@{ InspectionID = 'INS-1'; ReturnID = 'RET-1'; InspectionDate = [datetime]'2026-10-13'; InspectionStatus = 'COMPLETE'; SellableQty = 1; DamagedQty = 0; WriteOffQty = 0; ApprovedBy = 'Ops' })
    $S += @{ Name = 'S03B_REFUND_RETURNED_SELLABLE'; Rule = 'Case B: refund + return passes inspection: revenue -2,500, reverse 1,000 COGS, +1 sellable unit at 1,000.'
        Orders = @(& $mk 3102); Inputs = $iB
        Assertions = @(
            (A 'S03B-01' 'Net revenue 0' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Net Revenue' } 'value' 'Amount' 0),
            (A 'S03B-02' 'COGS reversal -1,000' 'COGS_EVENTS' @{ EventType = 'COGS_REVERSAL' } 'value' 'Amount' -1000),
            (A 'S03B-03' 'Net COGS in P&L = 0' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Cost of Goods Sold' } 'value' 'Amount' 0),
            (A 'S03B-04' 'Stock back to 5' 'INVENTORY' @{ SKU = 'SKU-A' } 'value' 'ClosingSellable' 5),
            (A 'S03B-05' 'Returned unit valued at 1,000' 'INVENTORY_MOVEMENTS' @{ MovementType = 'RETURN_SELLABLE' } 'value' 'Value' 1000),
            (A 'S03B-06' 'Stock value 5,000' 'INVENTORY' @{ SKU = 'SKU-A' } 'value' 'StockValue' 5000),
            (A 'S03B-07' 'Reconciliation RESOLVED' 'REFUND_RETURN_RECONCILIATION' @{ LineItemGID = (LG 3102 'L1') } 'value' 'Status' 'RESOLVED'),
            (ASum 'S03B-08' 'Journal balanced' 'JOURNAL_ENTRIES' 'Debit' 'Credit')
        ) }
    $iC = New-BaseInputs
    $iC.RETURNS = @(@{ ReturnID = 'RET-1'; OrderGID = (OG 3103); OrderName = '#3103'; LineItemGID = (LG 3103 'L1'); SKU = 'SKU-A'; Quantity = 1; PhysicalReturnStatus = 'CLOSED'; ReceivedDate = [datetime]'2026-10-12' })
    $iC.RETURN_INSPECTIONS = @(@{ InspectionID = 'INS-1'; ReturnID = 'RET-1'; InspectionDate = [datetime]'2026-10-13'; InspectionStatus = 'COMPLETE'; SellableQty = 0; DamagedQty = 1; WriteOffQty = 0; ApprovedBy = 'Ops' })
    $S += @{ Name = 'S03C_REFUND_RETURNED_DAMAGED'; Rule = 'Case C: refund + damaged return: revenue -2,500, no COGS reversal, no sellable stock, damaged unit tracked separately.'
        Orders = @(& $mk 3103); Inputs = $iC
        Assertions = @(
            (A 'S03C-01' 'Net revenue 0' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Net Revenue' } 'value' 'Amount' 0),
            (A 'S03C-02' 'COGS stays 1,000' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Cost of Goods Sold' } 'value' 'Amount' -1000),
            (A 'S03C-03' 'No COGS reversal' 'COGS_EVENTS' @{ EventType = 'COGS_REVERSAL' } 'count' -Expected 0),
            (A 'S03C-04' 'Sellable stock not increased (4)' 'INVENTORY' @{ SKU = 'SKU-A' } 'value' 'ClosingSellable' 4),
            (A 'S03C-05' 'Damaged on hand = 1' 'INVENTORY' @{ SKU = 'SKU-A' } 'value' 'DamagedOnHand' 1),
            (A 'S03C-06' 'Damaged movement at zero value' 'INVENTORY_MOVEMENTS' @{ MovementType = 'RETURN_DAMAGED' } 'value' 'Value' 0)
        ) }

    # ---------------------------------------------------------------- S04 pending inspection / unapproved inspection
    $i4 = New-BaseInputs
    $i4.RETURNS = @(
        @{ ReturnID = 'RET-1'; OrderGID = (OG 3201); LineItemGID = (LG 3201 'L1'); SKU = 'SKU-A'; Quantity = 1; PhysicalReturnStatus = 'INSPECTION_PENDING'; ReceivedDate = [datetime]'2026-10-12' },
        @{ ReturnID = 'RET-2'; OrderGID = (OG 3202); LineItemGID = (LG 3202 'L1'); SKU = 'SKU-A'; Quantity = 1; PhysicalReturnStatus = 'RECEIVED'; ReceivedDate = [datetime]'2026-10-12' })
    $i4.RETURN_INSPECTIONS = @(@{ InspectionID = 'INS-2'; ReturnID = 'RET-2'; InspectionDate = [datetime]'2026-10-13'; InspectionStatus = 'COMPLETE'; SellableQty = 1; ApprovedBy = '' })
    $S += @{ Name = 'S04_PENDING_AND_UNAPPROVED_INSPECTION'; Rule = 'Received but not inspected, or inspected without approval: no COGS reversal, no sellable stock.'
        Orders = @((& $mk 3201), (& $mk 3202)); Inputs = $i4
        Assertions = @(
            (A 'S04-01' 'No COGS reversal' 'COGS_EVENTS' @{ EventType = 'COGS_REVERSAL' } 'count' -Expected 0),
            (A 'S04-02' 'Stock 5 - 2 sold = 3 (nothing added back)' 'INVENTORY' @{ SKU = 'SKU-A' } 'value' 'ClosingSellable' 3),
            (A 'S04-03' 'Pending inspection flagged (both)' 'INVENTORY_EXCEPTIONS' @{ CheckName = 'RETURN_PENDING_INSPECTION' } 'count' -Expected 2),
            (A 'S04-04' 'Unapproved COMPLETE inspection flagged' 'INVENTORY_EXCEPTIONS' @{ CheckName = 'INSPECTION_NOT_APPROVED' } 'count' -Expected 1),
            (A 'S04-05' 'COGS 2,000 kept' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Cost of Goods Sold' } 'value' 'Amount' -2000)
        ) }

    # ---------------------------------------------------------------- S05 partial refund, no return
    $S += @{ Name = 'S05_PARTIAL_REFUND_NO_RETURN'; Rule = 'Partial quantity refund without return reduces revenue only.'
        Orders = @(New-TOrder -Id 3301 -Name '#3301' -Created $O -Lines @(@{ Id = 'L1'; Sku = 'SKU-A'; Qty = 2; Price = 2500 }) -Received 5000 -Refunds @(@{ Id = 'R1'; At = '2026-10-10T10:00:00Z'; Amount = 2500; Lines = @(@{ Id = 'RL1'; Line = 'L1'; Qty = 1; Subtotal = 2500; Restock = 'NO_RESTOCK' }) })); Inputs = (New-BaseInputs)
        Assertions = @(
            (A 'S05-01' 'Line net revenue 2,500' 'SALES_FACT' @{ OrderName = '#3301' } 'value' 'NetRevenue' 2500),
            (A 'S05-02' 'Refunded qty 1' 'SALES_FACT' @{ OrderName = '#3301' } 'value' 'QtyRefunded' 1),
            (A 'S05-03' 'COGS 2,000 kept' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Cost of Goods Sold' } 'value' 'Amount' -2000),
            (A 'S05-04' 'Stock 5 -> 3' 'INVENTORY' @{ SKU = 'SKU-A' } 'value' 'ClosingSellable' 3)
        ) }

    # ---------------------------------------------------------------- S06 partial physical return
    $i6 = New-BaseInputs
    $i6.RETURNS = @(@{ ReturnID = 'RET-1'; OrderGID = (OG 3401); LineItemGID = (LG 3401 'L1'); SKU = 'SKU-A'; Quantity = 2; PhysicalReturnStatus = 'CLOSED'; ReceivedDate = [datetime]'2026-10-12' })
    $i6.RETURN_INSPECTIONS = @(@{ InspectionID = 'INS-1'; ReturnID = 'RET-1'; InspectionDate = [datetime]'2026-10-13'; InspectionStatus = 'COMPLETE'; SellableQty = 1; DamagedQty = 1; WriteOffQty = 0; ApprovedBy = 'Ops' })
    $S += @{ Name = 'S06_PARTIAL_PHYSICAL_RETURN'; Rule = '3 sold + refunded, 2 returned: 1 sellable, 1 damaged -> reverse COGS for 1 unit only.'
        Orders = @(New-TOrder -Id 3401 -Name '#3401' -Created $O -Lines @(@{ Id = 'L1'; Sku = 'SKU-A'; Qty = 3; Price = 2500 }) -Received 7500 -Refunds @(@{ Id = 'R1'; At = '2026-10-10T10:00:00Z'; Amount = 7500; Lines = @(@{ Id = 'RL1'; Line = 'L1'; Qty = 3; Subtotal = 7500; Restock = 'RETURN' }) })); Inputs = $i6
        Assertions = @(
            (A 'S06-01' 'One reversal of -1,000' 'COGS_EVENTS' @{ EventType = 'COGS_REVERSAL' } 'sum' 'Amount' -1000),
            (A 'S06-02' 'P&L COGS 3,000 - 1,000 = 2,000' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Cost of Goods Sold' } 'value' 'Amount' -2000),
            (A 'S06-03' 'Stock 5 - 3 + 1 = 3' 'INVENTORY' @{ SKU = 'SKU-A' } 'value' 'ClosingSellable' 3),
            (A 'S06-04' 'Damaged 1' 'INVENTORY' @{ SKU = 'SKU-A' } 'value' 'DamagedOnHand' 1),
            (A 'S06-05' 'Refunded but not returned = 1' 'REFUND_RETURN_RECONCILIATION' @{ LineItemGID = (LG 3401 'L1') } 'value' 'RefundedNotReturnedQty' 1),
            (A 'S06-06' 'Net revenue 0' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Net Revenue' } 'value' 'Amount' 0)
        ) }

    # ---------------------------------------------------------------- S07 duplicates + idempotent rerun
    $dupOrder = New-TOrder -Id 3501 -Name '#3501' -Created $O -Lines @(@{ Id = 'L1'; Sku = 'SKU-A'; Qty = 1; Price = 2500 }) -Received 2500 -Refunds $fullRefund
    $dupOrder.refunds = @($dupOrder.refunds) + @($dupOrder.refunds)    # same refund delivered twice by the API
    $i7 = New-BaseInputs
    $ret = @{ ReturnID = 'RET-1'; OrderGID = (OG 3501); LineItemGID = (LG 3501 'L1'); SKU = 'SKU-A'; Quantity = 1; PhysicalReturnStatus = 'RECEIVED'; ReceivedDate = [datetime]'2026-10-12' }
    $ins = @{ InspectionID = 'INS-1'; ReturnID = 'RET-1'; InspectionDate = [datetime]'2026-10-13'; InspectionStatus = 'COMPLETE'; SellableQty = 1; ApprovedBy = 'Ops' }
    $i7.RETURNS = @($ret, $ret); $i7.RETURN_INSPECTIONS = @($ins, $ins)
    $S += @{ Name = 'S07_DUPLICATES_IDEMPOTENT'; Rule = 'Duplicate refund/return/inspection records and a repeated refresh never duplicate refunds, stock or COGS reversals.'; Rerun = $true
        Orders = @($dupOrder, $dupOrder); Inputs = $i7
        Assertions = @(
            (A 'S07-01' 'Order counted once' 'RAW_ORDERS' @{} 'count' -Expected 1),
            (A 'S07-02' 'Refund recognised once (-2,500)' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Refunds (line-item allocated)' } 'value' 'Amount' -2500),
            (A 'S07-03' 'One COGS reversal' 'COGS_EVENTS' @{ EventType = 'COGS_REVERSAL' } 'count' -Expected 1),
            (A 'S07-04' 'One sellable return movement' 'INVENTORY_MOVEMENTS' @{ MovementType = 'RETURN_SELLABLE' } 'count' -Expected 1),
            (A 'S07-05' 'Stock 5 (not 6)' 'INVENTORY' @{ SKU = 'SKU-A' } 'value' 'ClosingSellable' 5),
            (A 'S07-06' 'Duplicate inspection flagged' 'INVENTORY_EXCEPTIONS' @{ CheckName = 'DUPLICATE_INSPECTION' } 'count' -Expected 1),
            (A 'S07-07' 'Duplicate return flagged' 'INVENTORY_EXCEPTIONS' @{ CheckName = 'DUPLICATE_RETURN_ID' } 'count' -Expected 1),
            (A 'S07-08' 'Duplicate order flagged' 'EXCEPTIONS' @{ CheckName = 'DUPLICATE_ORDER' } 'count' -Expected 1)
        ) }

    # ---------------------------------------------------------------- S08 refund recognised in the refund month
    $S += @{ Name = 'S08_REFUND_MONTH'; Rule = 'Sale in September, refund in October: September keeps the sale, October carries the refund.'
        Orders = @(New-TOrder -Id 3601 -Name '#3601' -Created '2026-09-28T10:00:00Z' -Lines @(@{ Id = 'L1'; Sku = 'SKU-A'; Qty = 1; Price = 2500 }) -Received 2500 -Refunds @(@{ Id = 'R1'; At = '2026-10-03T10:00:00Z'; Amount = 2500; Lines = @(@{ Id = 'RL1'; Line = 'L1'; Qty = 1; Subtotal = 2500; Restock = 'NO_RESTOCK' }) })); Inputs = (New-BaseInputs)
        Assertions = @(
            (A 'S08-01' 'September net revenue 2,500' 'PROFIT_AND_LOSS' @{ Month = '2026-09'; LineItem = 'Net Revenue' } 'value' 'Amount' 2500),
            (A 'S08-02' 'October net revenue -2,500' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Net Revenue' } 'value' 'Amount' -2500),
            (A 'S08-03' 'Refund event in 2026-10' 'REVENUE_EVENTS' @{ EventType = 'REFUND_LINE'; EventMonth = '2026-10' } 'count' -Expected 1),
            (A 'S08-04' 'September COGS 1,000 (sale month)' 'PROFIT_AND_LOSS' @{ Month = '2026-09'; LineItem = 'Cost of Goods Sold' } 'value' 'Amount' -1000),
            (A 'S08-05' 'October COGS 0' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Cost of Goods Sold' } 'value' 'Amount' 0)
        ) }

    # ---------------------------------------------------------------- S09 partner capital
    $de = @(
        @{ TransactionID = 'TXN-1'; TransactionDate = [datetime]'2026-10-01'; TransactionType = 'CAPITAL_DEPOSIT'; Amount = 10000; PaymentAccount = '1010'; PaidBy = 'Partner A'; Description = 'Capital deposit' },
        @{ TransactionID = 'TXN-2'; TransactionDate = [datetime]'2026-10-02'; TransactionType = 'EXPENSE'; Category = 'MARKETING'; Amount = 1500; PaymentSource = 'PARTNER_PERSONAL'; PaidBy = 'Partner B'; Description = 'Meta ads paid on personal card' },
        @{ TransactionID = 'TXN-3'; TransactionDate = [datetime]'2026-10-03'; TransactionType = 'EXPENSE'; Category = 'SHIPPING & DELIVERY'; Amount = 500; PaymentSource = 'COMPANY'; PaymentAccount = '1010'; Description = 'Courier' },
        @{ TransactionID = 'TXN-4'; TransactionDate = [datetime]'2026-10-04'; TransactionType = 'PRODUCTION_PAYMENT'; Amount = 3000; PaymentSource = 'COMPANY'; PaymentAccount = '1010'; Description = 'Workshop deposit' })
    $S += @{ Name = 'S09_PARTNER_CAPITAL'; Rule = 'Cash deposit: Dr cash / Cr capital. Partner-paid expense: Dr expense / Cr capital contribution, no company cash. Production payment is inventory, not COGS. No opening balances invented.'
        Orders = @(); Inputs = @{ DATA_ENTRY = $de }
        Assertions = @(
            (A 'S09-01' 'Cash = 10,000 - 500 - 3,000 = 6,500' 'BALANCE_SHEET' @{ Month = '2026-10'; LineItem = 'Cash & Bank' } 'value' 'Amount' 6500),
            (A 'S09-02' 'Capital deposits 10,000' 'BALANCE_SHEET' @{ Month = '2026-10'; LineItem = 'Partner Capital - Cash Deposits (Paid-Up)' } 'value' 'Amount' 10000),
            (A 'S09-03' 'Capital paid personally 1,500' 'BALANCE_SHEET' @{ Month = '2026-10'; LineItem = 'Partner Capital - Company Costs Paid Personally' } 'value' 'Amount' 1500),
            (A 'S09-04' 'Production payment held as inventory/WIP 3,000' 'BALANCE_SHEET' @{ Month = '2026-10'; LineItem = 'Inventory - Materials, WIP & Advances' } 'value' 'Amount' 3000),
            (A 'S09-05' 'Balance sheet balances' 'BALANCE_SHEET' @{ Month = '2026-10'; Section = 'CHECK' } 'value' 'Amount' 0),
            (A 'S09-06' 'Marketing expense 1,500' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Marketing' } 'value' 'Amount' -1500),
            (A 'S09-07' 'COGS 0 (production not expensed)' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Cost of Goods Sold' } 'value' 'Amount' 0),
            (A 'S09-08' 'Net profit -2,000' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Net Profit' } 'value' 'Amount' -2000),
            (A 'S09-09' 'Owner deposits in cash flow 10,000' 'CASH_FLOW' @{ Month = '2026-10'; LineItem = 'Owner capital deposits' } 'value' 'Amount' 10000),
            (A 'S09-10' 'Operating expenses paid -500 (partner-paid 1,500 is not company cash)' 'CASH_FLOW' @{ Month = '2026-10'; LineItem = 'Operating expenses paid' } 'value' 'Amount' -500),
            (A 'S09-11' 'Cash flow reconciles' 'CASH_FLOW' @{ Month = '2026-10'; LineItem = 'Check: Closing Cash - Balance Sheet Cash' } 'value' 'Amount' 0),
            (A 'S09-12' 'Two capital contributions listed' 'CAPITAL_CONTRIBUTIONS' @{} 'count' -Expected 2),
            (A 'S09-13' 'Missing opening balances flagged' 'FINANCE_EXCEPTIONS' @{ CheckName = 'MISSING_OPENING_BALANCES' } 'count' -Expected 1),
            (A 'S09-14' 'Balance sheet marked INCOMPLETE' 'BALANCE_SHEET' @{ Month = '2026-10'; LineItem = 'TOTAL ASSETS' } 'value' 'Status' 'INCOMPLETE'),
            (A 'S09-15' 'No double-count warning' 'FINANCE_EXCEPTIONS' @{ CheckName = 'POSSIBLE_DOUBLE_COUNT_CAPITAL' } 'count' -Expected 0),
            (ASum 'S09-16' 'Journal balanced' 'JOURNAL_ENTRIES' 'Debit' 'Credit')
        ) }

    # ---------------------------------------------------------------- S10 double count warning
    $S += @{ Name = 'S10_CAPITAL_DOUBLE_COUNT_WARNING'; Rule = 'Same partner, same amount, recorded as deposit and as paid-personally within 3 days -> warning.'
        Orders = @(); Inputs = @{ DATA_ENTRY = @(
            @{ TransactionID = 'TXN-1'; TransactionDate = [datetime]'2026-10-01'; TransactionType = 'CAPITAL_DEPOSIT'; Amount = 2000; PaymentAccount = '1010'; PaidBy = 'Partner A' },
            @{ TransactionID = 'TXN-2'; TransactionDate = [datetime]'2026-10-01'; TransactionType = 'EXPENSE'; Category = 'PACKAGING'; Amount = 2000; PaymentSource = 'PARTNER_PERSONAL'; PaidBy = 'Partner A' }) }
        Assertions = @(
            (A 'S10-01' 'Possible double count flagged' 'FINANCE_EXCEPTIONS' @{ CheckName = 'POSSIBLE_DOUBLE_COUNT_CAPITAL' } 'count' -Expected 1),
            (A 'S10-02' 'Packaging classification flagged as unconfirmed' 'FINANCE_EXCEPTIONS' @{ CheckName = 'EXPENSE_CLASSIFICATION_UNCONFIRMED' } 'count' -Expected 1)
        ) }

    # ---------------------------------------------------------------- S11 missing cost / missing SKU
    $S += @{ Name = 'S11_MISSING_COST_AND_SKU'; Rule = 'Missing cost or SKU: line stays visible, COGS blank (never zero), exception raised, month INCOMPLETE.'
        Orders = @(New-TOrder -Id 3701 -Name '#3701' -Created $O -Lines @(@{ Id = 'L1'; Sku = 'SKU-B'; Qty = 1; Price = 2000 }, @{ Id = 'L2'; Sku = $null; Qty = 1; Price = 1000 }) -Received 3000); Inputs = (New-BaseInputs)
        Assertions = @(
            (A 'S11-01' 'SKU-B line MISSING_COST' 'SALES_COSTED' @{ LineItemGID = (LG 3701 'L1') } 'value' 'CostStatus' 'MISSING_COST'),
            (A 'S11-02' 'COGS blank, not 0' 'SALES_COSTED' @{ LineItemGID = (LG 3701 'L1') } 'value' 'COGS' $null),
            (A 'S11-03' 'No-SKU line MISSING_SKU' 'SALES_COSTED' @{ LineItemGID = (LG 3701 'L2') } 'value' 'CostStatus' 'MISSING_SKU'),
            (A 'S11-04' 'Missing cost exception' 'COST_EXCEPTIONS' @{ CheckName = 'MISSING_EFFECTIVE_COST' } 'count' -Expected 1),
            (A 'S11-05' 'Missing SKU exception (ERROR for REAL)' 'EXCEPTIONS' @{ CheckName = 'MISSING_SKU'; Severity = 'ERROR' } 'count' -Expected 1),
            (A 'S11-06' 'October P&L INCOMPLETE' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Net Profit' } 'value' 'Status' 'INCOMPLETE'),
            (A 'S11-07' 'Cost coverage 0%' 'KPI_MONTHLY' @{ Month = '2026-10' } 'value' 'CostCoveragePct' 0),
            (A 'S11-08' 'Order profitability flagged MISSING_COST' 'ORDER_PROFITABILITY' @{ OrderName = '#3701' } 'value' 'DataStatus' 'MISSING_COST'),
            (A 'S11-09' 'SKU-B opening stock missing flagged' 'INVENTORY_EXCEPTIONS' @{ CheckName = 'MISSING_OPENING_INVENTORY'; AffectedRecord = 'SKU-B' } 'count' -Expected 1),
            (A 'S11-10' 'Dashboard warns about cost coverage' 'EXECUTIVE_DASHBOARD' @{ Metric = 'Gross Profit'; Period = 'LATEST_MONTH' } 'value' 'DataStatus' 'INCOMPLETE')
        ) }

    # ---------------------------------------------------------------- S12 missing funding classification
    $S += @{ Name = 'S12_MISSING_FUNDING_CLASSIFICATION'; Rule = 'Expense without PaymentSource is not posted and is flagged; month INCOMPLETE.'
        Orders = @(); Inputs = @{ DATA_ENTRY = @(@{ TransactionID = 'TXN-9'; TransactionDate = [datetime]'2026-10-08'; TransactionType = 'EXPENSE'; Category = 'MARKETING'; Amount = 800; PaidBy = 'Partner A' }) }
        Assertions = @(
            (A 'S12-01' 'Exception raised' 'FINANCE_EXCEPTIONS' @{ CheckName = 'MISSING_PARTNER_FUNDING_CLASSIFICATION'; AffectedRecord = 'TXN-9' } 'count' -Expected 1),
            (A 'S12-02' 'Not posted' 'JOURNAL_ENTRIES' @{ SourceID = 'TXN-9' } 'count' -Expected 0),
            (A 'S12-03' 'October shown INCOMPLETE' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Net Profit' } 'value' 'Status' 'INCOMPLETE')
        ) }

    # ---------------------------------------------------------------- S13 effective-dated cost, original-cost reversal, append-only
    $i13 = New-BaseInputs
    $i13.COST_MASTER = @(
        @{ CostRecordID = 'C-A1'; SKU = 'SKU-A'; UnitCost = 1000; Currency = 'EGP'; EffectiveFrom = [datetime]'2026-01-01'; ApprovedBy = 'Finance' },
        @{ CostRecordID = 'C-A2'; SKU = 'SKU-A'; UnitCost = 1200; Currency = 'EGP'; EffectiveFrom = [datetime]'2026-10-01'; ApprovedBy = 'Finance' })
    $i13.RETURNS = @(@{ ReturnID = 'RET-1'; OrderGID = (OG 3801); LineItemGID = (LG 3801 'L1'); SKU = 'SKU-A'; Quantity = 1; PhysicalReturnStatus = 'RECEIVED'; ReceivedDate = [datetime]'2026-10-20' })
    $i13.RETURN_INSPECTIONS = @(@{ InspectionID = 'INS-1'; ReturnID = 'RET-1'; InspectionDate = [datetime]'2026-10-21'; InspectionStatus = 'COMPLETE'; SellableQty = 1; ApprovedBy = 'Ops' })
    $S += @{ Name = 'S13_EFFECTIVE_COST_AND_APPEND_ONLY'; Rule = 'Cost valid on the sale date is used; a sellable return reverses the ORIGINAL cost; editing an approved cost row is flagged; return without refund supported.'
        PreviousCostState = @{ 'C-A1' = 'SKU-A||900|2026-01-01||Finance' }
        Orders = @((New-TOrder -Id 3801 -Name '#3801' -Created '2026-09-15T10:00:00Z' -Lines @(@{ Id = 'L1'; Sku = 'SKU-A'; Qty = 1; Price = 2500 }) -Received 2500), (New-TOrder -Id 3802 -Name '#3802' -Created '2026-10-15T10:00:00Z' -Lines @(@{ Id = 'L1'; Sku = 'SKU-A'; Qty = 1; Price = 2500 }) -Received 2500)); Inputs = $i13
        Assertions = @(
            (A 'S13-01' 'September sale costed at 1,000 (C-A1)' 'SALES_COSTED' @{ OrderName = '#3801' } 'value' 'EffectiveUnitCost' 1000),
            (A 'S13-02' 'October sale costed at 1,200 (C-A2)' 'SALES_COSTED' @{ OrderName = '#3802' } 'value' 'CostRecordID' 'C-A2'),
            (A 'S13-03' 'Return reverses original 1,000, not current 1,200' 'COGS_EVENTS' @{ EventType = 'COGS_REVERSAL' } 'value' 'Amount' -1000),
            (A 'S13-04' 'Edited approved cost row flagged' 'COST_EXCEPTIONS' @{ CheckName = 'COST_RECORD_MODIFIED'; AffectedRecord = 'C-A1' } 'count' -Expected 1),
            (A 'S13-05' 'Return without refund recognised' 'REFUND_RETURN_RECONCILIATION' @{ LineItemGID = (LG 3801 'L1') } 'value' 'Status' 'RETURN_WITHOUT_REFUND'),
            (A 'S13-06' 'October COGS 1,200 - 1,000 = 200' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Cost of Goods Sold' } 'value' 'Amount' -200),
            (A 'S13-07' 'Stock 5 - 1 - 1 + 1 = 4' 'INVENTORY' @{ SKU = 'SKU-A' } 'value' 'ClosingSellable' 4),
            (A 'S13-08' 'Ledger value 5,000 - 1,000 - 1,200 + 1,000 = 3,800' 'INVENTORY' @{ SKU = 'SKU-A' } 'value' 'StockValue' 3800),
            (A 'S13-09' 'Revenue unchanged by a return without refund' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Net Revenue' } 'value' 'Amount' 2500)
        ) }

    # ---------------------------------------------------------------- S14 unallocated refund on a REAL order (the #1008 pattern)
    $i14 = New-BaseInputs; $i14.COST_MASTER = @($i14.COST_MASTER) + @(@{ CostRecordID = 'C-C1'; SKU = 'SKU-C'; UnitCost = 900; Currency = 'EGP'; EffectiveFrom = [datetime]'2026-01-01'; ApprovedBy = 'Finance' })
    $S += @{ Name = 'S14_UNALLOCATED_REFUND_REAL_ORDER'; Rule = 'Money refund without refund line items reduces revenue as UNALLOCATED, is never pushed onto a product, and product P&L still reconciles to the P&L.'
        Orders = @(New-TOrder -Id 3901 -Name '#3901' -Created '2026-10-26T07:30:54Z' -Lines @(@{ Id = 'L1'; Sku = 'SKU-A'; Qty = 1; Price = 2250 }, @{ Id = 'L2'; Sku = 'SKU-C'; Qty = 1; Price = 2199 }) -Received 4449 -Refunds @(
            @{ Id = 'R1'; At = '2026-10-27T15:17:58Z'; Amount = 2199; Lines = @(@{ Id = 'RL1'; Line = 'L2'; Qty = 1; Subtotal = 2199; Restock = 'RETURN' }) },
            @{ Id = 'R2'; At = '2026-10-30T18:07:57Z'; Amount = 2250; Lines = @() })); Inputs = $i14
        Assertions = @(
            (A 'S14-01' 'R2 UNALLOCATED 2,250' 'REFUND_RECONCILIATION' @{ RefundGID = (RG 3901 'R2') } 'value' 'Unallocated' 2250),
            (A 'S14-02' 'SKU-A line keeps 2,250 net (no guess)' 'SALES_FACT' @{ LineItemGID = (LG 3901 'L1') } 'value' 'NetRevenue' 2250),
            (A 'S14-03' 'SKU-C line refunded 2,199' 'SALES_FACT' @{ LineItemGID = (LG 3901 'L2') } 'value' 'RefundAllocated' 2199),
            (A 'S14-04' 'P&L unallocated refunds -2,250' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Refunds (unallocated)' } 'value' 'Amount' -2250),
            (A 'S14-05' 'P&L net revenue 0' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Net Revenue' } 'value' 'Amount' 0),
            (A 'S14-06' 'Product P&L shows UNALLOCATED_REFUNDS row' 'PRODUCT_PL' @{ SKU = 'UNALLOCATED_REFUNDS' } 'value' 'NetRevenue' -2250),
            (A 'S14-07' 'Product P&L reconciles to P&L' 'FINANCE_EXCEPTIONS' @{ CheckName = 'PRODUCT_PL_VS_PL' } 'count' -Expected 0),
            (A 'S14-08' 'Exception severity ERROR for REAL order' 'EXCEPTIONS' @{ CheckName = 'REFUND_WITHOUT_LINE_ITEM'; AffectedRecord = (RG 3901 'R2') } 'value' 'Severity' 'ERROR'),
            (A 'S14-09' 'COGS kept for refunded-not-returned item (1,000 + 900)' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Cost of Goods Sold' } 'value' 'Amount' -1900)
        ) }

    # ---------------------------------------------------------------- S15 cancelled unpaid COD
    $S += @{ Name = 'S15_CANCELLED_UNPAID_ORDER'; Rule = 'Cancelled before shipping, nothing paid: revenue reversed, no COGS, no stock movement.'
        Orders = @(New-TOrder -Id 4001 -Name '#4001' -Created $O -Lines @(@{ Id = 'L1'; Sku = 'SKU-A'; Qty = 1; Price = 2500 }) -Received 0 -Cancelled '2026-10-06T10:00:00Z' -Refunds @(@{ Id = 'R1'; At = '2026-10-06T10:00:00Z'; Amount = 0; Lines = @(@{ Id = 'RL1'; Line = 'L1'; Qty = 1; Subtotal = 2500; Restock = 'CANCEL' }) })); Inputs = (New-BaseInputs)
        Assertions = @(
            (A 'S15-01' 'Line net revenue 0' 'SALES_FACT' @{ OrderName = '#4001' } 'value' 'NetRevenue' 0),
            (A 'S15-02' 'Nothing shipped' 'SALES_FACT' @{ OrderName = '#4001' } 'value' 'QtyShipped' 0),
            (A 'S15-03' 'Cancellations -2,500 in P&L' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Cancellations' } 'value' 'Amount' -2500),
            (A 'S15-04' 'Net revenue 0' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Net Revenue' } 'value' 'Amount' 0),
            (A 'S15-05' 'No COGS' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Cost of Goods Sold' } 'value' 'Amount' 0),
            (A 'S15-06' 'Stock unchanged (5)' 'INVENTORY' @{ SKU = 'SKU-A' } 'value' 'ClosingSellable' 5),
            (A 'S15-07' 'No residual on the cancelled order' 'EXCEPTIONS' @{ CheckName = 'CANCELLED_ORDER_RESIDUAL' } 'count' -Expected 0)
        ) }

    # ---------------------------------------------------------------- S16 Cairo time zone month boundary
    $S += @{ Name = 'S16_CAIRO_MONTH_BOUNDARY'; Rule = '2026-09-30 22:30 UTC is 2026-10-01 01:30 in Cairo (DST): the order belongs to October.'
        Orders = @(New-TOrder -Id 4101 -Name '#4101' -Created '2026-09-30T22:30:00Z' -Lines @(@{ Id = 'L1'; Sku = 'SKU-A'; Qty = 1; Price = 2500 }) -Received 2500); Inputs = (New-BaseInputs)
        Assertions = @(
            (A 'S16-01' 'Order month 2026-10' 'SALES_FACT' @{ OrderName = '#4101' } 'value' 'OrderMonth' '2026-10'),
            (A 'S16-02' 'Order date 2026-10-01' 'SALES_FACT' @{ OrderName = '#4101' } 'value' 'OrderDateLocal' '2026-10-01')
        ) }

    # ---------------------------------------------------------------- S17 test orders cannot leak
    $S += @{ Name = 'S17_NO_TEST_ORDER_LEAKAGE'; Rule = 'Manual TEST, Shopify test flag and TEST tag are all excluded; only the REAL order reaches reports.'
        Orders = @(
            (New-TOrder -Id 4201 -Name '#4201' -Created $O -Lines @(@{ Id = 'L1'; Sku = 'SKU-A'; Qty = 1; Price = 9999 }) -Received 9999),
            (New-TOrder -Id 4202 -Name '#4202' -Created $O -Lines @(@{ Id = 'L1'; Sku = 'SKU-A'; Qty = 1; Price = 8888 }) -Received 8888 -ShopifyTest $true),
            (New-TOrder -Id 4203 -Name '#4203' -Created $O -Lines @(@{ Id = 'L1'; Sku = 'SKU-A'; Qty = 1; Price = 7777 }) -Received 7777 -Tags @('TEST')),
            (New-TOrder -Id 4204 -Name '#4204' -Created $O -Lines @(@{ Id = 'L1'; Sku = 'SKU-A'; Qty = 1; Price = 2500 }) -Received 2500))
        Inputs = (New-BaseInputs) + @{ ORDER_CLASSIFICATION = @(@{ OrderGID = (OG 4201); OrderName = '#4201'; Classification = 'TEST'; Reason = 'staff test' }) }
        Assertions = @(
            (A 'S17-01' 'Manual TEST' 'SALES_FACT' @{ OrderName = '#4201' } 'value' 'ClassificationSource' 'MANUAL'),
            (A 'S17-02' 'Shopify test flag' 'SALES_FACT' @{ OrderName = '#4202' } 'value' 'ClassificationSource' 'SHOPIFY_TEST_FLAG'),
            (A 'S17-03' 'TEST tag' 'SALES_FACT' @{ OrderName = '#4203' } 'value' 'ClassificationSource' 'TEST_TAG'),
            (A 'S17-04' 'Gross sales only from REAL order' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Gross Sales' } 'value' 'Amount' 2500),
            (A 'S17-05' 'KPI orders = 1' 'KPI_MONTHLY' @{ Month = '2026-10' } 'value' 'Orders' 1),
            (A 'S17-06' 'Stock reduced only by the REAL sale' 'INVENTORY' @{ SKU = 'SKU-A' } 'value' 'ClosingSellable' 4),
            (A 'S17-07' 'No test order in Finance' 'FINANCE_EXCEPTIONS' @{ CheckName = 'TEST_ORDER_IN_FINANCE' } 'count' -Expected 0),
            (A 'S17-08' 'No test order in Management' 'MANAGEMENT_EXCEPTIONS' @{ CheckName = 'TEST_ORDER_IN_MANAGEMENT' } 'count' -Expected 0),
            (A 'S17-09' 'Operational SALES has 1 line' 'SALES' @{} 'count' -Expected 1),
            (A 'S17-10' 'Dashboard revenue reconciles to Finance' 'MANAGEMENT_EXCEPTIONS' @{ CheckName = 'KPI_REVENUE_VS_FINANCE' } 'count' -Expected 0)
        ) }

    # ---------------------------------------------------------------- S18 multiple refunds, different months
    $S += @{ Name = 'S18_MULTIPLE_REFUNDS_SAME_ORDER'; Rule = 'Two refunds on one line in different months: each recognised in its own month; quantities never exceed the line.'
        Orders = @(New-TOrder -Id 4301 -Name '#4301' -Created '2026-09-20T10:00:00Z' -Lines @(@{ Id = 'L1'; Sku = 'SKU-A'; Qty = 2; Price = 2500 }) -Received 5000 -Refunds @(
            @{ Id = 'R1'; At = '2026-09-25T10:00:00Z'; Amount = 2500; Lines = @(@{ Id = 'RL1'; Line = 'L1'; Qty = 1; Subtotal = 2500; Restock = 'NO_RESTOCK' }) },
            @{ Id = 'R2'; At = '2026-10-05T10:00:00Z'; Amount = 2500; Lines = @(@{ Id = 'RL2'; Line = 'L1'; Qty = 1; Subtotal = 2500; Restock = 'NO_RESTOCK' }) })); Inputs = (New-BaseInputs)
        Assertions = @(
            (A 'S18-01' 'September net revenue 2,500' 'PROFIT_AND_LOSS' @{ Month = '2026-09'; LineItem = 'Net Revenue' } 'value' 'Amount' 2500),
            (A 'S18-02' 'October net revenue -2,500' 'PROFIT_AND_LOSS' @{ Month = '2026-10'; LineItem = 'Net Revenue' } 'value' 'Amount' -2500),
            (A 'S18-03' 'Line refunded qty 2' 'SALES_FACT' @{ OrderName = '#4301' } 'value' 'QtyRefunded' 2),
            (A 'S18-04' 'Line net revenue 0' 'SALES_FACT' @{ OrderName = '#4301' } 'value' 'NetRevenue' 0),
            (A 'S18-05' 'No quantity mismatch' 'EXCEPTIONS' @{ CheckName = 'LINE_REFUND_QTY_MISMATCH' } 'count' -Expected 0)
        ) }
    return $S
}
