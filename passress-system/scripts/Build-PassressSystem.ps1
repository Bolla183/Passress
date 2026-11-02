#Requires -Version 5.1
<#
.SYNOPSIS
  Step 2/3 - builds the PASSRESS folder structure and the four workbooks with Excel COM.
.DESCRIPTION
  * Creates PASSRESS_BUSINESS_SYSTEM\01..08 folders.
  * Copies the ORIGINAL workbook to 05_BACKUPS\00_ORIGINAL (read-only attribute), verifies the SHA-256 and never
    writes to the original. Legacy data is read from that copy, opened READ-ONLY, closed without saving.
  * Creates 01_DATA_SOURCE.xlsx, 02_OPERATIONS.xlsx, 03_FINANCE.xlsx, 04_MANAGEMENT.xlsx:
      HOME (status + guide), CONFIG (root parameter, upstream freshness), INPUT tables (typed, validated),
      REPORT tables (Power Query loads of engine CSVs), statements pivots (03), CONTROLS (formula checks).
  * Existing workbooks are never overwritten unless -Rebuild is given, and then only after a timestamped backup.
.EXAMPLE
  .\Build-PassressSystem.ps1 -ConfigPath C:\PASSRESS_BUSINESS_SYSTEM\07_CONFIGURATION\passress.config.json -OriginalWorkbookPath "C:\Users\me\Downloads\Passress(3).xlsx"
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ConfigPath, [string]$OriginalWorkbookPath, [switch]$Rebuild, [switch]$Visible, [string[]]$Only)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent; $src = Join-Path $repo 'src'
Import-Module (Join-Path $src 'Passress.Common.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $src 'Passress.Engine.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $src 'Passress.Excel.psm1') -Force -DisableNameChecking

$cfg = Get-PassressConfig -Path $ConfigPath
$paths = Get-PassressPaths -Config $cfg
foreach ($d in @($paths.Root, $paths.Backups, $paths.Documentation, $paths.Configuration, $paths.Logs, $paths.Staging)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }
foreach ($w in $paths.Workbooks.Values) { foreach ($d in @($w.Folder, $w.Outputs, $w.Inputs, $w.State)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } } }
Set-PassressLogFile (Join-Path $paths.Logs ('build_{0}.log' -f (Get-Date -Format 'yyyyMMdd_HHmmss')))
Write-PassressLog -Message "Build started. Root: $($paths.Root)"

# .gitignore guard in case the business folder is ever placed under source control
$gi = Join-Path $paths.Root '.gitignore'
if (-not (Test-Path $gi)) { Set-Content -LiteralPath $gi -Encoding UTF8 -Value "# PASSRESS business data - never commit`r`n*`r`n" }

# documentation
$docSrc = Join-Path $repo 'docs'; if (Test-Path $docSrc) { Copy-Item -Path (Join-Path $docSrc '*') -Destination $paths.Documentation -Recurse -Force }

# ------------------------------------------------------------------ preserve original
$legacyCopy = $null
if ($OriginalWorkbookPath) {
    $fp = Get-PassressFileFingerprint -Path $OriginalWorkbookPath
    Write-PassressLog -Message ("Original: {0} | {1} bytes | {2} | SHA-256 {3}" -f $fp.Path, $fp.SizeBytes, $fp.LastWriteTimeUtc, $fp.SHA256)
    $expected = [string](Get-PassressConfigValue $cfg 'ExpectedOriginalSha256' '')
    if ($expected -and $fp.SHA256 -ne $expected) { Write-PassressLog -Level WARN -Message 'Original workbook hash differs from the audited file (9944f490...). Continuing with the file provided; migrated data comes from THIS file.' }
    $origDir = Join-Path $paths.Backups '00_ORIGINAL'; if (-not (Test-Path $origDir)) { New-Item -ItemType Directory -Path $origDir -Force | Out-Null }
    $legacyCopy = Join-Path $origDir (Split-Path $OriginalWorkbookPath -Leaf)
    if (-not (Test-Path -LiteralPath $legacyCopy)) { Copy-Item -LiteralPath $OriginalWorkbookPath -Destination $legacyCopy }
    $copyFp = Get-PassressFileFingerprint -Path $legacyCopy
    if ($copyFp.SHA256 -ne $fp.SHA256) { throw "Preserved copy hash mismatch ($legacyCopy). Stopping." }
    (Get-Item -LiteralPath $legacyCopy).IsReadOnly = $true
    Write-PassressJson -Object $fp -Path (Join-Path $origDir 'ORIGINAL_FINGERPRINT.json')
}

