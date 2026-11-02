#Requires -Version 5.1
<#
.SYNOPSIS  Controlled sequential refresh: 01_DATA_SOURCE -> 02_OPERATIONS -> 03_FINANCE -> 04_MANAGEMENT.
.DESCRIPTION
  For each workbook, in order:
    open (own Excel instance) -> snapshot its INPUT tables -> run the engine stage (refuses stale/failed upstream)
    -> refresh every connection synchronously -> validate row counts and run id -> save -> close.
  The chain stops at the first failure; downstream workbooks are not touched and keep their previous (older) data,
  which their HOME sheet then shows as STALE. A timestamped backup of all workbooks and engine state is taken first.
  LIVE  : extracts Shopify (read-only) - requires the rotated credential (Set-PassressShopifyCredential.ps1).
  OFFLINE: uses a saved extract folder (orders.json, customers.json, variants.json) - no network.
.EXAMPLE  .\Invoke-PassressRefresh.ps1 -ConfigPath C:\PASSRESS_BUSINESS_SYSTEM\07_CONFIGURATION\passress.config.json -Mode LIVE
.EXAMPLE  .\Invoke-PassressRefresh.ps1 -ConfigPath ... -Mode OFFLINE -OfflineExtractFolder ..\tests\fixtures\extract_test_orders
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ConfigPath, [ValidateSet('LIVE', 'OFFLINE')][string]$Mode = 'LIVE',
    [string]$OfflineExtractFolder, [int]$TimeoutMinutes = 0, [switch]$Visible,
    [ValidateSet('', '01_DATA_SOURCE', '02_OPERATIONS', '03_FINANCE', '04_MANAGEMENT')][string]$SimulateFailureAt = ''
)
$ErrorActionPreference = 'Stop'
$src = Join-Path (Split-Path $PSScriptRoot -Parent) 'src'
Import-Module (Join-Path $src 'Passress.Common.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $src 'Passress.Engine.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $src 'Passress.Excel.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $src 'Passress.Shopify.psm1') -Force -DisableNameChecking

$cfg = Get-PassressConfig -Path $ConfigPath
$paths = Get-PassressPaths -Config $cfg
$runId = New-PassressRunId
Set-PassressLogFile (Join-Path $paths.Logs ("refresh_{0}.log" -f $runId))
if ($TimeoutMinutes -le 0) { $TimeoutMinutes = [int](Get-PassressConfigValue $cfg 'RefreshTimeoutMinutes' 30) }
$stages = @('01_DATA_SOURCE', '02_OPERATIONS', '03_FINANCE', '04_MANAGEMENT')
$summary = [ordered]@{ RunId = $runId; Mode = $Mode; StartedAt = (Get-Date).ToString('s'); Stages = @(); Result = 'RUNNING'; Message = '' }
Write-PassressLog -Message "=== PASSRESS controlled refresh $runId ($Mode) ==="

$session = $null; $watchdog = $null; $failed = $false
try {
    # ---------------------------------------------------- preflight
    foreach ($s in $stages) {
        $f = $paths.Workbooks[$s].File
        if (-not (Test-Path -LiteralPath $f)) { throw "PREFLIGHT: $f not found. Run Build-PassressSystem.ps1 first." }
        if (-not (Test-PassressFileUnlocked $f)) { throw "PREFLIGHT: $f is open. Close all PASSRESS workbooks, then run again." }
    }
    $toBackup = @(); foreach ($s in $stages) { $w = $paths.Workbooks[$s]; $toBackup += $w.File; $toBackup += $w.Outputs; $toBackup += $w.State }
    $bk = Backup-PassressFiles -Paths $toBackup -BackupRoot $paths.Backups -Label ("pre-refresh_$runId") -RelativeTo $paths.Root
    Write-PassressLog -Message "Backup: $($bk.Folder)"

    # ---------------------------------------------------- extract
    $extract = Join-Path $paths.Staging $runId
    if ($Mode -eq 'LIVE') {
        if (-not (Test-PassressShopifyCredential)) { throw 'LIVE_BLOCKED: no Shopify credential. Rotate the old secret, run Set-PassressShopifyCredential.ps1, or use -Mode OFFLINE.' }
        $x = Invoke-PassressShopifyExtract -Config $cfg -OutFolder $extract
        Write-PassressLog -Level OK -Message ("Shopify extract: {0} orders, {1} customers, {2} variants" -f $x.Orders, $x.Customers, $x.Variants)
    } else {
        if (-not $OfflineExtractFolder -or -not (Test-Path -LiteralPath (Join-Path $OfflineExtractFolder 'orders.json'))) { throw 'OFFLINE mode needs -OfflineExtractFolder containing orders.json (customers.json / variants.json optional).' }
        New-Item -ItemType Directory -Path $extract -Force | Out-Null
        foreach ($n in @('orders.json', 'customers.json', 'variants.json')) { $p = Join-Path $OfflineExtractFolder $n; if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination $extract } else { Set-Content -LiteralPath (Join-Path $extract $n) -Value '[]' -Encoding UTF8 } }
        Write-PassressLog -Message "Offline extract copied from $OfflineExtractFolder"
    }

    # ---------------------------------------------------- Excel + watchdog (kills only OUR Excel process on timeout)
    $session = New-PassressExcel -Visible:$Visible
    Write-PassressLog -Message ("Excel {0} (build {1}) PID {2}; timeout {3} min" -f $session.Version, $session.Build, $session.ProcessId, $TimeoutMinutes)
    $watchdog = Start-Job -ArgumentList $session.ProcessId, ($TimeoutMinutes * 60) -ScriptBlock { param($procId, $seconds) Start-Sleep -Seconds $seconds; $p = Get-Process -Id $procId -ErrorAction SilentlyContinue; if ($p -and $p.ProcessName -like 'EXCEL*') { Stop-Process -Id $procId -Force; 'TIMEOUT_KILLED' } }

    foreach ($stage in $stages) {
        $w = $paths.Workbooks[$stage]; $st = [ordered]@{ Stage = $stage; Status = 'RUNNING'; Started = (Get-Date).ToString('s'); Connections = @(); Validation = @(); Message = '' }
        if ($failed) { $st.Status = 'SKIPPED'; $st.Message = 'Upstream stage failed - not refreshed (keeps previous data, shown as STALE).'; $summary.Stages += [pscustomobject]$st; Write-PassressLog -Level WARN -Message "$stage SKIPPED (upstream failed)"; continue }
        Write-PassressLog -Message "--- $stage ---"
        $wb = $null; $ok = $false
        try {
            $wb = Open-PassressWorkbook -Session $session -Path $w.File
            $counts = Export-PassressInputTables -Workbook $wb -Stage $stage -Directory $w.Inputs
            Write-PassressLog -Message ("Inputs snapshot: " + (($counts.Keys | ForEach-Object { "$_=$($counts[$_])" }) -join ', '))
            if ($SimulateFailureAt -eq $stage) { throw "SIMULATED_FAILURE requested at $stage (test of downstream protection)." }
            $run = Invoke-PassressStageIO -Stage $stage -Config $cfg -RunId $runId -Mode $Mode -ShopifyExtractFolder $extract
            Write-PassressLog -Message ("Engine: {0} ERROR / {1} WARNING data exceptions" -f $run.ErrorCount, $run.WarningCount)
            $res = Invoke-PassressWorkbookRefresh -Session $session -Workbook $wb
            $st.Connections = $res
            $badConn = @($res | Where-Object { $_.Status -ne 'OK' })
            if ($badConn.Count -gt 0) { throw ('POWER_QUERY_REFRESH_FAILED: ' + (($badConn | ForEach-Object { "$($_.Connection): $($_.Error)" }) -join ' | ')) }
            # validation: every engine output table in Excel has exactly the rows the engine wrote, and the log shows this run
            $expected = @{}; foreach ($c in @($run.RowCounts)) { $kv = $c.Split('='); $expected[$kv[0]] = [int]$kv[1] }
            $mism = @()
            foreach ($t in $expected.Keys) { $n = Get-PassressListObjectRowCount -Workbook $wb -Name $t; $st.Validation += [pscustomobject]@{ Table = $t; Engine = $expected[$t]; Excel = $n }; if ($n -ne $expected[$t]) { $mism += "$t (engine $($expected[$t]) / Excel $n)" } }
            $logRows = Get-PassressListObjectRowCount -Workbook $wb -Name 'LOG_REFRESH'
            $loLog = Get-PassressListObject -Workbook $wb -Name 'LOG_REFRESH'
            $lastRun = [string]$loLog.ListColumns.Item('RunId').DataBodyRange.Cells.Item($logRows, 1).Value2
            if ($lastRun -ne $runId) { $mism += "LOG_REFRESH last run '$lastRun' <> $runId" }
            if ($mism.Count -gt 0) { throw ('VALIDATION_FAILED: ' + ($mism -join '; ')) }
            $wb.Save(); $wb.Close($false); $wb = $null
            $ok = $true; $st.Status = 'OK'
            Write-PassressLog -Level OK -Message "$stage refreshed, validated and saved."
        } catch {
            $failed = $true; $st.Status = 'FAILED'; $st.Message = $_.Exception.Message
            Write-PassressLog -Level ERROR -Message "$stage FAILED: $($_.Exception.Message)"
            try { Write-PassressStageFailure -Stage $stage -Config $cfg -RunId $runId -Message $_.Exception.Message -Mode $Mode } catch { }
        } finally {
            if ($null -ne $wb) { try { $wb.Close($false) } catch { } ; Write-PassressLog -Level WARN -Message "$stage closed WITHOUT saving." }
        }
        $st.Ended = (Get-Date).ToString('s'); $summary.Stages += [pscustomobject]$st
    }
    $summary.Result = if ($failed) { 'FAILED' } else { 'OK' }
} catch {
    $failed = $true; $summary.Result = 'FAILED'; $summary.Message = $_.Exception.Message
    Write-PassressLog -Level ERROR -Message $_.Exception.Message
} finally {
    if ($session) { Close-PassressExcel -Session $session }
    if ($watchdog) { $wd = Receive-Job $watchdog -ErrorAction SilentlyContinue; Remove-Job $watchdog -Force -ErrorAction SilentlyContinue; if ($wd -eq 'TIMEOUT_KILLED') { $summary.Result = 'FAILED'; $summary.Message = "Timeout after $TimeoutMinutes minutes - our Excel instance was stopped. Restore from the pre-refresh backup if a workbook is damaged." } }
    $summary.EndedAt = (Get-Date).ToString('s')
    Write-PassressJson -Object $summary -Path (Join-Path $paths.Logs ("refresh_{0}.json" -f $runId))
}
Write-PassressLog -Level $(if ($failed) { 'ERROR' } else { 'OK' }) -Message ("=== Refresh {0}: {1} ===" -f $runId, $summary.Result)
foreach ($s in $summary.Stages) { Write-PassressLog -Message ("  {0,-16} {1}  {2}" -f $s.Stage, $s.Status, $s.Message) }
if ($failed) { Write-PassressLog -Message "Recovery: workbooks were only saved after successful validation. If needed: .\Restore-PassressBackup.ps1 -ConfigPath ... -BackupFolder `"$($bk.Folder)`""; exit 1 }
exit 0
