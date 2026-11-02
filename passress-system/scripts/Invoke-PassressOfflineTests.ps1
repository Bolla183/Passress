#Requires -Version 5.1
<#
.SYNOPSIS  Repeatable OFFLINE test suite (no Shopify calls). Produces evidence files in tests\results.
.DESCRIPTION
  Level 1 (any PowerShell 5.1/7): engine scenarios S01-S18 through the real CSV round trip, determinism re-run,
          stale/failed-upstream file tests, read-only guard, secret redaction, culture-independent CSV.
  Level 2 (-WithExcel, Windows + Excel): builds the four workbooks in a temporary root, runs the controlled OFFLINE
          refresh with the saved #1001-#1009 sample, then a refresh with a simulated failure at 02 to prove that
          03/04 are not refreshed.
  A test is PASS only when it was executed and its assertion held; evidence (expected vs actual) is written for every check.
.EXAMPLE  .\Invoke-PassressOfflineTests.ps1
.EXAMPLE  .\Invoke-PassressOfflineTests.ps1 -WithExcel
#>
[CmdletBinding()]
param([string]$ResultsFolder, [switch]$WithExcel, [string[]]$Scenario)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent; $src = Join-Path $repo 'src'; $testsDir = Join-Path $repo 'tests'
Import-Module (Join-Path $src 'Passress.Common.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $src 'Passress.Engine.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $src 'Passress.Shopify.psm1') -Force -DisableNameChecking
. (Join-Path $testsDir 'TestHelpers.ps1')
. (Join-Path $testsDir 'scenarios\Scenarios.ps1')

if (-not $ResultsFolder) { $ResultsFolder = Join-Path $testsDir 'results' }
New-Item -ItemType Directory -Path $ResultsFolder -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("passress_tests_$stamp"); New-Item -ItemType Directory -Path $work -Force | Out-Null
$fixture = Join-Path $testsDir 'fixtures\extract_test_orders_1001_1009'
$results = New-Object System.Collections.Generic.List[object]
function Add-Result { param($Group, $Id, $Desc, $Expected, $Actual, $Result) $results.Add([pscustomobject]@{ Group = $Group; Id = $Id; Description = $Desc; Expected = [string]$Expected; Actual = [string]$Actual; Result = $Result }) }

$env_ = [ordered]@{ Started = (Get-Date).ToString('s'); PowerShell = $PSVersionTable.PSVersion.ToString(); Edition = $PSVersionTable.PSEdition; OS = [System.Environment]::OSVersion.VersionString; Machine = [System.Environment]::MachineName }
Write-Host ("PASSRESS offline tests - PowerShell {0} on {1}" -f $env_.PowerShell, $env_.OS)

# ------------------------------------------------------------------ Level 1a: scenarios
$cfg = New-TestConfig -Root (Join-Path $work 'root')
foreach ($sc in (Get-PassressTestScenarios -FixtureFolder $fixture)) {
    if ($Scenario -and $Scenario -notcontains $sc.Name) { continue }
    $dir = Join-Path $work $sc.Name
    try {
        $tables = Invoke-TestPipeline -Scenario $sc -Config $cfg -TempDir $dir
        foreach ($a in $sc.Assertions) { $r = Invoke-Assertion -Assertion $a -Tables $tables; Add-Result $sc.Name $r.Id $r.Desc $r.Expected $r.Actual $r.Result }
        if ($sc.ContainsKey('Rerun') -and $sc.Rerun) {
            $dir2 = Join-Path $work ($sc.Name + '_rerun'); $null = Invoke-TestPipeline -Scenario $sc -Config $cfg -TempDir $dir2
            $diff = @()
            foreach ($f in (Get-ChildItem -Path $dir -Recurse -Filter '*.csv')) {
                $rel = $f.FullName.Substring($dir.Length); $other = Join-Path $dir2 $rel
                if (-not (Test-Path -LiteralPath $other) -or (Get-FileHash $f.FullName).Hash -ne (Get-FileHash $other).Hash) { $diff += $rel }
            }
            Add-Result $sc.Name ($sc.Name.Substring(0, 3) + '-RERUN') 'Second full refresh produces byte-identical outputs (idempotent)' '0 differing files' ("{0} differing files {1}" -f $diff.Count, ($diff -join ',')) $(if ($diff.Count -eq 0) { 'PASS' } else { 'FAIL' })
        }
    } catch {
        Add-Result $sc.Name ($sc.Name.Substring(0, 3) + '-ERR') 'Scenario executed without error' 'no error' ($_.Exception.Message + ' @ ' + $_.InvocationInfo.PositionMessage) 'FAIL'
    }
}

