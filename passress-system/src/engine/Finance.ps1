# Stage 03 - FINANCE. Double-entry journal + preliminary statements.
# Accounting rules implemented here:
#  * Revenue only from REAL orders (IsReportable). Refunds recognised in the month the successful refund transaction occurred.
#  * Production / inventory payments are ASSETS (1310), never expensed as COGS when paid.
#  * COGS comes only from COGS_EVENTS (sale COGS and approved SELLABLE return reversals).
#  * Partner capital: CAPITAL_DEPOSIT = Dr cash / Cr 3000; partner-paid company cost = Dr expense|asset / Cr 3010 (no company cash).
#  * Opening balances are never invented: missing -> exception + statements INCOMPLETE.

function Get-PassressDefaultChartOfAccounts {
    $rows = @(
        @('1000', 'Cash on Hand', 'ASSET', 'Cash & Bank', $true), @('1010', 'Bank Account', 'ASSET', 'Cash & Bank', $true),
        @('1020', 'InstaPay / Wallet', 'ASSET', 'Cash & Bank', $true), @('1030', 'Vodafone Cash', 'ASSET', 'Cash & Bank', $true),
        @('1200', 'Accounts Receivable - Customers', 'ASSET', 'Accounts Receivable', $false),
        @('1210', 'COD / Payment Clearing (held by courier or gateway)', 'ASSET', 'COD & Payment Clearing', $false),
        @('1300', 'Inventory - Finished Goods', 'ASSET', 'Inventory - Finished Goods', $false),
        @('1310', 'Inventory - Materials, WIP & Supplier Advances', 'ASSET', 'Inventory - Materials & WIP', $false),
        @('1500', 'Fixed Assets', 'ASSET', 'Fixed Assets', $false),
        @('2000', 'Accounts Payable', 'LIABILITY', 'Accounts Payable', $false), @('2200', 'VAT / Tax Payable', 'LIABILITY', 'Tax Payable', $false),
        @('2900', 'Other Liabilities', 'LIABILITY', 'Other Liabilities', $false),
        @('3000', 'Partner Capital - Cash Deposits (Paid-Up)', 'EQUITY', 'Partner Capital - Cash Deposits', $false),
        @('3010', 'Partner Capital - Company Costs Paid Personally', 'EQUITY', 'Partner Capital - Paid Personally', $false),
        @('3200', 'Partner Withdrawals', 'EQUITY', 'Partner Withdrawals', $false),
        @('3900', 'Retained Earnings - Opening', 'EQUITY', 'Retained Earnings', $false),
        @('4000', 'Gross Sales', 'REVENUE', 'Gross Sales', $false), @('4010', 'Shipping Income', 'REVENUE', 'Shipping Income', $false),
        @('4100', 'Discounts', 'CONTRA_REVENUE', 'Discounts', $false), @('4200', 'Refunds - Line Items', 'CONTRA_REVENUE', 'Refunds', $false),
        @('4210', 'Refunds - Unallocated', 'CONTRA_REVENUE', 'Refunds - Unallocated', $false), @('4300', 'Cancellations', 'CONTRA_REVENUE', 'Cancellations', $false),
        @('5000', 'Cost of Goods Sold', 'COGS', 'Cost of Goods Sold', $false), @('5100', 'Inventory Write-offs & Adjustments', 'COGS', 'Inventory Write-offs', $false),
        @('6100', 'Samples', 'EXPENSE', 'Samples', $false), @('6200', 'Packaging', 'EXPENSE', 'Packaging', $false),
        @('6300', 'Shipping & Delivery', 'EXPENSE', 'Shipping & Delivery', $false), @('6400', 'Marketing', 'EXPENSE', 'Marketing', $false),
        @('6500', 'Salaries & Freelancers', 'EXPENSE', 'Salaries & Freelancers', $false), @('6600', 'Website, Software & Subscriptions', 'EXPENSE', 'Website & Software', $false),
        @('6700', 'Production Overheads', 'EXPENSE', 'Production Overheads', $false), @('6750', 'Rent & Utilities', 'EXPENSE', 'Rent & Utilities', $false),
        @('6800', 'COD & Payment Fees', 'EXPENSE', 'COD & Payment Fees', $false), @('6900', 'Miscellaneous', 'EXPENSE', 'Miscellaneous', $false),
        @('7000', 'Other Income', 'OTHER_INCOME', 'Other Income', $false), @('7100', 'Other Expenses', 'OTHER_EXPENSE', 'Other Expenses', $false)
    )
    return , @($rows | ForEach-Object { [pscustomobject]@{ AccountCode = $_[0]; AccountName = $_[1]; AccountType = $_[2]; StatementLine = $_[3]; IsCash = $_[4]; Active = $true } })
}

function Get-PassressDefaultExpenseMap {
    # Mirrors the categories in the original HEIRARCHY. ClassificationConfirmed = FALSE where Phase 1 flagged the treatment as undecided.
    $rows = @(
        @('SAMPLE', '6100', $false, 'Samples treated as expense in the legacy workbook; confirm (expense vs inventory).'),
        @('PRODUCTION', '6700', $false, 'Legacy EXPENSES/PRODUCTION rows - confirm whether these are inventory (use PRODUCTION_PAYMENT) or overheads.'),
        @('PACKAGING', '6200', $false, 'Confirm: operating expense vs product cost (COST_MASTER PackagingCost).'),
        @('SHIPPING & DELIVERY', '6300', $true, ''), @('MARKETING', '6400', $true, ''), @('SALARIES', '6500', $true, ''),
        @('MISC.', '6900', $true, ''), @('WEBSITE AND TECHNOLOGY', '6600', $true, ''), @('RENT & UTILITIES', '6750', $true, ''), @('COD & PAYMENT FEES', '6800', $true, '')
    )
    return , @($rows | ForEach-Object { [pscustomobject]@{ Category = $_[0]; AccountCode = $_[1]; ClassificationConfirmed = $_[2]; Notes = $_[3] } })
}

