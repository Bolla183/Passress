#Requires -Version 5.1
<#
.SYNOPSIS  Restores the four workbooks and the engine outputs/state from a folder in 05_BACKUPS
           (created by Invoke-PassressRefresh.ps1 or Build-PassressSystem.ps1 -Rebuild).
.DESCRIPTION  The current files are backed up first (label pre-restore), so a restore can itself be undone.
#>
[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$ConfigPath, [Parameter(Mandatory)][string]$BackupFolder)
$ErrorActionPreference = 'Stop'
$src = Join-Path (Split-Path $PSScriptRoot -Parent) 'src'
Import-Module (Join-Path $src 'Passress.Common.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $src 'Passress.Excel.psm1') -Force -DisableNameChecking
$cfg = Get-PassressConfig -Path $ConfigPath; $paths = Get-PassressPaths -Config $cfg
if (-not (Test-Path -LiteralPath $BackupFolder)) { throw "Backup folder not found: $BackupFolder" }
$current = @(); foreach ($w in $paths.Workbooks.Values) { if (-not (Test-PassressFileUnlocked $w.File)) { throw "Close $($w.File) first." }; $current += $w.File, $w.Outputs, $w.State }
$pre = Backup-PassressFiles -Paths $current -BackupRoot $paths.Backups -Label 'pre-restore' -RelativeTo $paths.Root
Write-PassressLog -Message "Current files backed up to $($pre.Folder)"
$root = (Resolve-Path -LiteralPath $paths.Root).Path.TrimEnd('\')
foreach ($w in $paths.Workbooks.Values) {
    foreach ($item in @($w.File, $w.Outputs, $w.State)) {
        $rel = $item.Substring($root.Length).TrimStart('\'); $from = Join-Path $BackupFolder $rel
        if (-not (Test-Path -LiteralPath $from)) { Write-PassressLog -Level WARN -Message "Not in backup: $rel"; continue }
        if ($PSCmdlet.ShouldProcess($item, 'restore')) {
            if ((Get-Item -LiteralPath $from).PSIsContainer) { if (Test-Path -LiteralPath $item) { Remove-Item -LiteralPath $item -Recurse -Force }; Copy-Item -LiteralPath $from -Destination $item -Recurse -Force }
            else { Copy-Item -LiteralPath $from -Destination $item -Force }
            Write-PassressLog -Level OK -Message "Restored $rel"
        }
    }
}
Write-PassressLog -Message 'Restore complete. Open each workbook HOME sheet to confirm the run id, or re-run Invoke-PassressRefresh.ps1.'