# ------------------------------------------------------------------ Level 1b: file-level refresh protections (no Excel)
function New-IoRoot { param($name) $r = Join-Path $work $name; $c = New-TestConfig -Root $r; Initialize-PassressOutputFiles -Config $c; return $c }
try {
    $c = New-IoRoot 'io_chain'
    $ok = $true; $msg = @()
    foreach ($st in @('01_DATA_SOURCE', '02_OPERATIONS', '03_FINANCE', '04_MANAGEMENT')) { $run = Invoke-PassressStageIO -Stage $st -Config $c -RunId 'RUN-A' -Mode OFFLINE -ShopifyExtractFolder $fixture; if ($run.Status -ne 'OK') { $ok = $false }; $msg += "$st=$($run.Status)" }
    Add-Result 'IO' 'IO-01' 'Full offline chain 01->02->03->04 completes with _RUN.json OK for every stage' 'all OK' ($msg -join ', ') $(if ($ok) { 'PASS' } else { 'FAIL' })
    $missing = @(); $schema = Get-PassressSchema
    foreach ($w in @('01_DATA_SOURCE', '02_OPERATIONS', '03_FINANCE', '04_MANAGEMENT')) { foreach ($t in @($schema.workbooks.$w.tables | Where-Object { $_.kind -eq 'output' })) { $p = Join-Path (Join-Path (Join-Path $c.RootFolder $schema.workbooks.$w.folder) 'outputs') ($t.name + '.csv'); if (-not (Test-Path -LiteralPath $p)) { $missing += "$w/$($t.name)" } } }
    Add-Result 'IO' 'IO-02' 'Every output table in the schema has a CSV for Power Query' '0 missing' ("{0} missing {1}" -f $missing.Count, ($missing -join ',')) $(if ($missing.Count -eq 0) { 'PASS' } else { 'FAIL' })
    foreach ($st in @('01_DATA_SOURCE', '02_OPERATIONS', '03_FINANCE', '04_MANAGEMENT')) { $null = Invoke-PassressStageIO -Stage $st -Config $c -RunId 'RUN-B' -Mode OFFLINE -ShopifyExtractFolder $fixture }
    $paths = Get-PassressPaths -Config $c
    $log = Import-PassressTable -Workbook '04_MANAGEMENT' -Table 'LOG_REFRESH' -Directory $paths.Workbooks['04_MANAGEMENT'].Outputs
    Add-Result 'IO' 'IO-03' 'LOG_REFRESH is append-only (2 runs -> 2 rows, last = RUN-B, upstream = RUN-B)' '2 rows, RUN-B/RUN-B' ("{0} rows, {1}/{2}" -f $log.Count, $log[$log.Count - 1].RunId, $log[$log.Count - 1].UpstreamRunId) $(if ($log.Count -eq 2 -and $log[1].RunId -eq 'RUN-B' -and $log[1].UpstreamRunId -eq 'RUN-B') { 'PASS' } else { 'FAIL' })
    $threw = $null; try { $null = Invoke-PassressStageIO -Stage '02_OPERATIONS' -Config $c -RunId 'RUN-C' -Mode OFFLINE } catch { $threw = $_.Exception.Message }
    Add-Result 'IO' 'IO-04' 'Stale upstream (01 is from RUN-B, 02 runs as RUN-C) is refused' 'STALE_UPSTREAM error' $threw $(if ($threw -like 'STALE_UPSTREAM*') { 'PASS' } else { 'FAIL' })
    Write-PassressStageFailure -Stage '01_DATA_SOURCE' -Config $c -RunId 'RUN-D' -Message 'simulated Shopify failure'
    $threw = $null; try { $null = Invoke-PassressStageIO -Stage '02_OPERATIONS' -Config $c -RunId 'RUN-D' -Mode OFFLINE } catch { $threw = $_.Exception.Message }
    Add-Result 'IO' 'IO-05' 'Failed upstream (01 FAILED in RUN-D) stops 02' 'STALE_UPSTREAM error' $threw $(if ($threw -like 'STALE_UPSTREAM*') { 'PASS' } else { 'FAIL' })
    $bad = Join-Path $work 'bad_extract'; New-Item -ItemType Directory -Path $bad -Force | Out-Null; Set-Content -LiteralPath (Join-Path $bad 'orders.json') -Value '{ this is not json' -Encoding UTF8
    $threw = $null; try { $null = Invoke-PassressStageIO -Stage '01_DATA_SOURCE' -Config $c -RunId 'RUN-E' -Mode OFFLINE -ShopifyExtractFolder $bad } catch { $threw = $_.Exception.Message }
    $run01 = Read-PassressJson (Join-Path $paths.Workbooks['01_DATA_SOURCE'].Outputs '_RUN.json')
    Add-Result 'IO' 'IO-06' 'Corrupt Shopify extract fails stage 01 and leaves no RUN-E success marker' 'error + _RUN.json not RUN-E/OK' ("error={0}; _RUN={1}/{2}" -f [bool]$threw, $run01.RunId, $run01.Status) $(if ($threw -and -not ($run01.RunId -eq 'RUN-E' -and $run01.Status -eq 'OK')) { 'PASS' } else { 'FAIL' })
} catch { Add-Result 'IO' 'IO-ERR' 'File-level tests executed' 'no error' ($_.Exception.Message + ' @ ' + $_.InvocationInfo.PositionMessage) 'FAIL' }

