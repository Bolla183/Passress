#Requires -Version 5.1
<#
  Passress.Engine - pure business logic for the four stages. No Excel, no network.
  Every stage takes plain rows and returns tables + exceptions, so it can be tested offline.
#>
Set-StrictMode -Version 2.0
Import-Module (Join-Path $PSScriptRoot 'Passress.Common.psm1') -Force -DisableNameChecking

. (Join-Path $PSScriptRoot 'engine\Helpers.ps1')
. (Join-Path $PSScriptRoot 'engine\DataSource.ps1')
. (Join-Path $PSScriptRoot 'engine\Operations.ps1')
. (Join-Path $PSScriptRoot 'engine\Finance.ps1')
. (Join-Path $PSScriptRoot 'engine\Management.ps1')

function Invoke-PassressStageIO {
    <#
      Runs one stage end-to-end on disk:
        reads upstream outputs (CSV) + this workbook's input snapshot (CSV exported from Excel by the controller),
        runs the engine, writes every output table to <workbook>\outputs, appends LOG_REFRESH, writes _RUN.json.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('01_DATA_SOURCE', '02_OPERATIONS', '03_FINANCE', '04_MANAGEMENT')][string]$Stage,
        [Parameter(Mandatory)]$Config, [Parameter(Mandatory)][string]$RunId, [ValidateSet('LIVE', 'OFFLINE')][string]$Mode = 'OFFLINE',
        [string]$ShopifyExtractFolder
    )
    $paths = Get-PassressPaths -Config $Config
    $wb = $paths.Workbooks[$Stage]
    $started = Get-Date
    $schema = Get-PassressSchema
    $inputTables = @($schema.workbooks.$Stage.tables | Where-Object { $_.kind -eq 'input' } | ForEach-Object { $_.name })
    $inputs = @{}; foreach ($t in $inputTables) { $inputs[$t] = Import-PassressTable -Workbook $Stage -Table $t -Directory $wb.Inputs -AllowMissing }
    $up = @{}; $upstreamRun = $null
    $readUp = {
        param($wbName, [string[]]$tables)
        $src = $paths.Workbooks[$wbName]
        $run = Read-PassressJson (Join-Path $src.Outputs '_RUN.json')
        if ($null -eq $run -or $run.Status -ne 'OK' -or $run.RunId -ne $RunId) {
            $got = if ($run) { '{0} / {1}' -f $run.RunId, $run.Status } else { 'none' }
            throw "STALE_UPSTREAM: $wbName outputs are not from this run ($RunId). Found: $got. Downstream refresh refused."
        }
        foreach ($t in $tables) { $up[$t] = Import-PassressTable -Workbook $wbName -Table $t -Directory $src.Outputs }
        return $run.RunId
    }

    $result = $null; $outTables = @{}; $exceptionTables = @{}
    switch ($Stage) {
        '01_DATA_SOURCE' {
            if (-not $ShopifyExtractFolder) { throw 'ShopifyExtractFolder is required for stage 01.' }
            $orders = Read-PassressJson (Join-Path $ShopifyExtractFolder 'orders.json'); $customers = Read-PassressJson (Join-Path $ShopifyExtractFolder 'customers.json'); $variants = Read-PassressJson (Join-Path $ShopifyExtractFolder 'variants.json')
            if (-not (Test-Path -LiteralPath (Join-Path $ShopifyExtractFolder 'orders.json'))) { throw "orders.json missing in $ShopifyExtractFolder" }
            $orders = @($orders | Where-Object { $null -ne $_ }); $customers = @($customers | Where-Object { $null -ne $_ }); $variants = @($variants | Where-Object { $null -ne $_ })
            $result = Invoke-PassressDataSourceStage -OrderNodes @($orders) -CustomerNodes @($customers) -VariantNodes @($variants) -ClassificationRows $inputs.ORDER_CLASSIFICATION -Config $Config -RunId $RunId
            $outTables = $result.Tables; $exceptionTables['EXCEPTIONS'] = $result.Exceptions
        }
        '02_OPERATIONS' {
            $upstreamRun = & $readUp '01_DATA_SOURCE' @('SALES_FACT', 'REVENUE_EVENTS', 'RAW_CUSTOMERS', 'RAW_VARIANTS', 'REFUND_RECONCILIATION', 'FULFILLMENT_EVENTS', 'ORDER_TRANSACTIONS')
            $statePath = Join-Path $wb.State 'cost_master_state.json'
            $result = Invoke-PassressOperationsStage -Upstream $up -Inputs $inputs -PreviousCostState (Read-PassressJson $statePath) -Config $Config -RunId $RunId
            $outTables = $result.Tables; $exceptionTables['COST_EXCEPTIONS'] = $result.CostExceptions; $exceptionTables['INVENTORY_EXCEPTIONS'] = $result.InventoryExceptions
            Write-PassressJson -Object $result.CostState -Path $statePath
        }
        '03_FINANCE' {
            $upstreamRun = & $readUp '01_DATA_SOURCE' @('SALES_FACT', 'REVENUE_EVENTS', 'ORDER_TRANSACTIONS')
            $null = & $readUp '02_OPERATIONS' @('SALES_COSTED', 'COGS_EVENTS', 'INVENTORY_MOVEMENTS', 'INVENTORY', 'REFUND_RETURN_RECONCILIATION')
            $snapPath = Join-Path $wb.State 'month_close_snapshots.json'
            $result = Invoke-PassressFinanceStage -Upstream $up -Inputs $inputs -CloseSnapshots (Read-PassressJson $snapPath) -Config $Config -RunId $RunId
            $outTables = $result.Tables; $exceptionTables['FINANCE_EXCEPTIONS'] = $result.Exceptions
            Write-PassressJson -Object $result.CloseSnapshots -Path $snapPath
        }
        '04_MANAGEMENT' {
            $upstreamRun = & $readUp '01_DATA_SOURCE' @('SALES_FACT')
            $null = & $readUp '02_OPERATIONS' @('SALES_COSTED', 'INVENTORY', 'CUSTOMER_BASE', 'REFUND_RETURN_RECONCILIATION')
            $null = & $readUp '03_FINANCE' @('PROFIT_AND_LOSS', 'BALANCE_SHEET', 'CASH_FLOW', 'PRODUCT_PL', 'FINANCE_EXCEPTIONS')
            $result = Invoke-PassressManagementStage -Upstream $up -Inputs $inputs -Config $Config -RunId $RunId
            $outTables = $result.Tables; $exceptionTables['MANAGEMENT_EXCEPTIONS'] = $result.Exceptions
        }
    }
    $counts = @()
    foreach ($t in $outTables.Keys) { $r = Export-PassressTable -Workbook $Stage -Table $t -Rows $outTables[$t] -Directory $wb.Outputs; $counts += ('{0}={1}' -f $t, $r.Rows) }
    $errors = 0; $warnings = 0
    foreach ($t in $exceptionTables.Keys) {
        $rows = @($exceptionTables[$t]); $r = Export-PassressTable -Workbook $Stage -Table $t -Rows $rows -Directory $wb.Outputs; $counts += ('{0}={1}' -f $t, $r.Rows)
        $errors += @($rows | Where-Object { $_.Severity -eq 'ERROR' }).Count; $warnings += @($rows | Where-Object { $_.Severity -eq 'WARNING' }).Count
    }
    $log = Import-PassressTable -Workbook $Stage -Table 'LOG_REFRESH' -Directory $wb.Outputs -AllowMissing
    $entry = [ordered]@{ RunId = $RunId; Stage = $Stage; StartedAt = $started; EndedAt = (Get-Date); Status = 'OK'; Mode = $Mode; UpstreamRunId = $upstreamRun; RowCounts = ($counts -join ';'); ErrorCount = $errors; WarningCount = $warnings; Message = $(if ($errors -gt 0) { "$errors data exceptions (see exception tables) - figures marked INCOMPLETE where affected." } else { '' }) }
    Export-PassressTable -Workbook $Stage -Table 'LOG_REFRESH' -Rows (@($log) + @($entry)) -Directory $wb.Outputs | Out-Null
    $run = [ordered]@{ RunId = $RunId; Stage = $Stage; Status = 'OK'; Mode = $Mode; EndedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss'); UpstreamRunId = $upstreamRun; RowCounts = $counts; ErrorCount = $errors; WarningCount = $warnings }
    Write-PassressJson -Object $run -Path (Join-Path $wb.Outputs '_RUN.json')
    return [pscustomobject]$run
}

