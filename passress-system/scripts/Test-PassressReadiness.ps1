#Requires -Version 5.1
<#
.SYNOPSIS  Step 1 - implementation readiness. Read-only: changes nothing except writing a readiness report to 08_LOGS.
.EXAMPLE   .\Test-PassressReadiness.ps1 -ConfigPath C:\PASSRESS_BUSINESS_SYSTEM\07_CONFIGURATION\passress.config.json -OriginalWorkbookPath "C:\Users\me\Downloads\Passress(3).xlsx"
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ConfigPath, [string]$OriginalWorkbookPath)
$ErrorActionPreference = 'Stop'
$src = Join-Path (Split-Path $PSScriptRoot -Parent) 'src'
Import-Module (Join-Path $src 'Passress.Common.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $src 'Passress.Shopify.psm1') -Force -DisableNameChecking

$checks = New-Object System.Collections.Generic.List[object]
function Add-Check { param($Name, $Status, $Detail) $checks.Add([pscustomobject]@{ Check = $Name; Status = $Status; Detail = $Detail }); $lvl = @{ PASS = 'OK'; WARN = 'WARN'; FAIL = 'ERROR'; INFO = 'INFO' }[$Status]; Write-PassressLog -Level $lvl -Message ("{0,-34} {1,-5} {2}" -f $Name, $Status, $Detail) }

Add-Check 'PowerShell version' $(if ($PSVersionTable.PSVersion.Major -ge 5) { 'PASS' } else { 'FAIL' }) $PSVersionTable.PSVersion.ToString()
Add-Check 'Operating system' $(if ($env:OS -eq 'Windows_NT') { 'PASS' } else { 'FAIL' }) ([System.Environment]::OSVersion.VersionString)

$cfg = $null
try { $cfg = Get-PassressConfig -Path $ConfigPath; Add-Check 'Config file' 'PASS' $ConfigPath } catch { Add-Check 'Config file' 'FAIL' $_.Exception.Message }
if ($cfg) {
    $paths = Get-PassressPaths -Config $cfg
    try { if (-not (Test-Path $paths.Root)) { New-Item -ItemType Directory -Path $paths.Root -Force | Out-Null }; $probe = Join-Path $paths.Root '.write_test'; Set-Content $probe 'x'; Remove-Item $probe; Add-Check 'Root folder writable' 'PASS' $paths.Root } catch { Add-Check 'Root folder writable' 'FAIL' $_.Exception.Message }
    try { [void](Get-ShopTimeZone $cfg); Add-Check 'Shop time zone' 'PASS' $cfg.TimeZoneWindows } catch { Add-Check 'Shop time zone' 'FAIL' $_.Exception.Message }
    Add-Check 'Shopify API version' 'INFO' ("{0} (pinned; review twice a year)" -f $cfg.ApiVersion)
}

# Excel COM
$xl = $null
try {
    $xl = New-Object -ComObject Excel.Application
    $ver = [double]$xl.Version
    $label = switch ($ver) { 16 { 'Excel 2016 / 2019 / 2021 / Microsoft 365 (all report 16.0)' } 15 { 'Excel 2013' } default { "Excel $ver" } }
    Add-Check 'Excel COM' $(if ($ver -ge 16) { 'PASS' } else { 'FAIL' }) ("{0}, build {1}" -f $label, $xl.Build)
    $wb = $xl.Workbooks.Add()
    try { $null = $wb.Queries.Count; Add-Check 'Power Query object model' 'PASS' 'Workbook.Queries available (required to install queries)' } catch { Add-Check 'Power Query object model' 'FAIL' 'Workbook.Queries not available - Excel 2016+ desktop required.' }
    $wb.Close($false)
    Add-Check 'Excel list separator' 'INFO' $xl.International(5)
} catch { Add-Check 'Excel COM' 'FAIL' "Excel could not be started via COM: $($_.Exception.Message)" }
finally { if ($xl) { $xl.Quit(); [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($xl) } }

if ($OriginalWorkbookPath) {
    try {
        $fp = Get-PassressFileFingerprint -Path $OriginalWorkbookPath
        $expected = if ($cfg) { [string](Get-PassressConfigValue $cfg 'ExpectedOriginalSha256' '') } else { '' }
        $st = if ($expected -and $fp.SHA256 -ne $expected) { 'WARN' } else { 'PASS' }
        Add-Check 'Original workbook' $st ("{0} | {1} bytes | modified {2} | SHA-256 {3}{4}" -f $fp.Path, $fp.SizeBytes, $fp.LastWriteTimeUtc, $fp.SHA256, $(if ($st -eq 'WARN') { ' (differs from the audited file)' } else { ' (matches audited file)' }))
        if ($cfg) { Write-PassressJson -Object $fp -Path (Join-Path $paths.Logs 'original_workbook_fingerprint.json') }
    } catch { Add-Check 'Original workbook' 'FAIL' $_.Exception.Message }
} else { Add-Check 'Original workbook' 'WARN' 'Not provided (-OriginalWorkbookPath) - legacy migration will be skipped.' }

Add-Check 'Shopify credential' $(if (Test-PassressShopifyCredential) { 'PASS' } else { 'WARN' }) $(if (Test-PassressShopifyCredential) { 'Encrypted credential present (contents not shown).' } else { 'Not configured. LIVE refresh blocked until the old secret is rotated and the new one stored.' })

if ($cfg) { Write-PassressJson -Object $checks -Path (Join-Path $paths.Logs ('readiness_{0}.json' -f (Get-Date -Format 'yyyyMMdd_HHmmss'))) }
$fails = @($checks | Where-Object Status -eq 'FAIL').Count
if ($fails -gt 0) { Write-PassressLog -Level ERROR -Message "$fails readiness check(s) failed."; exit 1 } else { Write-PassressLog -Level OK -Message 'Ready.'; exit 0 }