# ------------------------------------------------------------------ Level 1c: security + culture unit tests
$cases = @(@{ Q = 'mutation { productDelete(input: {id: "x"}) { deletedProductId } }'; Allowed = $false }, @{ Q = 'query { shop { name } }'; Allowed = $true }, @{ Q = '{ shop { name } }'; Allowed = $true }, @{ Q = 'query { a } mutation { b }'; Allowed = $false }, @{ Q = 'subscription { x }'; Allowed = $false })
$n = 0; foreach ($k in $cases) { $n++; $allowed = $true; try { Assert-PassressReadOnlyQuery -Document $k.Q } catch { $allowed = $false }; Add-Result 'SECURITY' ("SEC-0$n") ("Read-only guard: '" + $k.Q.Substring(0, [math]::Min(30, $k.Q.Length)) + "...'") $(if ($k.Allowed) { 'allowed' } else { 'refused' }) $(if ($allowed) { 'allowed' } else { 'refused' }) $(if ($allowed -eq $k.Allowed) { 'PASS' } else { 'FAIL' }) }
$lf = Join-Path $work 'redact.log'; Set-PassressLogFile $lf
$fakeToken = ('shp' + 'ss_') + 'ABCdef' + '1234567890'   # assembled at runtime: no credential-shaped literal in the code base
Write-PassressLog -Message ('token ' + $fakeToken + ' and client_secret=TopSecret99 and access_token=Zz9') 6>$null
Set-PassressLogFile $null
$txt = Get-Content -LiteralPath $lf -Raw
Add-Result 'SECURITY' 'SEC-06' 'Logs never contain secrets (shpss_..., client_secret=, access_token=)' 'redacted' $(if ($txt -match 'ABCdef|TopSecret|Zz9') { 'LEAKED' } else { 'redacted' }) $(if ($txt -match 'ABCdef|TopSecret|Zz9') { 'FAIL' } else { 'PASS' })
$cultureOut = & {
    $old = [System.Threading.Thread]::CurrentThread.CurrentCulture
    try {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')
        $d = Join-Path $work 'culture'; $null = Export-PassressTable -Workbook '03_FINANCE' -Table 'CASH_FLOW' -Rows @(@{ Month = '2026-10'; SortOrder = 1; LineItem = 'x'; Amount = 1234.5; Status = 'PRELIMINARY' }) -Directory $d
        $back = Import-PassressTable -Workbook '03_FINANCE' -Table 'CASH_FLOW' -Directory $d
        @((Get-Content -LiteralPath (Join-Path $d 'CASH_FLOW.csv') -Raw), $back[0].Amount)
    } finally { [System.Threading.Thread]::CurrentThread.CurrentCulture = $old }
}
$okC = ($cultureOut[0] -match '"1234\.5"' -and [double]$cultureOut[1] -eq 1234.5)
Add-Result 'CSV' 'CSV-01' 'Numbers written culture-independently (German decimal comma does not leak)' '"1234.5" and 1234.5 read back' ("file has 1234.5: {0}; read back {1}" -f ($cultureOut[0] -match '"1234\.5"'), $cultureOut[1]) $(if ($okC) { 'PASS' } else { 'FAIL' })