function Write-PassressStageFailure {
    # Marks a stage FAILED so no downstream stage can consume its outputs.
    param([Parameter(Mandatory)][string]$Stage, [Parameter(Mandatory)]$Config, [Parameter(Mandatory)][string]$RunId, [string]$Message, [string]$Mode = 'OFFLINE')
    $paths = Get-PassressPaths -Config $Config; $wb = $paths.Workbooks[$Stage]
    if (-not (Test-Path -LiteralPath $wb.Outputs)) { New-Item -ItemType Directory -Path $wb.Outputs -Force | Out-Null }
    Write-PassressJson -Object ([ordered]@{ RunId = $RunId; Stage = $Stage; Status = 'FAILED'; Mode = $Mode; EndedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss'); Message = $Message }) -Path (Join-Path $wb.Outputs '_RUN.json')
    $log = Import-PassressTable -Workbook $Stage -Table 'LOG_REFRESH' -Directory $wb.Outputs -AllowMissing
    $entry = [ordered]@{ RunId = $RunId; Stage = $Stage; StartedAt = (Get-Date); EndedAt = (Get-Date); Status = 'FAILED'; Mode = $Mode; UpstreamRunId = $null; RowCounts = ''; ErrorCount = 0; WarningCount = 0; Message = $Message }
    Export-PassressTable -Workbook $Stage -Table 'LOG_REFRESH' -Rows (@($log) + @($entry)) -Directory $wb.Outputs | Out-Null
}

function Initialize-PassressOutputFiles {
    # Header-only CSVs so Power Query can be bound before the first refresh.
    param([Parameter(Mandatory)]$Config)
    $paths = Get-PassressPaths -Config $Config; $schema = Get-PassressSchema
    foreach ($w in $paths.Workbooks.Keys) {
        foreach ($t in @($schema.workbooks.$w.tables | Where-Object { $_.kind -eq 'output' })) {
            $f = Join-Path $paths.Workbooks[$w].Outputs ($t.name + '.csv')
            if (-not (Test-Path -LiteralPath $f)) { Export-PassressTable -Workbook $w -Table $t.name -Rows @() -Directory $paths.Workbooks[$w].Outputs | Out-Null }
        }
    }
}

Export-ModuleMember -Function Invoke-Passress*, Initialize-Passress*, Write-PassressStageFailure, Get-PassressEffectiveCost, Get-PassressDefault*, Resolve-PassressClassification, Get-OrderClassification
