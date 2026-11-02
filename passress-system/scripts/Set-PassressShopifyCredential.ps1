#Requires -Version 5.1
<#
.SYNOPSIS  Stores the NEW (rotated) Shopify client id + secret, encrypted with Windows DPAPI for the current user.
.DESCRIPTION
  1. In the Shopify Dev Dashboard open app PASSRESS_DATA and rotate/revoke the old client secret (it was exposed in
     the original workbook and must be treated as compromised).
  2. Run this script and paste the client id and the NEW secret when prompted (the secret is not echoed).
  The file is %LOCALAPPDATA%\Passress\shopify_credential.xml - outside the project folder and outside git.
  Nothing else in the system stores or prints the secret.
#>
[CmdletBinding()] param()
$ErrorActionPreference = 'Stop'
$src = Join-Path (Split-Path $PSScriptRoot -Parent) 'src'
Import-Module (Join-Path $src 'Passress.Common.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $src 'Passress.Shopify.psm1') -Force -DisableNameChecking
$answer = Read-Host 'Have you rotated (revoked) the OLD client secret in the Shopify Dev Dashboard? (yes/no)'
if ($answer -notmatch '^(?i)y(es)?$') { Write-PassressLog -Level WARN -Message 'Rotate the old secret first. Nothing was stored.'; exit 1 }
Set-PassressShopifyCredential