# ------------------------------------------------------------------ Level 2: Excel end-to-end (Windows only)
if ($WithExcel) {
    try {
        $root = Join-Path $work 'excel_root'; New-Item -ItemType Directory -Path (Join-Path $root '07_CONFIGURATION') -Force | Out-Null
        $tcfg = (Get-Content (Join-Path $repo 'config\passress.config.template.json') -Raw | ConvertFrom-Json); $tcfg.RootFolder = $root
        $cfgPath = Join-Path $root '07_CONFIGURATION\passress.config.json'; Write-PassressJson -Object $tcfg -Path $cfgPath
        & (Join-Path $PSScriptRoot 'Build-PassressSystem.ps1') -ConfigPath $cfgPath
        $built = @('01_DATA_SOURCE\01_DATA_SOURCE.xlsx', '02_OPERATIONS\02_OPERATIONS.xlsx', '03_FINANCE\03_FINANCE.xlsx', '04_MANAGEMENT\04_MANAGEMENT.xlsx') | Where-Object { Test-Path (Join-Path $root $_) }
        Add-Result 'EXCEL' 'XL-01' 'Build creates the four workbooks via Excel COM' '4 files' ("{0} files" -f @($built).Count) $(if (@($built).Count -eq 4) { 'PASS' } else { 'FAIL' })
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Invoke-PassressRefresh.ps1') -ConfigPath $cfgPath -Mode OFFLINE -OfflineExtractFolder $fixture | Out-Host
        $code = $LASTEXITCODE
        $sum = Get-ChildItem (Join-Path $root '08_LOGS') -Filter 'refresh_RUN-*.json' | Sort-Object LastWriteTime | Select-Object -Last 1 | ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json }
        Add-Result 'EXCEL' 'XL-02' 'Controlled OFFLINE refresh 01->04 succeeds (Power Query loads, row counts validated, saved)' 'exit 0, all stages OK' ("exit {0}; {1}" -f $code, (($sum.Stages | ForEach-Object { "$($_.Stage)=$($_.Status)" }) -join ', ')) $(if ($code -eq 0 -and @($sum.Stages | Where-Object Status -ne 'OK').Count -eq 0) { 'PASS' } else { 'FAIL' })
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Invoke-PassressRefresh.ps1') -ConfigPath $cfgPath -Mode OFFLINE -OfflineExtractFolder $fixture -SimulateFailureAt 02_OPERATIONS | Out-Host
        $code = $LASTEXITCODE
        $sum = Get-ChildItem (Join-Path $root '08_LOGS') -Filter 'refresh_RUN-*.json' | Sort-Object LastWriteTime | Select-Object -Last 1 | ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json }
        $st = @{}; foreach ($s in $sum.Stages) { $st[$s.Stage] = $s.Status }
        Add-Result 'EXCEL' 'XL-03' 'Failure at 02 stops the chain: 03 and 04 SKIPPED, exit code 1' '01 OK, 02 FAILED, 03/04 SKIPPED' (($sum.Stages | ForEach-Object { "$($_.Stage)=$($_.Status)" }) -join ', ') $(if ($code -eq 1 -and $st['01_DATA_SOURCE'] -eq 'OK' -and $st['02_OPERATIONS'] -eq 'FAILED' -and $st['03_FINANCE'] -eq 'SKIPPED' -and $st['04_MANAGEMENT'] -eq 'SKIPPED') { 'PASS' } else { 'FAIL' })
        $excelLeft = @(Get-Process -Name EXCEL -ErrorAction SilentlyContinue | Where-Object { $_.StartTime -gt [datetime]$env_.Started })
        Add-Result 'EXCEL' 'XL-04' 'No orphan Excel process left by the controller' '0' $excelLeft.Count $(if ($excelLeft.Count -eq 0) { 'PASS' } else { 'FAIL' })
    } catch { Add-Result 'EXCEL' 'XL-ERR' 'Excel tests executed' 'no error' $_.Exception.Message 'FAIL' }
} else { Add-Result 'EXCEL' 'XL-SKIP' 'Excel COM end-to-end tests' 'run with -WithExcel on Windows' 'not executed' 'NOT_RUN' }

# ------------------------------------------------------------------ evidence
$pass = @($results | Where-Object Result -eq 'PASS').Count; $fail = @($results | Where-Object Result -eq 'FAIL').Count; $notrun = @($results | Where-Object Result -eq 'NOT_RUN').Count
$env_.Ended = (Get-Date).ToString('s')
Write-PassressJson -Object ([ordered]@{ Environment = $env_; Summary = @{ Pass = $pass; Fail = $fail; NotRun = $notrun }; Results = $results }) -Path (Join-Path $ResultsFolder "TEST_RESULTS_$stamp.json")
$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine("# PASSRESS offline test evidence - $stamp"); [void]$md.AppendLine('')
[void]$md.AppendLine(("PowerShell {0} ({1}) on {2}. PASS {3} / FAIL {4} / NOT RUN {5}." -f $env_.PowerShell, $env_.Edition, $env_.OS, $pass, $fail, $notrun)); [void]$md.AppendLine('')
[void]$md.AppendLine('| Group | Id | Check | Expected | Actual | Result |'); [void]$md.AppendLine('|---|---|---|---|---|---|')
foreach ($r in $results) { [void]$md.AppendLine(('| {0} | {1} | {2} | {3} | {4} | **{5}** |' -f $r.Group, $r.Id, ($r.Description -replace '\|', '/'), ($r.Expected -replace '\|', '/'), ($r.Actual -replace '\|', '/' -replace "`r?`n", ' '), $r.Result)) }
[System.IO.File]::WriteAllText((Join-Path $ResultsFolder "TEST_REPORT_$stamp.md"), $md.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("RESULT: PASS {0}  FAIL {1}  NOT RUN {2}   evidence: {3}" -f $pass, $fail, $notrun, $ResultsFolder)
if ($fail -gt 0) { $results | Where-Object Result -eq 'FAIL' | Format-Table Id, Description, Expected, Actual -AutoSize -Wrap | Out-Host; exit 1 }
exit 0