Initialize-PassressOutputFiles -Config $cfg

# ------------------------------------------------------------------ list values
$sep = ','
$lists = @{
    ORDER_CLASSIFICATION = @{ Classification = @('TEST', 'REAL') }
    HEIRARCHY = @{ ActiveStatus = @('ACTIVE', 'INACTIVE') }
    PRODUCTION = @{ Status = @('PLANNED', 'IN_PROGRESS', 'RECEIVED', 'CANCELLED') }
    SUPPLIERS = @{ SupplierType = @('FABRIC', 'WORKSHOP', 'PACKAGING', 'COURIER', 'OTHER') }
    PURCHASES = @{ ItemType = @('SKU', 'MATERIAL'); Status = @('ORDERED', 'PARTIAL', 'RECEIVED', 'CANCELLED') }
    RETURNS = @{ PhysicalReturnStatus = @('NOT_RETURNED', 'RETURN_REQUESTED', 'IN_TRANSIT', 'RECEIVED', 'INSPECTION_PENDING', 'CLOSED') }
    RETURN_INSPECTIONS = @{ InspectionStatus = @('PENDING_INSPECTION', 'COMPLETE') }
    DELIVERY_CONFIRMATIONS = @{ Source = @('COURIER_STATEMENT', 'COURIER_PORTAL', 'CUSTOMER_CONFIRMATION', 'OTHER') }
    INVENTORY_ADJUSTMENTS = @{ Bucket = @('SELLABLE', 'DAMAGED'); Reason = @('COUNT', 'DAMAGE', 'WRITE_OFF', 'OTHER') }
    DATA_ENTRY = @{ TransactionType = @('EXPENSE', 'PRODUCTION_PAYMENT', 'INVENTORY_PURCHASE', 'ASSET_PURCHASE', 'CAPITAL_DEPOSIT', 'OWNER_WITHDRAWAL', 'OTHER_INCOME', 'OTHER_EXPENSE', 'COD_REMITTANCE', 'COD_FEE', 'TRANSFER'); PaymentSource = @('COMPANY', 'PARTNER_PERSONAL'); PaymentAccount = @('1000', '1010', '1020', '1030'); Category = @((Get-PassressDefaultExpenseMap) | ForEach-Object { $_.Category }); PaymentMethod = @('Cash', 'InstaPay', 'Bank Transfer', 'Credit Card', 'Vodafone Cash'); ReviewStatus = @('PENDING_REVIEW', 'APPROVED') }
    CHART_OF_ACCOUNTS = @{ AccountType = @('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'CONTRA_REVENUE', 'COGS', 'EXPENSE', 'OTHER_INCOME', 'OTHER_EXPENSE') }
    MONTH_CLOSE = @{ Status = @('OPEN', 'CLOSED') }
    BUDGET_INPUT = @{ ValueType = @('BUDGET', 'FORECAST'); LineItem = @('Net Revenue', 'COGS', 'Gross Profit', 'Marketing', 'Operating Expenses', 'Net Profit', 'Closing Cash') }
}

# ------------------------------------------------------------------ seeds
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$decided = [datetime]::ParseExact('2026-11-01', 'yyyy-MM-dd', $inv)
# Order ids of #1001-#1009 from the audited workbook (SALES sheet). Approved decision: TEST ORDERS.
$testOrders = [ordered]@{ '#1001' = '12203059675500'; '#1002' = '18928905683308'; '#1003' = '18928925802860'; '#1004' = '18947365962092'; '#1005' = '18953305129324'; '#1006' = '18953478603116'; '#1007' = '18968573641068'; '#1008' = '18971894907244'; '#1009' = '18981663048044' }
$seeds = @{}
$seeds['ORDER_CLASSIFICATION'] = @($testOrders.Keys | ForEach-Object { [ordered]@{ OrderGID = ('gid://shopify/Order/' + $testOrders[$_]); OrderName = $_; Classification = 'TEST'; Reason = 'Approved Phase 2 decision: orders #1001-#1009 are test orders (kept in raw data for audit).'; EffectiveDate = $decided; UpdatedAt = (Get-Date); UpdatedBy = 'Phase 2 build' } })
$seeds['CHART_OF_ACCOUNTS'] = Get-PassressDefaultChartOfAccounts
$seeds['EXPENSE_CATEGORY_MAP'] = Get-PassressDefaultExpenseMap
$seeds['MONTH_CLOSE'] = @()

# ------------------------------------------------------------------ legacy migration (read-only)
$session = $null
try {
    $session = New-PassressExcel -Visible:$Visible
    Write-PassressLog -Message ("Excel {0} build {1} started via COM (PID {2})." -f $session.Version, $session.Build, $session.ProcessId)
    if ($legacyCopy) {
        $owb = Open-PassressWorkbook -Session $session -Path $legacyCopy -ReadOnly
        try {
            $ws = $owb.Worksheets.Item('DATA ENTRY SHEET')
            $vals = $ws.Range('A2:K5001').Value2; $legacy = @(); $n = 0
            for ($r = 1; $r -le 5000; $r++) {
                $row = @(); $any = $false; for ($c = 1; $c -le 11; $c++) { $v = $vals[$r, $c]; $row += , $v; if ($null -ne $v -and "$v" -ne '') { $any = $true } }
                if (-not $any) { continue }
                $n++
                $ltype = [string]$row[1]
                $newType = switch -Regex ($ltype) { '^(?i)capital$' { 'CAPITAL_DEPOSIT' } '^(?i)paid-up capital$' { 'CAPITAL_DEPOSIT' } '^(?i)cogs$' { 'PRODUCTION_PAYMENT' } '^(?i)expenses$' { 'EXPENSE' } default { $null } }
                $legacy += [ordered]@{
                    TransactionID = ('LEG-{0:0000}' -f $n); TransactionDate = $(if ($row[0] -is [double]) { [DateTime]::FromOADate($row[0]) } else { $null })
                    TransactionType = $newType; Category = $row[2]; Subcategory = $row[3]; ProductType = $row[4]; ProductSKU = $row[5]; Description = $row[6]
                    Amount = $row[8]; PaymentSource = $null; PaymentAccount = $null; PaymentMethod = $row[7]; PaidBy = $row[9]
                    Notes = ('Migrated from Passress(3).xlsx DATA ENTRY row {0}. TransactionType is a PROVISIONAL suggestion. Confirm it, complete PaymentSource (COMPANY / PARTNER_PERSONAL) and PaymentAccount, then set ReviewStatus = APPROVED - nothing is posted before that. {1}' -f ($r + 1), $row[10]).Trim()
                    ReviewStatus = 'PENDING_REVIEW'; ReviewedBy = $null
                    LegacyType = $ltype; LegacyCategory = $row[2]
                }
            }
            $seeds['DATA_ENTRY'] = $legacy
            Write-PassressLog -Message "Legacy DATA ENTRY rows read: $n (migrated unposted; PaymentSource left blank on purpose - see exceptions)."
            $cost = @(); $hier = @()
            $lo = $null; foreach ($s in @($owb.Worksheets)) { foreach ($l in @($s.ListObjects)) { if ($l.Name -eq 'Table4') { $lo = $l } } }
            if ($lo -and $lo.DataBodyRange) {
                $cv = $lo.DataBodyRange.Value2; $rows = $lo.DataBodyRange.Rows.Count; $k = 0
                for ($r = 1; $r -le $rows; $r++) {
                    $sku = [string]$cv[$r, 1]; if (-not $sku) { continue }
                    $hier += [ordered]@{ SKU = $sku; ProductName = $cv[$r, 2]; ActiveStatus = 'ACTIVE' }
                    $total = $cv[$r, 14]
                    if ($null -ne $total -and "$total" -ne '' -and [double]$total -gt 0) {
                        $k++
                        $cost += [ordered]@{ CostRecordID = ('COST-LEG-{0:000}' -f $k); SKU = $sku; UnitCost = [double]$total; Currency = 'EGP'; EffectiveFrom = $null; EffectiveTo = $null; Source = 'Passress(3).xlsx COST sheet (Fabric Meter/Price labels look swapped - confirm)'; ApprovedBy = $null; CreatedAt = (Get-Date); Notes = 'NOT APPROVED: enter EffectiveFrom + ApprovedBy after confirming. Ignored by costing until then.' }
                    }
                }
            }
            $seeds['COST_MASTER'] = $cost; $seeds['HEIRARCHY'] = $hier
            Write-PassressLog -Message ("Legacy COST rows: {0} SKUs listed, {1} with a total cost (migrated as UNAPPROVED)." -f $hier.Count, $cost.Count)
        } finally { $owb.Close($false) }
        $after = Get-PassressFileFingerprint -Path $OriginalWorkbookPath
        if ($after.SHA256 -ne $fp.SHA256) { throw 'ORIGINAL WORKBOOK CHANGED during build - stop and restore from 05_BACKUPS\00_ORIGINAL.' }
        Write-PassressLog -Level OK -Message 'Original workbook verified unchanged (SHA-256 identical).'
    }

    # ------------------------------------------------------------------ workbook builder
    $schema = Get-PassressSchema
    $titles = @{ '01_DATA_SOURCE' = 'PASSRESS - 01 DATA SOURCE'; '02_OPERATIONS' = 'PASSRESS - 02 OPERATIONS'; '03_FINANCE' = 'PASSRESS - 03 FINANCE'; '04_MANAGEMENT' = 'PASSRESS - 04 MANAGEMENT' }
    $purpose = @{
        '01_DATA_SOURCE' = 'Shopify data (read-only extract) normalised to line level: orders, line items, refunds, refund line items, refund transactions, customers, products. Classify test orders in ORDER_CLASSIFICATION.'
        '02_OPERATIONS' = 'Costs (effective-dated, append-only), physical returns and inspections, production, purchases, stock ledger, costed sales.'
        '03_FINANCE' = 'Manual transactions, double-entry journal, preliminary P&L / Balance Sheet / Cash Flow, order and product profitability, partner capital, month close.'
        '04_MANAGEMENT' = 'Dashboard, KPIs, product / customer / marketing / inventory views and budget vs actual - REAL orders only, with data-quality status on every figure.'
    }
    $upstreamOf = @{ '02_OPERATIONS' = '01_DATA_SOURCE'; '03_FINANCE' = '02_OPERATIONS'; '04_MANAGEMENT' = '03_FINANCE' }
    $built = @()
    foreach ($stage in @('01_DATA_SOURCE', '02_OPERATIONS', '03_FINANCE', '04_MANAGEMENT')) {
        if ($Only -and $Only -notcontains $stage) { continue }
        $target = $paths.Workbooks[$stage].File
        if (Test-Path -LiteralPath $target) {
            if (-not $Rebuild) { Write-PassressLog -Level WARN -Message "$target exists - skipped (use -Rebuild to recreate; a backup is taken first)."; continue }
            if (-not (Test-PassressFileUnlocked $target)) { throw "WORKBOOK_LOCKED: close $target first." }
            $b = Backup-PassressFiles -Paths @($target) -BackupRoot $paths.Backups -Label ("pre-rebuild_$stage") -RelativeTo $paths.Root
            Write-PassressLog -Message "Backed up existing workbook to $($b.Folder)"
            Remove-Item -LiteralPath $target -Force
        }
        Write-PassressLog -Message "Building $stage ..."
        $wb = $session.App.Workbooks.Add()
        $saved = $false
        try {
            while ($wb.Worksheets.Count -gt 1) { $wb.Worksheets.Item($wb.Worksheets.Count).Delete() }
            $homeWs = $wb.Worksheets.Item(1); $homeWs.Name = 'HOME'
            $cfgWs = $wb.Worksheets.Add([System.Reflection.Missing]::Value, $homeWs); $cfgWs.Name = 'CONFIG'
            Set-PassressRootParameter -Workbook $wb -RootFolder $paths.Root
            Set-PassressSheetHeader -Worksheet $cfgWs -Title 'CONFIG' -Subtitle 'Technical settings. Root folder is changed only with scripts\Set-PassressRootFolder.ps1.' -Kind CONTROL
            $cfgWs.Cells.Item(4, 1).Value2 = 'Root folder (Power Query parameter pRootFolder)'; $cfgWs.Cells.Item(4, 2).Value2 = $paths.Root
            $cfgWs.Cells.Item(5, 1).Value2 = 'Workbook stage'; $cfgWs.Cells.Item(5, 2).Value2 = $stage
            $cfgWs.Cells.Item(6, 1).Value2 = 'Schema version'; $cfgWs.Cells.Item(6, 2).Value2 = [string]$schema.version
            $cfgWs.Cells.Item(7, 1).Value2 = 'Shop / API version'; $cfgWs.Cells.Item(7, 2).Value2 = ('{0} / {1}' -f $cfg.ShopDomain, $cfg.ApiVersion)
            $cfgWs.Cells.Item(8, 1).Value2 = 'Credentials'; $cfgWs.Cells.Item(8, 2).Value2 = 'Never stored in this workbook (encrypted Windows credential store, see 06_DOCUMENTATION).'
            if ($upstreamOf.ContainsKey($stage)) {
                $cfgWs.Cells.Item(10, 1).Value2 = ('Upstream workbook freshness ({0}, last saved version):' -f $upstreamOf[$stage]); $cfgWs.Cells.Item(10, 1).Font.Bold = $true
                [void](Add-PassressQueryTable -Workbook $wb -Worksheet $cfgWs -Name 'UPSTREAM_STATUS' -Formula (New-PassressUpstreamQueryFormula -UpstreamStage $upstreamOf[$stage]) -Anchor 'A11')
            }
            $guideRows = @()
            $last = $cfgWs
            foreach ($t in @($schema.workbooks.$stage.tables)) {
                $ts = Get-PassressTableSchema -Workbook $stage -Table $t.name
                $ws = $wb.Worksheets.Add([System.Reflection.Missing]::Value, $last); $ws.Name = $t.name; $last = $ws
                if ($t.kind -eq 'input') {
                    Set-PassressSheetHeader -Worksheet $ws -Title $t.name -Subtitle $t.purpose -Kind INPUT
                    $tl = if ($lists.ContainsKey($t.name)) { $lists[$t.name] } else { @{} }
                    $sd = if ($seeds.ContainsKey($t.name)) { @($seeds[$t.name]) } else { @() }
                    [void](Add-PassressInputTable -Worksheet $ws -TableSchema $ts -SeedRows $sd -Lists $tl -ListSeparator $sep -Anchor 'A4')
                    $guideRows += , @($t.name, 'INPUT', $t.purpose)
                } else {
                    Set-PassressSheetHeader -Worksheet $ws -Title $t.name -Subtitle $t.purpose -Kind REPORT
                    [void](Add-PassressQueryTable -Workbook $wb -Worksheet $ws -Name $t.name -Formula (New-PassressCsvQueryFormula -Stage $stage -Table $t.name) -Anchor 'A4')
                    $guideRows += , @($t.name, 'REPORT', $t.purpose)
                }
                $ws.Activate(); $session.App.ActiveWindow.SplitRow = 4; $session.App.ActiveWindow.SplitColumn = 0; $session.App.ActiveWindow.FreezePanes = $true
                $session.App.ActiveWindow.DisplayGridlines = $false
            }

            # statements as pivots (03) - monthly, quarterly, annual
            if ($stage -eq '03_FINANCE') {
                $pivots = @(
                    @{ Sheet = 'PL_MONTHLY'; Source = 'PROFIT_AND_LOSS'; Name = 'PT_PL_MONTHLY'; Cols = @('Month'); Rows = @('SortOrder', 'Section', 'LineItem'); Title = 'Profit & Loss by month (PRELIMINARY - see Status column in PROFIT_AND_LOSS)' }
                    @{ Sheet = 'PL_QUARTERLY'; Source = 'PROFIT_AND_LOSS'; Name = 'PT_PL_QUARTERLY_NORATIO'; Cols = @('Quarter'); Rows = @('SortOrder', 'Section', 'LineItem'); Title = 'Profit & Loss by quarter (percentage rows hidden - see monthly view)' }
                    @{ Sheet = 'PL_ANNUAL'; Source = 'PROFIT_AND_LOSS'; Name = 'PT_PL_ANNUAL_NORATIO'; Cols = @('Year'); Rows = @('SortOrder', 'Section', 'LineItem'); Title = 'Profit & Loss by year / year-to-date' }
                    @{ Sheet = 'BS_VIEW'; Source = 'BALANCE_SHEET'; Name = 'PT_BS'; Cols = @('Month'); Rows = @('SortOrder', 'Section', 'LineItem'); Title = 'Preliminary management Balance Sheet (month end)' }
                    @{ Sheet = 'CF_VIEW'; Source = 'CASH_FLOW'; Name = 'PT_CF'; Cols = @('Month'); Rows = @('SortOrder', 'LineItem'); Title = 'Cash Flow (direct method)' }
                )
                foreach ($p in $pivots) {
                    $ws = $wb.Worksheets.Add([System.Reflection.Missing]::Value, $homeWs); $ws.Name = $p.Sheet
                    Set-PassressSheetHeader -Worksheet $ws -Title $p.Sheet -Subtitle $p.Title -Kind REPORT
                    try {
                        $pc = $wb.PivotCaches().Create(1, $p.Source, 5)
                        $pt = $pc.CreatePivotTable($ws.Range('A5'), $p.Name, $true, 5)
                        $pos = 1; foreach ($r in $p.Rows) { $f = $pt.PivotFields($r); $f.Orientation = 1; $f.Position = $pos; $pos++; try { $f.Subtotals = [object[]](@($false) * 12) } catch { } }
                        foreach ($c in $p.Cols) { $pt.PivotFields($c).Orientation = 2 }
                        [void]$pt.AddDataField($pt.PivotFields('Amount'), 'EGP ', -4157)
                        $pt.RowAxisLayout(1); $pt.ColumnGrand = $false; $pt.RowGrand = $false
                        try { $pt.DataBodyRange.NumberFormat = '#,##0.00;[Red]-#,##0.00' } catch { }
                    } catch { Write-PassressLog -Level WARN -Message "Pivot $($p.Name) could not be created: $($_.Exception.Message)" }
                }
            }

            # CONTROLS sheet (Excel-native checks, independent of the engine)
            $ctl = $wb.Worksheets.Add([System.Reflection.Missing]::Value, $homeWs); $ctl.Name = 'CONTROLS'
            Set-PassressSheetHeader -Worksheet $ctl -Title 'CONTROLS' -Subtitle 'Formula checks recalculated by Excel. Every Result must read OK.' -Kind CONTROL
            $ctlRows = @()
            switch ($stage) {
                '01_DATA_SOURCE' { $ctlRows = @(
                    @('Open ERROR exceptions', '=COUNTIFS(EXCEPTIONS[Severity],"ERROR")', '=IF(B5=0,"OK","REVIEW")'),
                    @('Test orders excluded (info)', '=COUNTIFS(EXCEPTIONS[CheckName],"TEST_ORDER_EXCLUDED")', '="INFO"'),
                    @('Unallocated refunds (count)', '=COUNTIFS(REFUND_RECONCILIATION[Status],"UNALLOCATED")+COUNTIFS(REFUND_RECONCILIATION[Status],"MISMATCH")', '=IF(B7=0,"OK","REVIEW")'),
                    @('REAL lines in SALES_FACT', '=COUNTIFS(SALES_FACT[IsReportable],TRUE)', '="INFO"')) }
                '02_OPERATIONS' { $ctlRows = @(
                    @('Cost ERROR exceptions', '=COUNTIFS(COST_EXCEPTIONS[Severity],"ERROR")', '=IF(B5=0,"OK","REVIEW")'),
                    @('Inventory ERROR exceptions', '=COUNTIFS(INVENTORY_EXCEPTIONS[Severity],"ERROR")', '=IF(B6=0,"OK","REVIEW")'),
                    @('SKUs with negative stock', '=COUNTIFS(INVENTORY[StockStatus],"NEGATIVE")', '=IF(B7=0,"OK","FAIL")'),
                    @('Lines missing cost', '=COUNTIFS(SALES_COSTED[CostStatus],"MISSING_COST")+COUNTIFS(SALES_COSTED[CostStatus],"MISSING_SKU")', '=IF(B8=0,"OK","INCOMPLETE")'),
                    @('Lines with COGS pending recognition (trigger not met)', '=COUNTIFS(SALES_COSTED[RecognitionStatus],"PENDING")+COUNTIFS(SALES_COSTED[RecognitionStatus],"PARTIAL")', '=IF(B9=0,"OK","PENDING")')) }
                '03_FINANCE' { $ctlRows = @(
                    @('Journal debits - credits', '=ROUND(SUM(JOURNAL_ENTRIES[Debit])-SUM(JOURNAL_ENTRIES[Credit]),2)', '=IF(B5=0,"OK","FAIL")'),
                    @('Balance sheet checks (sum of monthly A-(L+E))', '=ROUND(SUMIFS(BALANCE_SHEET[Amount],BALANCE_SHEET[Section],"CHECK"),2)', '=IF(B6=0,"OK","FAIL")'),
                    @('Cash flow vs balance sheet cash', '=ROUND(SUMIFS(CASH_FLOW[Amount],CASH_FLOW[LineItem],"Check: Closing Cash - Balance Sheet Cash"),2)', '=IF(B7=0,"OK","FAIL")'),
                    @('P&L net revenue - journal revenue accounts', '=ROUND(SUMIFS(PROFIT_AND_LOSS[Amount],PROFIT_AND_LOSS[LineItem],"Net Revenue")-(SUMIFS(JOURNAL_ENTRIES[Credit],JOURNAL_ENTRIES[AccountCode],"4*")-SUMIFS(JOURNAL_ENTRIES[Debit],JOURNAL_ENTRIES[AccountCode],"4*")),2)', '=IF(B8=0,"OK","FAIL")'),
                    @('P&L COGS - journal COGS accounts', '=ROUND(-SUMIFS(PROFIT_AND_LOSS[Amount],PROFIT_AND_LOSS[Section],"COGS")-(SUMIFS(JOURNAL_ENTRIES[Debit],JOURNAL_ENTRIES[AccountCode],"5*")-SUMIFS(JOURNAL_ENTRIES[Credit],JOURNAL_ENTRIES[AccountCode],"5*")),2)', '=IF(B9=0,"OK","FAIL")'),
                    @('Test orders in journal', '=COUNTIFS(FINANCE_EXCEPTIONS[CheckName],"TEST_ORDER_IN_FINANCE")', '=IF(B10=0,"OK","FAIL")'),
                    @('Open ERROR exceptions', '=COUNTIFS(FINANCE_EXCEPTIONS[Severity],"ERROR")', '=IF(B11=0,"OK","REVIEW")'),
                    @('Months marked INCOMPLETE', '=COUNTIFS(PROFIT_AND_LOSS[Status],"INCOMPLETE",PROFIT_AND_LOSS[LineItem],"Net Profit")', '=IF(B12=0,"OK","INCOMPLETE")'),
                    @('Partner capital: sub-ledger vs GL mismatches', '=COUNTIFS(PARTNER_CAPITAL_RECONCILIATION[Status],"MISMATCH")', '=IF(B13=0,"OK","FAIL")'),
                    @('Legacy / pending-review rows not posted', '=COUNTIFS(FINANCE_EXCEPTIONS[CheckName],"LEGACY_ROW_PENDING_REVIEW")+COUNTIFS(FINANCE_EXCEPTIONS[CheckName],"ROW_PENDING_REVIEW")', '=IF(B14=0,"OK","REVIEW")')) }
                '04_MANAGEMENT' { $ctlRows = @(
                    @('Test orders in management data', '=COUNTIFS(MANAGEMENT_EXCEPTIONS[CheckName],"TEST_ORDER_IN_MANAGEMENT")', '=IF(B5=0,"OK","FAIL")'),
                    @('Reconciliation failures vs Finance', '=COUNTIFS(MANAGEMENT_EXCEPTIONS[CheckName],"KPI_REVENUE_VS_FINANCE")+COUNTIFS(MANAGEMENT_EXCEPTIONS[CheckName],"DASHBOARD_PROFIT_VS_FINANCE")', '=IF(B6=0,"OK","FAIL")'),
                    @('Months with INCOMPLETE data', '=COUNTIFS(KPI_MONTHLY[DataStatus],"INCOMPLETE")', '=IF(B7=0,"OK","INCOMPLETE")')) }
            }
            $ctl.Cells.Item(4, 1).Value2 = 'Check'; $ctl.Cells.Item(4, 2).Value2 = 'Value'; $ctl.Cells.Item(4, 3).Value2 = 'Result'
            $ctl.Range('A4:C4').Font.Bold = $true
            for ($i = 0; $i -lt $ctlRows.Count; $i++) { $ctl.Cells.Item(5 + $i, 1).Value2 = $ctlRows[$i][0]; $ctl.Cells.Item(5 + $i, 2).Formula = $ctlRows[$i][1]; $ctl.Cells.Item(5 + $i, 3).Formula = $ctlRows[$i][2] }
            $ctl.Columns.Item(1).ColumnWidth = 52; $ctl.Columns.Item(2).ColumnWidth = 16; $ctl.Columns.Item(3).ColumnWidth = 14

            # 04: trend chart on the dashboard sheet
            if ($stage -eq '04_MANAGEMENT') {
                try {
                    $dash = $wb.Worksheets.Item('EXECUTIVE_DASHBOARD'); $kpi = (Get-PassressListObject -Workbook $wb -Name 'KPI_MONTHLY')
                    $ch = $dash.Shapes.AddChart2(227, 4, 700, 60, 520, 280).Chart
                    $src = $session.App.Union($kpi.ListColumns.Item('Month').Range, $kpi.ListColumns.Item('NetRevenue').Range, $kpi.ListColumns.Item('NetProfit').Range)
                    $ch.SetSourceData($src); $ch.HasTitle = $true; $ch.ChartTitle.Text = 'Net revenue and net profit by month (REAL orders)'
                } catch { Write-PassressLog -Level WARN -Message "Dashboard chart not created: $($_.Exception.Message)" }
            }

            # HOME
            Set-PassressSheetHeader -Worksheet $homeWs -Title $titles[$stage] -Subtitle $purpose[$stage] -Kind HOME
            $homeWs.Cells.Item(4, 1).Value2 = 'REFRESH STATUS'; $homeWs.Cells.Item(4, 1).Font.Bold = $true
            $status = @(
                @('Last refresh run', '=IF(COUNTA(LOG_REFRESH[RunId])=0,"never",INDEX(LOG_REFRESH[RunId],COUNTA(LOG_REFRESH[RunId])))'),
                @('Finished at', '=IF(COUNTA(LOG_REFRESH[RunId])=0,"",INDEX(LOG_REFRESH[EndedAt],COUNTA(LOG_REFRESH[RunId])))'),
                @('Status', '=IF(COUNTA(LOG_REFRESH[RunId])=0,"NOT REFRESHED",INDEX(LOG_REFRESH[Status],COUNTA(LOG_REFRESH[RunId])))'),
                @('Data exceptions (ERROR)', '=IF(COUNTA(LOG_REFRESH[RunId])=0,"",INDEX(LOG_REFRESH[ErrorCount],COUNTA(LOG_REFRESH[RunId])))'),
                @('Upstream run consumed', '=IF(COUNTA(LOG_REFRESH[RunId])=0,"",INDEX(LOG_REFRESH[UpstreamRunId],COUNTA(LOG_REFRESH[RunId])))'))
            if ($upstreamOf.ContainsKey($stage)) {
                $status += , @('Upstream workbook latest run', '=IFERROR(INDEX(UPSTREAM_STATUS[RunId],1),"")')
                $status += , @('Freshness', '=IF(OR(B10="",B9=""),"n/a",IF(B10=B9,"CURRENT","STALE - run Invoke-PassressRefresh.ps1"))')
            }
            for ($i = 0; $i -lt $status.Count; $i++) { $homeWs.Cells.Item(5 + $i, 1).Value2 = $status[$i][0]; $homeWs.Cells.Item(5 + $i, 2).Formula = $status[$i][1] }
            $homeWs.Range('B6').NumberFormat = 'yyyy-mm-dd hh:mm'
            $g = 14
            $homeWs.Cells.Item($g, 1).Value2 = 'HOW TO USE'; $homeWs.Cells.Item($g, 1).Font.Bold = $true
            $how = @('1. Type only in INPUT sheets (olive tabs, light-green cells). REPORT sheets are rebuilt on every refresh - never type there.', '2. Save and close this workbook, then run scripts\Invoke-PassressRefresh.ps1 (refreshes 01 -> 02 -> 03 -> 04 in order).', '3. Check CONTROLS (all OK) and the exception sheets. INCOMPLETE / PRELIMINARY figures are not final.', '4. Do not rename sheets, tables or columns. Never paste Shopify orders or refunds into input sheets.')
            for ($i = 0; $i -lt $how.Count; $i++) { $homeWs.Cells.Item($g + 1 + $i, 1).Value2 = $how[$i] }
            $g = $g + 6
            $homeWs.Cells.Item($g, 1).Value2 = 'SHEET'; $homeWs.Cells.Item($g, 2).Value2 = 'TYPE'; $homeWs.Cells.Item($g, 3).Value2 = 'PURPOSE'; $homeWs.Range($homeWs.Cells.Item($g, 1), $homeWs.Cells.Item($g, 3)).Font.Bold = $true
            for ($i = 0; $i -lt $guideRows.Count; $i++) { for ($c = 0; $c -lt 3; $c++) { $homeWs.Cells.Item($g + 1 + $i, 1 + $c).Value2 = $guideRows[$i][$c] } }
            $homeWs.Columns.Item(1).ColumnWidth = 34; $homeWs.Columns.Item(2).ColumnWidth = 30; $homeWs.Columns.Item(3).ColumnWidth = 110
            $homeWs.Protect() ; $ctl.Protect()   # formulas only; no password so the operator can unprotect if needed
            $homeWs.Activate()
            $wb.SaveAs($target, 51)
            $saved = $true
            Write-PassressLog -Level OK -Message "Saved $target"
            $built += $target
        } catch {
            Write-PassressLog -Level ERROR -Message "Build of $stage failed: $($_.Exception.Message). The workbook was NOT saved."
            throw
        } finally { try { $wb.Close($saved) } catch { } }
    }
} finally { if ($session) { Close-PassressExcel -Session $session } }

Write-PassressLog -Level OK -Message ("Build complete. Workbooks: {0}" -f ($built -join '; '))
Write-PassressLog -Message 'Next: (1) rotate the Shopify secret and run Set-PassressShopifyCredential.ps1, (2) enter opening balances/costs, (3) run Invoke-PassressRefresh.ps1 -Mode LIVE.'
