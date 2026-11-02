#Requires -Version 5.1
<#
.SYNOPSIS  After moving PASSRESS_BUSINESS_SYSTEM to another folder/PC: updates the config file and the single
           Power Query parameter (pRootFolder) in all four workbooks. One command, no manual query editing.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ConfigPath, [Parameter(Mandatory)][string]$NewRootFolder)
$ErrorActionPreference = 'Stop'
$src = Join-Path (Split-Path $PSScriptRoot -Parent) 'src'
Import-Module (Join-Path $src 'Passress.Common.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $src 'Passress.Excel.psm1') -Force -DisableNameChecking
if (-not (Test-Path -LiteralPath $NewRootFolder)) { throw "Folder not found: $NewRootFolder" }
$raw = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$raw.RootFolder = (Resolve-Path -LiteralPath $NewRootFolder).Path
Copy-Item -LiteralPath $ConfigPath -Destination ($ConfigPath + '.bak') -Force
Write-PassressJson -Object $raw -Path $ConfigPath
$cfg = Get-PassressConfig -Path $ConfigPath; $paths = Get-PassressPaths -Config $cfg
$session = New-PassressExcel
try {
    foreach ($w in $paths.Workbooks.Values) {
        $wb = Open-PassressWorkbook -Session $session -Path $w.File
        try { Set-PassressRootParameter -Workbook $wb -RootFolder $paths.Root; $wb.Worksheets.Item('CONFIG').Cells.Item(4, 2).Value2 = $paths.Root; $wb.Save(); Write-PassressLog -Level OK -Message "Updated $($w.File)" }
        finally { $wb.Close($false) }
    }
} finally { Close-PassressExcel -Session $session }
Write-PassressLog -Message 'Run Invoke-PassressRefresh.ps1 to confirm every query resolves the new folder.'