function Invoke-PassressFinanceStage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Upstream,   # 01: SALES_FACT, REVENUE_EVENTS, ORDER_TRANSACTIONS ; 02: SALES_COSTED, COGS_EVENTS, INVENTORY_MOVEMENTS, INVENTORY, REFUND_RETURN_RECONCILIATION
        [Parameter(Mandatory)][hashtable]$Inputs,     # CHART_OF_ACCOUNTS, EXPENSE_CATEGORY_MAP, DATA_ENTRY, OPENING_BALANCES, MONTH_CLOSE
        $CloseSnapshots, [Parameter(Mandatory)]$Config, [Parameter(Mandatory)][string]$RunId
    )
    $Upstream = ConvertTo-PassressRowSet $Upstream @('SALES_FACT', 'REVENUE_EVENTS', 'ORDER_TRANSACTIONS', 'SALES_COSTED', 'COGS_EVENTS', 'INVENTORY_MOVEMENTS', 'INVENTORY', 'REFUND_RETURN_RECONCILIATION')
    $Inputs = ConvertTo-PassressRowSet $Inputs @('CHART_OF_ACCOUNTS', 'EXPENSE_CATEGORY_MAP', 'DATA_ENTRY', 'OPENING_BALANCES', 'MONTH_CLOSE')
    $ex = New-List; $J = New-List; $capital = New-List; $monthIssues = @{}
    $fyStart = [int](Get-PassressConfigValue $Config 'FinancialYearStartMonth' 1)

    $coaRows = @($Inputs.CHART_OF_ACCOUNTS); if ($coaRows.Count -eq 0) { $coaRows = Get-PassressDefaultChartOfAccounts }
    $coa = @{}; foreach ($a in $coaRows) { if (-not (Test-Blank $a.AccountCode)) { $coa[[string]$a.AccountCode] = $a } }
    $mapRows = @($Inputs.EXPENSE_CATEGORY_MAP); if ($mapRows.Count -eq 0) { $mapRows = Get-PassressDefaultExpenseMap }
    $expMap = @{}; foreach ($m in $mapRows) { if (-not (Test-Blank $m.Category)) { $expMap[([string]$m.Category).Trim().ToUpperInvariant()] = $m } }
    $isCash = { param($code) $code -and $coa.ContainsKey([string]$code) -and (ConvertTo-PassressBool $coa[[string]$code].IsCash) }

    $addJournal = {
        param([string]$Id, $Date, [object[]]$Lines, [string]$SourceType, [string]$SourceId, [string]$OrderName, [string]$Sku, [string]$Counterparty, [string]$Description)
        $dr = 0.0; $cr = 0.0; $bad = @()
        foreach ($l in $Lines) { $dr += [double]$l.Debit; $cr += [double]$l.Credit; if (-not $coa.ContainsKey([string]$l.Account)) { $bad += [string]$l.Account } }
        if ($bad.Count -gt 0) { $ex.Add((New-PassressException -CheckName 'UNKNOWN_ACCOUNT' -Severity ERROR -AffectedRecord $SourceId -OrderName $OrderName -ActualValue ($bad -join ',') -RecommendedAction 'Add the account to CHART_OF_ACCOUNTS. Entry not posted.' -RunId $RunId)); $monthIssues[(Get-MonthKey $Date)] = $true; return }
        if (-not (Test-MoneyEqual $dr $cr)) { $ex.Add((New-PassressException -CheckName 'UNBALANCED_JOURNAL' -Severity ERROR -AffectedRecord $Id -ExpectedValue $dr -ActualValue $cr -Difference (Get-RoundedMoney ($dr - $cr)) -RecommendedAction 'Internal error: journal not balanced, not posted.' -RunId $RunId)); return }
        if ($null -eq $Date) { $ex.Add((New-PassressException -CheckName 'JOURNAL_WITHOUT_DATE' -Severity ERROR -AffectedRecord $Id -RecommendedAction 'Source has no date; not posted.' -RunId $RunId)); return }
        $n = 0
        foreach ($l in $Lines) {
            if ([double]$l.Debit -eq 0 -and [double]$l.Credit -eq 0) { continue }
            $n++
            $J.Add([pscustomobject][ordered]@{ JournalID = $Id; LineNo = $n; EntryDate = $Date; Month = (Get-MonthKey $Date); AccountCode = [string]$l.Account; AccountName = $coa[[string]$l.Account].AccountName; Debit = (Get-RoundedMoney ([double]$l.Debit)); Credit = (Get-RoundedMoney ([double]$l.Credit)); SourceType = $SourceType; SourceID = $SourceId; OrderName = $OrderName; SKU = $Sku; Counterparty = $(if ($l.Cp) { [string]$l.Cp } else { $Counterparty }); Description = $Description })
        }
    }
    function L { param($a, $d, $c, $cp) return @{ Account = $a; Debit = $d; Credit = $c; Cp = $cp } }

    # ------------------------------------------------ Shopify revenue (REAL only)
    $testOrders = @{}; foreach ($f in @($Upstream.SALES_FACT)) { if (-not $f.IsReportable) { $testOrders[[string]$f.OrderName] = [string]$f.Classification } }
    foreach ($ev in @($Upstream.REVENUE_EVENTS | Where-Object { $_.IsReportable })) {
        $net = [double]$ev.NetAmount; $tax = [double]$ev.TaxAmount; $id = 'JE-' + $ev.EventID
        switch ($ev.EventType) {
            'SALE' {
                $g = [double]$ev.GrossAmount; $d = [double]$ev.DiscountAmount
                & $addJournal $id $ev.EventDateLocal @((L '1200' ($g - $d + $tax) 0), (L '4100' $d 0), (L '4000' 0 $g), (L '2200' 0 $tax)) 'SALE' $ev.EventID $ev.OrderName $ev.SKU $null 'Shopify sale'
            }
            'SALE_SHIPPING' { & $addJournal $id $ev.EventDateLocal @((L '1200' $net 0), (L '4010' 0 $net)) 'SALE' $ev.EventID $ev.OrderName $null $null 'Shipping charged' }
            'REFUND_LINE' { & $addJournal $id $ev.EventDateLocal @((L '4200' (-$net) 0), (L '2200' (-$tax) 0), (L '1210' 0 (-$net - $tax))) 'REFUND' $ev.EventID $ev.OrderName $ev.SKU $null 'Refund (line-item allocated)' }
            'REFUND_SHIPPING' { & $addJournal $id $ev.EventDateLocal @((L '4010' (-$net) 0), (L '1210' 0 (-$net))) 'REFUND' $ev.EventID $ev.OrderName $null $null 'Shipping refunded' }
            'REFUND_ADJUSTMENT' {
                if ($net -lt 0) { & $addJournal $id $ev.EventDateLocal @((L '4210' (-$net) 0), (L '1210' 0 (-$net))) 'REFUND' $ev.EventID $ev.OrderName $null $null 'Refund adjustment' }
                else { & $addJournal $id $ev.EventDateLocal @((L '1210' $net 0), (L '4210' 0 $net)) 'REFUND' $ev.EventID $ev.OrderName $null $null 'Refund adjustment' }
            }
            'REFUND_UNALLOCATED' {
                if ($net -lt 0) { & $addJournal $id $ev.EventDateLocal @((L '4210' (-$net) 0), (L '1210' 0 (-$net))) 'REFUND' $ev.EventID $ev.OrderName $null $null 'Refund NOT allocated to a product' }
                else { & $addJournal $id $ev.EventDateLocal @((L '1210' $net 0), (L '4210' 0 $net)) 'REFUND' $ev.EventID $ev.OrderName $null $null 'Negative unallocated refund difference' }
            }
            'CANCELLATION' { & $addJournal $id $ev.EventDateLocal @((L '4300' (-$net) 0), (L '2200' (-$tax) 0), (L '1200' 0 (-$net - $tax))) 'CANCELLATION' $ev.EventID $ev.OrderName $ev.SKU $null 'Order cancelled (no money)' }
        }
    }
    $realOrders = @{}; foreach ($f in @($Upstream.SALES_FACT | Where-Object { $_.IsReportable })) { $realOrders[[string]$f.OrderGID] = $true }
    foreach ($tx in @($Upstream.ORDER_TRANSACTIONS | Where-Object { $_.IsSuccessfulCollection })) {
        if (-not $realOrders.ContainsKey([string]$tx.OrderGID)) { continue }
        $a = [double]$tx.Amount
        & $addJournal ('JE-COL-' + $tx.TransactionGID) $tx.ProcessedDateLocal @((L '1210' $a 0), (L '1200' 0 $a)) 'COLLECTION' $tx.TransactionGID $tx.OrderName $null $tx.Gateway 'Payment marked received in Shopify (held by courier/gateway until remitted)'
    }

    # ------------------------------------------------ COGS + inventory (from 02)
    $costMissingMonths = @{}
    foreach ($c in @($Upstream.COGS_EVENTS)) {
        if ($null -eq $c.Amount) { $costMissingMonths[[string]$c.EventMonth] = $true; continue }
        $a = [double]$c.Amount
        if ($c.EventType -eq 'TRANSIT_LOSS') { & $addJournal ('JE-' + $c.EventID) $c.EventDateLocal @((L '5100' $a 0), (L '1300' 0 $a)) 'INVENTORY' $c.EventID $c.OrderName $c.SKU $null 'Undelivered unit returned damaged / written off (stock loss, not COGS of a sale)'; continue }
        if ($a -ge 0) { & $addJournal ('JE-' + $c.EventID) $c.EventDateLocal @((L '5000' $a 0), (L '1300' 0 $a)) 'COGS' $c.EventID $c.OrderName $c.SKU $null 'COGS recognised (configured trigger met) at effective unit cost' }
        else { & $addJournal ('JE-' + $c.EventID) $c.EventDateLocal @((L '1300' (-$a) 0), (L '5000' 0 (-$a))) 'COGS' $c.EventID $c.OrderName $c.SKU $null 'COGS reversal - approved SELLABLE return at original cost' }
    }
    foreach ($m in $costMissingMonths.Keys) { $monthIssues[$m] = $true }
    $openingInvValue = 0.0
    foreach ($mv in @($Upstream.INVENTORY_MOVEMENTS)) {
        switch ($mv.MovementType) {
            'OPENING' { if ($null -ne $mv.Value) { $openingInvValue += [double]$mv.Value } }
            { $_ -eq 'PRODUCTION_RECEIPT' -or $_ -eq 'PURCHASE_RECEIPT' } {
                if ($null -eq $mv.Value) { $monthIssues[[string]$mv.MovementMonth] = $true; break }
                & $addJournal ('JE-' + $mv.MovementID) $mv.MovementDate @((L '1300' $mv.Value 0), (L '1310' 0 $mv.Value)) 'INVENTORY' $mv.MovementID $null $mv.SKU $null ('Stock received: ' + $mv.MovementType)
            }
            'ADJUSTMENT' {
                if ($mv.Bucket -ne 'SELLABLE') { break }
                if ($null -eq $mv.Value) { $monthIssues[[string]$mv.MovementMonth] = $true; break }
                $v = [double]$mv.Value
                if ($v -lt 0) { & $addJournal ('JE-' + $mv.MovementID) $mv.MovementDate @((L '5100' (-$v) 0), (L '1300' 0 (-$v))) 'INVENTORY' $mv.MovementID $null $mv.SKU $null 'Stock adjustment (loss)' }
                elseif ($v -gt 0) { & $addJournal ('JE-' + $mv.MovementID) $mv.MovementDate @((L '1300' $v 0), (L '5100' 0 $v)) 'INVENTORY' $mv.MovementID $null $mv.SKU $null 'Stock adjustment (gain)' }
            }
        }
    }

    # ------------------------------------------------ manual DATA_ENTRY
    $spendTypes = @('EXPENSE', 'PRODUCTION_PAYMENT', 'INVENTORY_PURCHASE', 'ASSET_PURCHASE', 'OTHER_EXPENSE')
    $allTypes = $spendTypes + @('CAPITAL_DEPOSIT', 'OWNER_WITHDRAWAL', 'OTHER_INCOME', 'COD_REMITTANCE', 'COD_FEE', 'TRANSFER')
    $seenTx = @{}; $deposits = New-List
    # cash deposits by CapitalContributionRef - used to stop the same partner money being booked twice (3000 and 3010)
    $depositRefs = @{}
    foreach ($r in @($Inputs.DATA_ENTRY)) { if (([string]$r.TransactionType).Trim().ToUpperInvariant() -eq 'CAPITAL_DEPOSIT' -and -not (Test-Blank $r.CapitalContributionRef) -and -not (Test-Blank $r.TransactionID)) { $depositRefs[([string]$r.CapitalContributionRef).Trim().ToUpperInvariant()] = [string]$r.TransactionID } }
    $addCapital = {
        param($r, [string]$fundingType, [double]$signedAmount, [double]$cashImpact, [string]$debitAccount)
        $capital.Add([ordered]@{ TransactionID = [string]$r.TransactionID; TransactionDate = $r.TransactionDate; Partner = [string]$r.PaidBy; FundingType = $fundingType; PaymentSource = $r.PaymentSource; Amount = $signedAmount; CashImpact = $cashImpact; DebitAccount = $debitAccount; DebitAccountName = $(if ($coa.ContainsKey($debitAccount)) { $coa[$debitAccount].AccountName } else { $null }); RelatedCategory = $(if ($r.Category) { $r.Category } else { $r.TransactionType }); CapitalContributionRef = $r.CapitalContributionRef; SupportingDocument = $r.SupportingDocument; Description = $r.Description })
        if (Test-Blank $r.SupportingDocument) { $ex.Add((New-PassressException -CheckName 'MISSING_SUPPORTING_EVIDENCE' -Severity WARNING -AffectedRecord ([string]$r.TransactionID) -ActualValue $fundingType -RecommendedAction 'Partner-funded transaction without SupportingDocument (bank slip, receipt, invoice). Posted, but attach evidence.' -RunId $RunId)) }
    }
    foreach ($r in @($Inputs.DATA_ENTRY)) {
        $id = [string]$r.TransactionID; $date = $r.TransactionDate; $type = ([string]$r.TransactionType).Trim().ToUpperInvariant(); $amt = $r.Amount
        $mk = Get-MonthKey $date
        $fail = { param($check, $msg) $ex.Add((New-PassressException -CheckName $check -Severity ERROR -AffectedRecord $id -ActualValue $type -RecommendedAction ($msg + ' Not posted - statements for the month are INCOMPLETE.') -RunId $RunId)); if ($mk) { $monthIssues[$mk] = $true } }
        if (Test-Blank $id) { $ex.Add((New-PassressException -CheckName 'TRANSACTION_WITHOUT_ID' -Severity ERROR -AffectedRecord ('row dated ' + (Format-PassressValue $date 'date')) -RecommendedAction 'Every DATA_ENTRY row needs a unique TransactionID. Not posted.' -RunId $RunId)); if ($mk) { $monthIssues[$mk] = $true }; continue }
        if ($seenTx.ContainsKey($id)) { $ex.Add((New-PassressException -CheckName 'DUPLICATE_TRANSACTION_ID' -Severity ERROR -AffectedRecord $id -RecommendedAction 'Duplicate TransactionID: only the first row is posted (prevents double counting).' -RunId $RunId)); continue }
        $seenTx[$id] = $true
        # review gate: migrated legacy rows (and any row marked PENDING_REVIEW) are never posted until approved
        $review = ([string]$r.ReviewStatus).Trim().ToUpperInvariant()
        if (-not (Test-Blank $r.LegacyType) -and $review -ne 'APPROVED') { & $fail 'LEGACY_ROW_PENDING_REVIEW' ('Migrated legacy row (original type "' + $r.LegacyType + '", category "' + $r.LegacyCategory + '"). TransactionType is only a provisional suggestion: confirm it, set PaymentSource / PaymentAccount, then ReviewStatus = APPROVED and ReviewedBy.'); continue }
        if ($review -eq 'PENDING_REVIEW') { & $fail 'ROW_PENDING_REVIEW' 'ReviewStatus = PENDING_REVIEW.'; continue }
        if ($null -eq $date) { & $fail 'TRANSACTION_DATE_MISSING' 'Enter TransactionDate.'; continue }
        if ($null -eq $amt -or [double]$amt -le 0) { & $fail 'TRANSACTION_AMOUNT_INVALID' 'Amount must be a positive number.'; continue }
        if ($allTypes -notcontains $type) { & $fail 'TRANSACTION_TYPE_INVALID' ('TransactionType must be one of: ' + ($allTypes -join ', ') + '.'); continue }
        $amt = [double]$amt; $paidBy = [string]$r.PaidBy; $src = ([string]$r.PaymentSource).Trim().ToUpperInvariant()
        $payAcct = if (-not (Test-Blank $r.CounterAccount)) { [string]$r.CounterAccount } else { [string]$r.PaymentAccount }
        $desc = if ($r.Description) { [string]$r.Description } else { $type }

        if ($spendTypes -contains $type) {
            # debit side
            $debit = $null
            if (-not (Test-Blank $r.Account)) { $debit = [string]$r.Account }
            elseif ($type -eq 'EXPENSE') {
                $catKey = ([string]$r.Category).Trim().ToUpperInvariant()
                if ($expMap.ContainsKey($catKey)) {
                    $debit = [string]$expMap[$catKey].AccountCode
                    if (-not (ConvertTo-PassressBool $expMap[$catKey].ClassificationConfirmed)) { $ex.Add((New-PassressException -CheckName 'EXPENSE_CLASSIFICATION_UNCONFIRMED' -Severity WARNING -AffectedRecord $id -ActualValue $r.Category -RecommendedAction ('Posted to ' + $debit + ' provisionally. Confirm the treatment in EXPENSE_CATEGORY_MAP. ' + [string]$expMap[$catKey].Notes) -RunId $RunId)) }
                } else { & $fail 'UNMAPPED_EXPENSE_CATEGORY' ('Category "' + $r.Category + '" has no account in EXPENSE_CATEGORY_MAP.'); continue }
            }
            elseif ($type -eq 'PRODUCTION_PAYMENT' -or $type -eq 'INVENTORY_PURCHASE') { $debit = '1310' }
            elseif ($type -eq 'ASSET_PURCHASE') { $debit = '1500' }
            else { $debit = '7100' }
            # credit side - who paid
            if ($src -eq 'COMPANY') {
                if (-not (& $isCash $payAcct)) { & $fail 'MISSING_PAYMENT_ACCOUNT' 'COMPANY-paid rows need PaymentAccount = a cash/bank account code (e.g. 1010).'; continue }
                & $addJournal ('JE-' + $id) $date @((L $debit $amt 0), (L $payAcct 0 $amt)) 'DATA_ENTRY' $id $null $r.ProductSKU $r.Supplier $desc
            } elseif ($src -eq 'PARTNER_PERSONAL') {
                if (Test-Blank $paidBy) { & $fail 'MISSING_PARTNER_NAME' 'PARTNER_PERSONAL rows need PaidBy (the partner).'; continue }
                $ref = ([string]$r.CapitalContributionRef).Trim().ToUpperInvariant()
                if ($ref -and $depositRefs.ContainsKey($ref)) { & $fail 'CAPITAL_DOUBLE_COUNT' ('CapitalContributionRef ' + $ref + ' is also used by cash deposit ' + $depositRefs[$ref] + '. The same partner money cannot be both deposited into the company (3000) and paid personally (3010). If the company paid the supplier from that deposit, record this cost as PaymentSource = COMPANY.'); continue }
                # Dr expense/asset, Cr 3010 - company cash is NOT touched
                & $addJournal ('JE-' + $id) $date @((L $debit $amt 0), (L '3010' 0 $amt)) 'DATA_ENTRY' $id $null $r.ProductSKU $paidBy ($desc + ' (paid personally by partner - capital contribution)')
                & $addCapital $r 'PAID_PERSONALLY' $amt 0 $debit
            } else { & $fail 'MISSING_PARTNER_FUNDING_CLASSIFICATION' 'PaymentSource must be COMPANY or PARTNER_PERSONAL (was it paid from company money or personally by a partner?).'; continue }
            continue
        }
        switch ($type) {
            'CAPITAL_DEPOSIT' {
                if (-not (& $isCash $payAcct)) { & $fail 'MISSING_PAYMENT_ACCOUNT' 'CAPITAL_DEPOSIT needs PaymentAccount = the company cash/bank account that received the money.'; break }
                if (Test-Blank $paidBy) { & $fail 'MISSING_PARTNER_NAME' 'CAPITAL_DEPOSIT needs PaidBy (the partner).'; break }
                # Dr company cash (exactly once), Cr 3000
                & $addJournal ('JE-' + $id) $date @((L $payAcct $amt 0), (L '3000' 0 $amt)) 'DATA_ENTRY' $id $null $null $paidBy ($desc + ' (partner cash deposit)')
                & $addCapital $r 'CASH_DEPOSIT' $amt $amt $payAcct
                $deposits.Add([pscustomobject]@{ Id = $id; Date = $date; Partner = $paidBy; Amount = $amt })
            }
            'OWNER_WITHDRAWAL' {
                if (-not (& $isCash $payAcct)) { & $fail 'MISSING_PAYMENT_ACCOUNT' 'OWNER_WITHDRAWAL needs PaymentAccount.'; break }
                & $addJournal ('JE-' + $id) $date @((L '3200' $amt 0), (L $payAcct 0 $amt)) 'DATA_ENTRY' $id $null $null $paidBy $desc
                & $addCapital $r 'WITHDRAWAL' (-1 * $amt) (-1 * $amt) '3200'
            }
            'OTHER_INCOME' { if (-not (& $isCash $payAcct)) { & $fail 'MISSING_PAYMENT_ACCOUNT' 'OTHER_INCOME needs PaymentAccount.'; break }; & $addJournal ('JE-' + $id) $date @((L $payAcct $amt 0), (L '7000' 0 $amt)) 'DATA_ENTRY' $id $null $null $r.Supplier $desc }
            'COD_REMITTANCE' { if (-not (& $isCash $payAcct)) { & $fail 'MISSING_PAYMENT_ACCOUNT' 'COD_REMITTANCE needs PaymentAccount (where the courier paid you).'; break }; & $addJournal ('JE-' + $id) $date @((L $payAcct $amt 0), (L '1210' 0 $amt)) 'DATA_ENTRY' $id $null $null $r.Supplier $desc }
            'COD_FEE' { & $addJournal ('JE-' + $id) $date @((L '6800' $amt 0), (L '1210' 0 $amt)) 'DATA_ENTRY' $id $null $null $r.Supplier $desc }
            'TRANSFER' {
                $to = [string]$r.Account
                if (-not (& $isCash $payAcct) -or -not (& $isCash $to)) { & $fail 'TRANSFER_ACCOUNTS_INVALID' 'TRANSFER needs PaymentAccount (from) and Account (to), both cash/bank accounts.'; break }
                & $addJournal ('JE-' + $id) $date @((L $to $amt 0), (L $payAcct 0 $amt)) 'DATA_ENTRY' $id $null $null $null $desc
            }
        }
    }
    foreach ($c in @($capital | Where-Object { $_.FundingType -eq 'PAID_PERSONALLY' })) {
        foreach ($d in $deposits) {
            if ($d.Partner -eq $c.Partner -and (Test-MoneyEqual $d.Amount $c.Amount) -and [math]::Abs(($d.Date - $c.TransactionDate).TotalDays) -le 3) {
                $ex.Add((New-PassressException -CheckName 'POSSIBLE_DOUBLE_COUNT_CAPITAL' -Severity WARNING -AffectedRecord ($c.TransactionID + ' / ' + $d.Id) -ActualValue $c.Amount -RecommendedAction 'Same partner, same amount within 3 days recorded both as a cash deposit and as a cost paid personally. If the partner paid the supplier directly, delete the deposit row (or vice versa).' -RunId $RunId))
            }
        }
    }
    foreach ($grp in (@($capital) | Group-Object { '{0}|{1}|{2}|{3}' -f $_.Partner, (Format-PassressValue $_.TransactionDate 'date'), (Format-PassressValue $_.Amount 'number'), $_.FundingType })) {
        if ($grp.Count -gt 1) { $ex.Add((New-PassressException -CheckName 'POSSIBLE_DUPLICATE_CAPITAL_ENTRY' -Severity WARNING -AffectedRecord ((@($grp.Group | ForEach-Object { $_.TransactionID })) -join ' / ') -ActualValue $grp.Name -RecommendedAction 'Two or more partner-capital rows with the same partner, date, amount and funding type. Delete the duplicate unless they are genuinely separate payments (then add a CapitalContributionRef to each).' -RunId $RunId)) }
    }

    # ------------------------------------------------ opening balances
    $openRows = @($Inputs.OPENING_BALANCES | Where-Object { -not (Test-Blank $_.AccountCode) })
    $openingMissing = ($openRows.Count -eq 0)
    $openingGLInventory = 0.0
    if ($openingMissing) {
        $ex.Add((New-PassressException -CheckName 'MISSING_OPENING_BALANCES' -Severity ERROR -AffectedRecord 'OPENING_BALANCES' -RecommendedAction 'Enter opening cash/bank balances, opening inventory value and opening partner capital with evidence. Until then the Balance Sheet and Cash Flow are INCOMPLETE (nothing is assumed).' -RunId $RunId))
    } else {
        foreach ($grp in ($openRows | Group-Object { Format-PassressValue $_.AsOfDate 'date' })) {
            $lines = @(); foreach ($o in $grp.Group) { $lines += (L ([string]$o.AccountCode) (Get-Money $o.Debit) (Get-Money $o.Credit) $o.Counterparty); if ([string]$o.AccountCode -eq '1300') { $openingGLInventory += (Get-Money $o.Debit) - (Get-Money $o.Credit) } }
            $dr = Get-SumOf -Items $lines -Property 'Debit'; $cr = Get-SumOf -Items $lines -Property 'Credit'
            if (-not (Test-MoneyEqual $dr $cr)) { $ex.Add((New-PassressException -CheckName 'OPENING_BALANCES_UNBALANCED' -Severity ERROR -AffectedRecord ('as of ' + $grp.Name) -ExpectedValue $dr -ActualValue $cr -Difference (Get-RoundedMoney ($dr - $cr)) -RecommendedAction 'Opening debits must equal credits (balance with partner capital / retained earnings, with evidence). Not posted.' -RunId $RunId)); $openingMissing = $true; continue }
            & $addJournal ('JE-OPENING-' + $grp.Name) $grp.Group[0].AsOfDate $lines 'OPENING' ('OPENING-' + $grp.Name) $null $null $null 'Opening balances'
        }
    }
    if (-not (Test-MoneyEqual $openingInvValue $openingGLInventory)) {
        $ex.Add((New-PassressException -CheckName 'OPENING_INVENTORY_GL_MISMATCH' -Severity ERROR -AffectedRecord '1300' -ExpectedValue (Get-RoundedMoney $openingInvValue) -ActualValue (Get-RoundedMoney $openingGLInventory) -Difference (Get-RoundedMoney ($openingGLInventory - $openingInvValue)) -RecommendedAction 'Opening inventory value in 02 OPENING_INVENTORY must equal the 1300 opening balance in OPENING_BALANCES.' -RunId $RunId))
    }

    # ------------------------------------------------ partner capital reconciliation (sub-ledger vs GL 3000/3010/3200 by partner)
    $partnerRows = @{}
    $getP = { param($n) $k = if (Test-Blank $n) { '(unassigned)' } else { ([string]$n).Trim() }; if (-not $partnerRows.ContainsKey($k)) { $partnerRows[$k] = @{ Opening = 0.0; Dep = 0.0; Pers = 0.0; Wd = 0.0; G3000 = 0.0; G3010 = 0.0; G3200 = 0.0 } }; return $partnerRows[$k] }
    foreach ($c in $capital) { $p = & $getP $c.Partner; switch ($c.FundingType) { 'CASH_DEPOSIT' { $p.Dep += [double]$c.Amount } 'PAID_PERSONALLY' { $p.Pers += [double]$c.Amount } 'WITHDRAWAL' { $p.Wd += -1 * [double]$c.Amount } } }
    foreach ($l in $J) {
        if (@('3000', '3010', '3200') -notcontains [string]$l.AccountCode) { continue }
        $p = & $getP $l.Counterparty; $v = [double]$l.Credit - [double]$l.Debit
        switch ([string]$l.AccountCode) { '3000' { $p.G3000 += $v } '3010' { $p.G3010 += $v } '3200' { $p.G3200 += $v } }
        if ($l.SourceType -eq 'OPENING') { $p.Opening += $v }
    }
    $PCR = New-List
    foreach ($k in @($partnerRows.Keys | Sort-Object)) {
        $p = $partnerRows[$k]
        $sub = Get-RoundedMoney ($p.Opening + $p.Dep + $p.Pers - $p.Wd); $gl = Get-RoundedMoney ($p.G3000 + $p.G3010 + $p.G3200); $diff = Get-RoundedMoney ($gl - $sub)
        $st = if (Test-MoneyEqual $diff 0) { 'OK' } else { 'MISMATCH' }
        $PCR.Add([ordered]@{ Partner = $k; OpeningCapital = (Get-RoundedMoney $p.Opening); CashDeposits = (Get-RoundedMoney $p.Dep); PaidPersonally = (Get-RoundedMoney $p.Pers); Withdrawals = (Get-RoundedMoney $p.Wd); SubledgerBalance = $sub; GL3000 = (Get-RoundedMoney $p.G3000); GL3010 = (Get-RoundedMoney $p.G3010); GL3200 = (Get-RoundedMoney $p.G3200); GLBalance = $gl; Difference = $diff; NetCashContributed = (Get-RoundedMoney ($p.Dep - $p.Wd)); Status = $st })
        if ($st -ne 'OK') { $ex.Add((New-PassressException -CheckName 'PARTNER_CAPITAL_MISMATCH' -Severity ERROR -AffectedRecord $k -ExpectedValue $sub -ActualValue $gl -Difference $diff -RecommendedAction 'Partner capital in the ledger differs from the capital sub-ledger. Check postings to 3000/3010/3200 for this partner.' -RunId $RunId)) }
        if ($k -eq '(unassigned)' -and -not (Test-MoneyEqual $gl 0)) { $ex.Add((New-PassressException -CheckName 'CAPITAL_WITHOUT_PARTNER' -Severity WARNING -AffectedRecord $k -ActualValue $gl -RecommendedAction 'Capital postings without a partner name (opening balances without Counterparty?). Add the partner so balances are traceable.' -RunId $RunId)) }
    }

    # ------------------------------------------------ trial balance / statements
    $journal = $J.ToArray()
    # months with activity OR with blocking issues (an unposted entry must still show its month as INCOMPLETE)
    $months = Get-MonthRange -Months (@($journal | ForEach-Object { $_.Month }) + @($monthIssues.Keys | Where-Object { $_ }))
    $period = @{}   # month|account -> @(dr,cr)
    foreach ($l in $journal) { $k = $l.Month + '|' + $l.AccountCode; if (-not $period.ContainsKey($k)) { $period[$k] = @(0.0, 0.0) }; $period[$k][0] += [double]$l.Debit; $period[$k][1] += [double]$l.Credit }
    $accounts = @($coa.Keys | Sort-Object)
    $TB = New-List; $bal = @{}; foreach ($a in $accounts) { $bal[$a] = 0.0 }
    $tbByMonth = @{}
    foreach ($m in $months) {
        $tbByMonth[$m] = @{}
        foreach ($a in $accounts) {
            $k = $m + '|' + $a; $pd = 0.0; $pc = 0.0
            if ($period.ContainsKey($k)) { $pd = $period[$k][0]; $pc = $period[$k][1] }
            $bal[$a] = [double]$bal[$a] + $pd - $pc
            $tbByMonth[$m][$a] = @{ Dr = $pd; Cr = $pc; Bal = $bal[$a] }
            if ($pd -ne 0 -or $pc -ne 0 -or [math]::Abs($bal[$a]) -gt 0.004) { $TB.Add([ordered]@{ Month = $m; AccountCode = $a; AccountName = $coa[$a].AccountName; AccountType = $coa[$a].AccountType; PeriodDebit = (Get-RoundedMoney $pd); PeriodCredit = (Get-RoundedMoney $pc); ClosingBalance = (Get-RoundedMoney $bal[$a]) }) }
        }
    }
    $mov = { param($m, $a, [int]$sign) if ($tbByMonth[$m].ContainsKey($a)) { $x = $tbByMonth[$m][$a]; return (Get-RoundedMoney ($sign * ($x.Dr - $x.Cr))) } return 0.0 }
    $balOf = { param($m, $a) if ($tbByMonth[$m].ContainsKey($a)) { return [double]$tbByMonth[$m][$a].Bal } return 0.0 }
    $typeAccounts = { param($t) @($accounts | Where-Object { $coa[$_].AccountType -eq $t }) }

    $pendingByMonth = @{}; foreach ($c in @($Upstream.SALES_COSTED)) { if ([int](Get-Money $c.PendingRecognitionQty) -gt 0 -and $null -ne $c.EffectiveUnitCost) { Add-ToMap $pendingByMonth ([string]$c.OrderMonth) ([double]$c.PendingRecognitionQty * [double]$c.EffectiveUnitCost) } }
    $PL = New-List; $plNet = @{}; $plRev = @{}; $plCogs = @{}; $plOpex = @{}; $plMarketing = @{}; $plGP = @{}
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    foreach ($m in $months) {
        $dt = [datetime]::ParseExact($m + '-01', 'yyyy-MM-dd', $inv); $q = [int][math]::Ceiling($dt.Month / 3)
        $status = if ($monthIssues.ContainsKey($m)) { 'INCOMPLETE' } else { 'PRELIMINARY' }
        $add = { param($order, $section, $line, $amount) $PL.Add([ordered]@{ Month = $m; Quarter = ('{0}-Q{1}' -f $dt.Year, $q); Year = $dt.Year; SortOrder = $order; Section = $section; LineItem = $line; Amount = $amount; Status = $status }) }
        $gross = & $mov $m '4000' -1; $ship = & $mov $m '4010' -1; $disc = & $mov $m '4100' 1; $ref = & $mov $m '4200' 1; $refU = & $mov $m '4210' 1; $canc = & $mov $m '4300' 1
        $netRev = Get-RoundedMoney ($gross + $ship - $disc - $ref - $refU - $canc)
        $cogs = & $mov $m '5000' 1; $wo = & $mov $m '5100' 1; $gp = Get-RoundedMoney ($netRev - $cogs - $wo)
        & $add 10 'REVENUE' 'Gross Sales' $gross; & $add 20 'REVENUE' 'Shipping Income' $ship; & $add 30 'REVENUE' 'Discounts' (-$disc)
        & $add 40 'REVENUE' 'Refunds (line-item allocated)' (-$ref); & $add 45 'REVENUE' 'Refunds (unallocated)' (-$refU); & $add 50 'REVENUE' 'Cancellations' (-$canc)
        & $add 60 'REVENUE' 'Net Revenue' $netRev
        & $add 70 'COGS' 'Cost of Goods Sold' (-$cogs); & $add 75 'COGS' 'Inventory Write-offs & Adjustments' (-$wo)
        & $add 76 'MEMO' 'COGS pending recognition (memo, not posted)' (Get-RoundedMoney (-1 * [double](Get-MapValue $pendingByMonth $m 0)))
        & $add 80 'GROSS' 'Gross Profit' $gp; & $add 85 'RATIO' 'Gross Margin %' (Get-SafeDivide $gp $netRev)
        $opex = 0.0; $o = 100
        foreach ($a in (& $typeAccounts 'EXPENSE')) { $v = & $mov $m $a 1; $opex += $v; & $add $o 'OPEX' $coa[$a].AccountName (-$v); $o++ }
        $opex = Get-RoundedMoney $opex
        & $add 190 'OPEX' 'Total Operating Expenses' (-$opex)
        $opProfit = Get-RoundedMoney ($gp - $opex); & $add 200 'OPERATING' 'Operating Profit' $opProfit
        $oi = 0.0; foreach ($a in (& $typeAccounts 'OTHER_INCOME')) { $oi += & $mov $m $a -1 }
        $oe = 0.0; foreach ($a in (& $typeAccounts 'OTHER_EXPENSE')) { $oe += & $mov $m $a 1 }
        & $add 210 'OTHER' 'Other Income' (Get-RoundedMoney $oi); & $add 220 'OTHER' 'Other Expenses' (Get-RoundedMoney (-$oe))
        $np = Get-RoundedMoney ($opProfit + $oi - $oe)
        & $add 300 'NET' 'Net Profit' $np; & $add 310 'RATIO' 'Net Profit Margin %' (Get-SafeDivide $np $netRev)
        $plNet[$m] = $np; $plRev[$m] = $netRev; $plCogs[$m] = Get-RoundedMoney ($cogs + $wo); $plOpex[$m] = $opex; $plMarketing[$m] = (& $mov $m '6400' 1); $plGP[$m] = $gp
    }

    $BS = New-List; $CF = New-List; $cashAccounts = @($accounts | Where-Object { & $isCash $_ })
    $bsStatus = if ($openingMissing) { 'INCOMPLETE' } else { 'PRELIMINARY' }
    $prevCash = 0.0
    foreach ($m in $months) {
        $dt = [datetime]::ParseExact($m + '-01', 'yyyy-MM-dd', $inv)
        $fyYear = if ($dt.Month -ge $fyStart) { $dt.Year } else { $dt.Year - 1 }
        $fyStartDate = [datetime]::ParseExact(('{0:0000}-{1:00}-01' -f $fyYear, $fyStart), 'yyyy-MM-dd', $inv)
        $cash = 0.0; foreach ($a in $cashAccounts) { $cash += & $balOf $m $a }
        $special = @('1200', '1210', '1300', '1310', '1500') + $cashAccounts
        $otherAssets = 0.0; foreach ($a in (& $typeAccounts 'ASSET')) { if ($special -notcontains $a) { $otherAssets += & $balOf $m $a } }
        $assets = [ordered]@{ 'Cash & Bank' = $cash; 'Accounts Receivable - Customers' = (& $balOf $m '1200'); 'COD / Payment Clearing (courier, gateway)' = (& $balOf $m '1210'); 'Inventory - Finished Goods' = (& $balOf $m '1300'); 'Inventory - Materials, WIP & Advances' = (& $balOf $m '1310'); 'Fixed Assets' = (& $balOf $m '1500'); 'Other Assets' = $otherAssets }
        $otherLiab = 0.0; foreach ($a in (& $typeAccounts 'LIABILITY')) { if (@('2000', '2200') -notcontains $a) { $otherLiab += -1 * (& $balOf $m $a) } }
        $liab = [ordered]@{ 'Accounts Payable' = (-1 * (& $balOf $m '2000')); 'VAT / Tax Payable' = (-1 * (& $balOf $m '2200')); 'Other Liabilities' = $otherLiab }
        $priorProfit = 0.0; $ytdProfit = 0.0
        foreach ($pm in $months) { $pd = [datetime]::ParseExact($pm + '-01', 'yyyy-MM-dd', $inv); if ($pd -gt $dt) { continue }; if ($pd -lt $fyStartDate) { $priorProfit += $plNet[$pm] } else { $ytdProfit += $plNet[$pm] } }
        $otherEq = 0.0; foreach ($a in (& $typeAccounts 'EQUITY')) { if (@('3000', '3010', '3200', '3900') -notcontains $a) { $otherEq += -1 * (& $balOf $m $a) } }
        $equity = [ordered]@{ 'Partner Capital - Cash Deposits (Paid-Up)' = (-1 * (& $balOf $m '3000')); 'Partner Capital - Company Costs Paid Personally' = (-1 * (& $balOf $m '3010')); 'Partner Withdrawals' = (-1 * (& $balOf $m '3200')); 'Retained Earnings - Opening' = (-1 * (& $balOf $m '3900')); 'Retained Earnings - Prior Periods' = $priorProfit; 'Current Year Profit' = $ytdProfit; 'Other Equity' = $otherEq }
        $o = 10; $ta = 0.0
        foreach ($k in $assets.Keys) { $v = Get-RoundedMoney $assets[$k]; $ta += $v; $BS.Add([ordered]@{ Month = $m; SortOrder = $o; Section = 'ASSETS'; LineItem = $k; Amount = $v; Status = $bsStatus }); $o++ }
        $BS.Add([ordered]@{ Month = $m; SortOrder = 50; Section = 'ASSETS'; LineItem = 'TOTAL ASSETS'; Amount = (Get-RoundedMoney $ta); Status = $bsStatus })
        $o = 60; $tl = 0.0
        foreach ($k in $liab.Keys) { $v = Get-RoundedMoney $liab[$k]; $tl += $v; $BS.Add([ordered]@{ Month = $m; SortOrder = $o; Section = 'LIABILITIES'; LineItem = $k; Amount = $v; Status = $bsStatus }); $o++ }
        $BS.Add([ordered]@{ Month = $m; SortOrder = 80; Section = 'LIABILITIES'; LineItem = 'TOTAL LIABILITIES'; Amount = (Get-RoundedMoney $tl); Status = $bsStatus })
        $o = 90; $te = 0.0
        foreach ($k in $equity.Keys) { $v = Get-RoundedMoney $equity[$k]; $te += $v; $BS.Add([ordered]@{ Month = $m; SortOrder = $o; Section = 'EQUITY'; LineItem = $k; Amount = $v; Status = $bsStatus }); $o++ }
        $BS.Add([ordered]@{ Month = $m; SortOrder = 120; Section = 'EQUITY'; LineItem = 'TOTAL EQUITY'; Amount = (Get-RoundedMoney $te); Status = $bsStatus })
        $diff = Get-RoundedMoney ($ta - $tl - $te)
        $BS.Add([ordered]@{ Month = $m; SortOrder = 130; Section = 'CHECK'; LineItem = 'Assets - (Liabilities + Equity)'; Amount = $diff; Status = $bsStatus })
        if (-not (Test-MoneyEqual $diff 0)) { $ex.Add((New-PassressException -CheckName 'BALANCE_SHEET_DOES_NOT_BALANCE' -Severity ERROR -AffectedRecord $m -ExpectedValue 0 -ActualValue $diff -Difference $diff -RecommendedAction 'Internal control failed. Investigate journal entries for the month.' -RunId $RunId)) }

        # cash flow (direct): classify each cash line by the other accounts of its journal
        $cats = [ordered]@{ 'Opening balances recorded' = 0.0; 'Customer collections (COD / gateway remittances)' = 0.0; 'Owner capital deposits' = 0.0; 'Other inflows' = 0.0; 'Supplier & production payments' = 0.0; 'Operating expenses paid' = 0.0; 'Owner withdrawals' = 0.0; 'Asset purchases' = 0.0; 'Other outflows' = 0.0 }
        foreach ($grp in ($journal | Where-Object { $_.Month -eq $m } | Group-Object { $_.JournalID })) {
            $lines = @($grp.Group); $cashLines = @($lines | Where-Object { & $isCash $_.AccountCode }); if ($cashLines.Count -eq 0) { continue }
            $others = @($lines | Where-Object { -not (& $isCash $_.AccountCode) } | ForEach-Object { $_.AccountCode })
            $netCash = 0.0; foreach ($cl in $cashLines) { $netCash += [double]$cl.Debit - [double]$cl.Credit }
            if ($others.Count -eq 0) { continue }   # cash-to-cash transfer
            $cat = $null
            if ($lines[0].SourceType -eq 'OPENING') { $cat = 'Opening balances recorded' }
            elseif ($others -contains '1210' -or $others -contains '1200') { $cat = 'Customer collections (COD / gateway remittances)' }
            elseif ($others -contains '3000') { $cat = 'Owner capital deposits' }
            elseif ($others -contains '3200') { $cat = 'Owner withdrawals' }
            elseif ($others -contains '1310' -or $others -contains '1300' -or $others -contains '2000') { $cat = 'Supplier & production payments' }
            elseif ($others -contains '1500') { $cat = 'Asset purchases' }
            elseif (@($others | Where-Object { $coa[$_].AccountType -eq 'EXPENSE' }).Count -gt 0) { $cat = 'Operating expenses paid' }
            elseif ($netCash -ge 0) { $cat = 'Other inflows' } else { $cat = 'Other outflows' }
            $cats[$cat] += $netCash
        }
        $cfStatus = $bsStatus
        $CF.Add([ordered]@{ Month = $m; SortOrder = 10; LineItem = 'Opening Cash'; Amount = (Get-RoundedMoney $prevCash); Status = $cfStatus })
        $o = 20; $netMove = 0.0
        foreach ($k in $cats.Keys) { $v = Get-RoundedMoney $cats[$k]; $netMove += $v; $CF.Add([ordered]@{ Month = $m; SortOrder = $o; LineItem = $k; Amount = $v; Status = $cfStatus }); $o += 10 }
        $closing = Get-RoundedMoney ($prevCash + $netMove)
        $CF.Add([ordered]@{ Month = $m; SortOrder = 200; LineItem = 'Net Cash Movement'; Amount = (Get-RoundedMoney $netMove); Status = $cfStatus })
        $CF.Add([ordered]@{ Month = $m; SortOrder = 210; LineItem = 'Closing Cash'; Amount = $closing; Status = $cfStatus })
        $cfDiff = Get-RoundedMoney ($closing - $cash)
        $CF.Add([ordered]@{ Month = $m; SortOrder = 220; LineItem = 'Check: Closing Cash - Balance Sheet Cash'; Amount = $cfDiff; Status = $cfStatus })
        if (-not (Test-MoneyEqual $cfDiff 0)) { $ex.Add((New-PassressException -CheckName 'CASH_FLOW_VS_BALANCE_SHEET' -Severity ERROR -AffectedRecord $m -ExpectedValue (Get-RoundedMoney $cash) -ActualValue $closing -Difference $cfDiff -RecommendedAction 'Internal control failed: cash flow does not reconcile to balance-sheet cash.' -RunId $RunId)) }
        $prevCash = $closing
    }
    # COD clearing ageing: money marked received in Shopify but never remitted
    if ($months.Count -gt 0) {
        $lastM = $months[$months.Count - 1]; $clr = & $balOf $lastM '1210'
        if ($clr -gt 0.004) { $ex.Add((New-PassressException -CheckName 'UNRECONCILED_COD_REMITTANCE' -Severity WARNING -AffectedRecord '1210' -ExpectedValue 0 -ActualValue (Get-RoundedMoney $clr) -Difference (Get-RoundedMoney $clr) -RecommendedAction 'Shopify shows money received that has not been recorded as remitted to a company account. Record COD_REMITTANCE / COD_FEE rows from courier statements.' -RunId $RunId)) }
    }

    # ------------------------------------------------ order profitability / product P&L
    $OP = New-List; $costedByOrder = @{}
    foreach ($c in @($Upstream.SALES_COSTED)) { $og = [string]$c.OrderGID; if (-not $costedByOrder.ContainsKey($og)) { $costedByOrder[$og] = New-List }; $costedByOrder[$og].Add($c) }
    $evByOrder = @{}
    foreach ($ev in @($Upstream.REVENUE_EVENTS | Where-Object { $_.IsReportable })) { $og = [string]$ev.OrderGID; if (-not $evByOrder.ContainsKey($og)) { $evByOrder[$og] = New-List }; $evByOrder[$og].Add($ev) }
    $orderInfo = @{}; foreach ($f in @($Upstream.SALES_FACT | Where-Object { $_.IsReportable })) { $orderInfo[[string]$f.OrderGID] = $f }
    foreach ($og in $evByOrder.Keys) {
        $evs = $evByOrder[$og]; $f = $orderInfo[$og]
        $gross = 0.0; $disc = 0.0; $refs = 0.0; $canc = 0.0; $net = 0.0
        foreach ($ev in $evs) { $net += [double]$ev.NetAmount; if ($ev.EventType -eq 'SALE') { $gross += [double]$ev.GrossAmount; $disc += [double]$ev.DiscountAmount } elseif ($ev.EventType -eq 'SALE_SHIPPING') { $gross += [double]$ev.NetAmount } elseif ($ev.EventType -like 'REFUND_*') { $refs += -1 * [double]$ev.NetAmount } elseif ($ev.EventType -eq 'CANCELLATION') { $canc += -1 * [double]$ev.NetAmount } }
        $cogs = 0.0; $missing = $false
        if ($costedByOrder.ContainsKey($og)) { foreach ($c in $costedByOrder[$og]) { if ($null -eq $c.NetCOGS) { $missing = $true } else { $cogs += [double]$c.NetCOGS } } }
        $net = Get-RoundedMoney $net
        $contrib = if ($missing) { $null } else { Get-RoundedMoney ($net - $cogs) }
        $OP.Add([ordered]@{ OrderGID = $og; OrderName = $f.OrderName; OrderMonth = $f.OrderMonth; CustomerGID = $f.CustomerGID; GrossSales = (Get-RoundedMoney $gross); Discounts = (Get-RoundedMoney $disc); Refunds = (Get-RoundedMoney $refs); Cancellations = (Get-RoundedMoney $canc); NetRevenue = $net; NetCOGS = $(if ($missing) { $null } else { Get-RoundedMoney $cogs }); ShippingCost = $null; CODFees = $null; PackagingCost = $null; ContributionProfit = $contrib; ContributionMarginPct = $(if ($null -ne $contrib) { Get-SafeDivide $contrib $net } else { $null }); DataStatus = $(if ($missing) { 'MISSING_COST' } else { 'COMPLETE_EXCEPT_FULFILMENT_COSTS' }) })
    }

    $PP = New-List; $invBySku = @{}; foreach ($i in @($Upstream.INVENTORY)) { $invBySku[[string]$i.SKU] = $i }
    $recvBySku = @{}; foreach ($r in @($Upstream.REFUND_RETURN_RECONCILIATION | Where-Object { $_.Classification -eq 'REAL' -and $_.SKU })) { Add-ToMap $recvBySku ([string]$r.SKU) ([double]$r.ReceivedQty) }
    $costBySku = @{}; foreach ($c in @($Upstream.SALES_COSTED)) { $k = if ($c.SKU) { [string]$c.SKU } else { '(NO SKU)' }; if (-not $costBySku.ContainsKey($k)) { $costBySku[$k] = New-List }; $costBySku[$k].Add($c) }
    $factsBySku = @{}; foreach ($f in @($Upstream.SALES_FACT | Where-Object { $_.IsReportable })) { $k = if ($f.SKU) { [string]$f.SKU } else { '(NO SKU)' }; if (-not $factsBySku.ContainsKey($k)) { $factsBySku[$k] = New-List }; $factsBySku[$k].Add($f) }
    $ppNetTotal = 0.0
    foreach ($sku in @($factsBySku.Keys | Sort-Object)) {
        $fs = $factsBySku[$sku]
        $units = 0; $unitsRef = 0; $gross = 0.0; $disc = 0.0; $refs = 0.0; $canc = 0.0; $net = 0.0
        foreach ($f in $fs) { $units += [int]$f.QtyShipped; $unitsRef += [int]$f.QtyRefunded; $gross += [double]$f.GrossSales; $disc += [double]$f.LineDiscount; $refs += [double]$f.RefundAllocated; $canc += [double]$f.CancellationReversal; $net += [double]$f.NetRevenue }
        $cogs = 0.0; $missing = $false; $sellRet = 0
        foreach ($c in @(Get-MapValue $costBySku $sku @())) { $sellRet += [int]$c.SellableReturnedQty; if ($null -eq $c.NetCOGS) { $missing = $true } else { $cogs += [double]$c.NetCOGS } }
        $net = Get-RoundedMoney $net; $ppNetTotal += $net
        $gp = if ($missing) { $null } else { Get-RoundedMoney ($net - $cogs) }
        $netUnits = $units - $sellRet
        $PP.Add([ordered]@{ SKU = $sku; ProductTitle = $fs[0].ProductTitle; UnitsSold = $units; UnitsRefunded = $unitsRef; UnitsReturnedSellable = $sellRet; GrossSales = (Get-RoundedMoney $gross); Discounts = (Get-RoundedMoney $disc); Refunds = (Get-RoundedMoney $refs); Cancellations = (Get-RoundedMoney $canc); NetRevenue = $net; NetCOGS = $(if ($missing) { $null } else { Get-RoundedMoney $cogs }); GrossProfit = $gp; GrossMarginPct = $(if ($null -ne $gp) { Get-SafeDivide $gp $net } else { $null }); ReturnRatePct = (Get-SafeDivide (Get-MapValue $recvBySku $sku 0) $units); RefundRatePct = (Get-SafeDivide $refs $gross); AverageSellingPrice = (Get-SafeDivide $net $netUnits); InventoryValue = $(if ($invBySku.ContainsKey($sku)) { $invBySku[$sku].StockValue } else { $null }); CostStatus = $(if ($missing) { 'MISSING_COST' } else { 'OK' }) })
    }
    $orderLevel = @{ 'SALE_SHIPPING' = 'SHIPPING_INCOME'; 'REFUND_SHIPPING' = 'SHIPPING_INCOME'; 'REFUND_UNALLOCATED' = 'UNALLOCATED_REFUNDS'; 'REFUND_ADJUSTMENT' = 'UNALLOCATED_REFUNDS' }
    $special = @{}; foreach ($ev in @($Upstream.REVENUE_EVENTS | Where-Object { $_.IsReportable -and $orderLevel.ContainsKey([string]$_.EventType) })) { Add-ToMap $special $orderLevel[[string]$ev.EventType] ([double]$ev.NetAmount) }
    foreach ($k in $special.Keys) { $v = Get-RoundedMoney $special[$k]; $ppNetTotal += $v; $PP.Add([ordered]@{ SKU = $k; ProductTitle = '(order-level, not attributable to a product)'; UnitsSold = 0; UnitsRefunded = 0; UnitsReturnedSellable = 0; GrossSales = 0; Discounts = 0; Refunds = $(if ($k -eq 'UNALLOCATED_REFUNDS') { -$v } else { 0 }); Cancellations = 0; NetRevenue = $v; NetCOGS = 0; GrossProfit = $v; GrossMarginPct = $null; ReturnRatePct = $null; RefundRatePct = $null; AverageSellingPrice = $null; InventoryValue = $null; CostStatus = 'N/A' }) }

    # ------------------------------------------------ controls
    $plTotalRev = 0.0; foreach ($m in $months) { $plTotalRev += $plRev[$m] }
    $evTotal = 0.0; foreach ($ev in @($Upstream.REVENUE_EVENTS | Where-Object { $_.IsReportable })) { $evTotal += [double]$ev.NetAmount }
    if (-not (Test-MoneyEqual $plTotalRev $evTotal)) { $ex.Add((New-PassressException -CheckName 'PL_REVENUE_VS_REVENUE_EVENTS' -Severity ERROR -AffectedRecord 'ALL' -ExpectedValue (Get-RoundedMoney $evTotal) -ActualValue (Get-RoundedMoney $plTotalRev) -Difference (Get-RoundedMoney ($plTotalRev - $evTotal)) -RecommendedAction 'Net revenue in the P&L differs from the REAL revenue ledger (an event failed to post - see other exceptions).' -RunId $RunId)) }
    if (-not (Test-MoneyEqual $plTotalRev $ppNetTotal)) { $ex.Add((New-PassressException -CheckName 'PRODUCT_PL_VS_PL' -Severity ERROR -AffectedRecord 'ALL' -ExpectedValue (Get-RoundedMoney $plTotalRev) -ActualValue (Get-RoundedMoney $ppNetTotal) -Difference (Get-RoundedMoney ($ppNetTotal - $plTotalRev)) -RecommendedAction 'Product P&L (incl. order-level rows) must reconcile to P&L net revenue.' -RunId $RunId)) }
    $cogsEv = 0.0; foreach ($c in @($Upstream.COGS_EVENTS)) { if ($null -ne $c.Amount -and $c.EventType -ne 'TRANSIT_LOSS') { $cogsEv += [double]$c.Amount } }
    $cogsPl = 0.0; foreach ($m in $months) { $cogsPl += (& $mov $m '5000' 1) }
    if (-not (Test-MoneyEqual $cogsEv $cogsPl)) { $ex.Add((New-PassressException -CheckName 'PL_COGS_VS_OPERATIONS' -Severity ERROR -AffectedRecord 'ALL' -ExpectedValue (Get-RoundedMoney $cogsEv) -ActualValue (Get-RoundedMoney $cogsPl) -Difference (Get-RoundedMoney ($cogsPl - $cogsEv)) -RecommendedAction 'COGS in the P&L differs from 02 COGS_EVENTS.' -RunId $RunId)) }
    $dr = Get-SumOf -Items $journal -Property 'Debit'; $cr = Get-SumOf -Items $journal -Property 'Credit'
    if (-not (Test-MoneyEqual $dr $cr)) { $ex.Add((New-PassressException -CheckName 'JOURNAL_DEBITS_NE_CREDITS' -Severity ERROR -AffectedRecord 'ALL' -ExpectedValue $dr -ActualValue $cr -Difference (Get-RoundedMoney ($dr - $cr)) -RecommendedAction 'Internal control failed.' -RunId $RunId)) }
    foreach ($l in $journal) { if ($l.OrderName -and $testOrders.ContainsKey([string]$l.OrderName)) { $ex.Add((New-PassressException -CheckName 'TEST_ORDER_IN_FINANCE' -Severity ERROR -AffectedRecord $l.JournalID -OrderName $l.OrderName -Classification $testOrders[[string]$l.OrderName] -RecommendedAction 'A TEST/unclassified order reached the journal. This must never happen - report it.' -RunId $RunId)) } }
    $expPosted = 0.0; foreach ($l in $journal) { if ($l.SourceType -eq 'DATA_ENTRY' -and $coa[$l.AccountCode].AccountType -eq 'EXPENSE') { $expPosted += [double]$l.Debit - [double]$l.Credit } }
    $expPl = 0.0; foreach ($m in $months) { $expPl += $plOpex[$m] }
    $expFromCod = 0.0; foreach ($l in $journal) { if ($l.SourceType -ne 'DATA_ENTRY' -and $coa[$l.AccountCode].AccountType -eq 'EXPENSE') { $expFromCod += [double]$l.Debit - [double]$l.Credit } }
    if (-not (Test-MoneyEqual ($expPosted + $expFromCod) $expPl)) { $ex.Add((New-PassressException -CheckName 'EXPENSES_ENTERED_VS_PL' -Severity ERROR -AffectedRecord 'ALL' -ExpectedValue (Get-RoundedMoney ($expPosted + $expFromCod)) -ActualValue (Get-RoundedMoney $expPl) -RecommendedAction 'Posted expenses differ from P&L operating expenses.' -RunId $RunId)) }

    # inventory: stock ledger value (SELLABLE + IN_TRANSIT) must equal GL 1300 when all values and the opening balance are known
    $ledgerVal = 0.0; $ledgerKnown = $true
    foreach ($mv in @($Upstream.INVENTORY_MOVEMENTS)) { if ($mv.Bucket -eq 'SELLABLE' -or $mv.Bucket -eq 'IN_TRANSIT') { if ($null -eq $mv.Value) { $ledgerKnown = $false } else { $ledgerVal += [double]$mv.Value } } }
    $gl1300 = if ($bal.ContainsKey('1300')) { [double]$bal['1300'] } else { 0.0 }
    if ($ledgerKnown -and (-not $openingMissing -or (Test-MoneyEqual $openingInvValue 0)) -and -not (Test-MoneyEqual $ledgerVal $gl1300)) {
        $ex.Add((New-PassressException -CheckName 'INVENTORY_LEDGER_VS_GL' -Severity WARNING -AffectedRecord '1300' -ExpectedValue (Get-RoundedMoney $ledgerVal) -ActualValue (Get-RoundedMoney $gl1300) -Difference (Get-RoundedMoney ($gl1300 - $ledgerVal)) -RecommendedAction 'Stock ledger value differs from the finished-goods account (receipts without value, or opening balance mismatch).' -RunId $RunId))
    }

    # ------------------------------------------------ month close
    $closeStatus = New-List; $snap = @{}
    if ($null -ne $CloseSnapshots) { foreach ($p in $CloseSnapshots.PSObject.Properties) { $snap[$p.Name] = $p.Value } }
    $closed = @{}; foreach ($c in @($Inputs.MONTH_CLOSE)) { if (([string]$c.Status).ToUpperInvariant() -eq 'CLOSED' -and $c.Month) { $closed[[string]$c.Month] = $c } }
    foreach ($m in $months) {
        $np = $plNet[$m]
        if ($closed.ContainsKey($m)) {
            if (-not $snap.ContainsKey($m)) { $snap[$m] = [pscustomobject]@{ NetProfit = $np; NetRevenue = $plRev[$m]; COGS = $plCogs[$m]; TakenAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss', $inv); RunId = $RunId } }
            $s = $snap[$m]; $d = Get-RoundedMoney ($np - [double]$s.NetProfit)
            $res = if (Test-MoneyEqual $d 0) { 'UNCHANGED' } else { 'CHANGED_AFTER_CLOSE' }
            if ($res -ne 'UNCHANGED') { $ex.Add((New-PassressException -CheckName 'CLOSED_PERIOD_CHANGED' -Severity ERROR -AffectedRecord $m -ExpectedValue $s.NetProfit -ActualValue $np -Difference $d -RecommendedAction 'A closed month changed. Find the back-dated entry (cost edit, late transaction) and post it in an open month, or re-open the month with approval.' -RunId $RunId)) }
            $closeStatus.Add([ordered]@{ Month = $m; Status = 'CLOSED'; SnapshotTakenAt = $s.TakenAt; SnapshotNetProfit = $s.NetProfit; CurrentNetProfit = $np; Difference = $d; Result = $res })
        } else { $closeStatus.Add([ordered]@{ Month = $m; Status = 'OPEN'; SnapshotTakenAt = $null; SnapshotNetProfit = $null; CurrentNetProfit = $np; Difference = $null; Result = 'NOT_CLOSED' }) }
    }
    $snapObj = New-Object psobject; foreach ($k in $snap.Keys) { $snapObj | Add-Member -NotePropertyName $k -NotePropertyValue $snap[$k] }

    $tables = @{ JOURNAL_ENTRIES = $journal; TRIAL_BALANCE = $TB.ToArray(); PROFIT_AND_LOSS = $PL.ToArray(); BALANCE_SHEET = $BS.ToArray(); CASH_FLOW = $CF.ToArray(); ORDER_PROFITABILITY = $OP.ToArray(); PRODUCT_PL = $PP.ToArray(); CAPITAL_CONTRIBUTIONS = $capital.ToArray(); PARTNER_CAPITAL_RECONCILIATION = $PCR.ToArray(); MONTH_CLOSE_STATUS = $closeStatus.ToArray() }
    return [pscustomobject]@{ Tables = $tables; Exceptions = (Get-UniqueExceptions $ex.ToArray()); CloseSnapshots = $snapObj; Months = $months; MonthIssues = $monthIssues }
}
