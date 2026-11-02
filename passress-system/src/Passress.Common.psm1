#Requires -Version 5.1
<#
  Passress.Common - shared helpers for the PASSRESS business system.
  Compatible with Windows PowerShell 5.1 and PowerShell 7+.
  Never writes credentials anywhere.
#>
Set-StrictMode -Version 2.0

$script:Invariant = [System.Globalization.CultureInfo]::InvariantCulture
$script:SchemaCache = $null
$script:LogFile = $null

# --------------------------------------------------------------------------- schema
function Get-PassressSchema {
    [CmdletBinding()] param([string]$Path)
    if (-not $Path) { $Path = Join-Path (Split-Path $PSScriptRoot -Parent) 'schemas\tables.json' }
    if ($script:SchemaCache -and $script:SchemaCache.Path -eq $Path) { return $script:SchemaCache.Schema }
    if (-not (Test-Path -LiteralPath $Path)) { throw "Schema file not found: $Path" }
    $schema = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    $script:SchemaCache = @{ Path = $Path; Schema = $schema }
    return $schema
}

function Get-PassressTableSchema {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Workbook, [Parameter(Mandatory)][string]$Table)
    $schema = Get-PassressSchema
    $wb = $schema.workbooks.$Workbook
    if (-not $wb) { throw "Unknown workbook '$Workbook' in schema." }
    $t = $wb.tables | Where-Object { $_.name -eq $Table } | Select-Object -First 1
    if (-not $t) { throw "Unknown table '$Table' in workbook '$Workbook'." }
    $cols = @()
    foreach ($c in $t.columns) { $cols += [pscustomobject]@{ Name = [string]$c[0]; Type = [string]$c[1]; Description = [string]$c[2] } }
    return [pscustomobject]@{ Workbook = $Workbook; Name = $t.name; Kind = $t.kind; Purpose = $t.purpose; Columns = $cols }
}

# --------------------------------------------------------------------------- config
function Get-PassressConfig {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Config file not found: $Path. Copy config\passress.config.template.json and edit it." }
    $cfg = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($req in @('RootFolder', 'ShopDomain', 'ApiVersion', 'TimeZoneWindows', 'TimeZoneIana', 'Currency')) {
        if (-not ($cfg.PSObject.Properties.Name -contains $req) -or [string]::IsNullOrWhiteSpace([string]$cfg.$req)) {
            throw "Config value '$req' is missing in $Path."
        }
    }
    foreach ($p in $cfg.PSObject.Properties) {
        if ($p.Name -match '(?i)secret|password|token') { throw "Config file must not contain credentials (found '$($p.Name)'). Use scripts\Set-PassressShopifyCredential.ps1." }
    }
    return $cfg
}

function Get-PassressConfigValue {
    param([Parameter(Mandatory)]$Config, [Parameter(Mandatory)][string]$Name, $Default)
    if ($Config.PSObject.Properties.Name -contains $Name -and -not [string]::IsNullOrWhiteSpace([string]$Config.$Name)) { return $Config.$Name }
    return $Default
}

function Get-PassressPaths {
    [CmdletBinding()] param([Parameter(Mandatory)]$Config)
    $root = [string]$Config.RootFolder
    $schema = Get-PassressSchema
    $wbs = @{}
    foreach ($name in @('01_DATA_SOURCE', '02_OPERATIONS', '03_FINANCE', '04_MANAGEMENT')) {
        $w = $schema.workbooks.$name
        $folder = Join-Path $root $w.folder
        $wbs[$name] = [pscustomobject]@{
            Name = $name; Folder = $folder; File = (Join-Path $root $w.file)
            Outputs = (Join-Path $folder 'outputs'); Inputs = (Join-Path $folder 'inputs_snapshot'); State = (Join-Path $folder 'state')
        }
    }
    return [pscustomobject]@{
        Root = $root; Workbooks = $wbs
        Backups = (Join-Path $root '05_BACKUPS'); Documentation = (Join-Path $root '06_DOCUMENTATION')
        Configuration = (Join-Path $root '07_CONFIGURATION'); Logs = (Join-Path $root '08_LOGS')
        Staging = (Join-Path (Join-Path $root '01_DATA_SOURCE') 'staging')
    }
}

# --------------------------------------------------------------------------- logging
function Set-PassressLogFile { param([string]$Path) $script:LogFile = $Path }

function Write-PassressLog {
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR', 'OK')][string]$Level = 'INFO')
    # Defensive redaction: never let anything that looks like a Shopify secret/token reach a log.
    $safe = $Message -replace '(shp(at|ss|ca|pa|ua)_)[A-Za-z0-9]+', '$1<REDACTED>' -replace '(?i)(access_token|client_secret)=([^&\s"]+)', '$1=<REDACTED>'
    $line = '{0} [{1}] {2}' -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss', $script:Invariant), $Level, $safe
    if ($script:LogFile) { Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 }
    switch ($Level) { 'ERROR' { Write-Host $line -ForegroundColor Red } 'WARN' { Write-Host $line -ForegroundColor Yellow } 'OK' { Write-Host $line -ForegroundColor Green } default { Write-Host $line } }
}

function New-PassressRunId { return ('RUN-{0}' -f (Get-Date).ToString('yyyyMMdd-HHmmss', $script:Invariant)) }

# --------------------------------------------------------------------------- values
function Get-Money { param($Value) if ($null -eq $Value -or "$Value" -eq '') { return 0.0 } return [math]::Round([double]$Value, 2, [System.MidpointRounding]::AwayFromZero) }
function Get-RoundedMoney { param([double]$Value) return [math]::Round($Value, 2, [System.MidpointRounding]::AwayFromZero) }
function Test-Blank { param($Value) return ($null -eq $Value -or ([string]$Value).Trim() -eq '') }
function Get-SafeDivide { param($Numerator, $Denominator) if ($null -eq $Numerator -or $null -eq $Denominator -or [double]$Denominator -eq 0) { return $null } return [math]::Round([double]$Numerator / [double]$Denominator, 4) }

function ConvertTo-PassressDate {
    # Accepts DateTime, ISO text, Excel OADate number. Returns [datetime] (date part) or $null.
    param($Value)
    if (Test-Blank $Value) { return $null }
    if ($Value -is [datetime]) { return $Value.Date }
    if ($Value -is [double] -or $Value -is [int] -or $Value -is [decimal]) { return [DateTime]::FromOADate([double]$Value).Date }
    $s = ([string]$Value).Trim()
    $d = [datetime]::MinValue
    $styles = [System.Globalization.DateTimeStyles]::AllowWhiteSpaces
    foreach ($fmt in @('yyyy-MM-dd', 'yyyy-MM-ddTHH:mm:ss', 'yyyy-MM-ddTHH:mm:ssZ', 'yyyy-MM-dd HH:mm:ss', 'dd/MM/yyyy', 'd/M/yyyy')) {
        if ([datetime]::TryParseExact($s, $fmt, $script:Invariant, $styles, [ref]$d)) { return $d.Date }
    }
    $num = 0.0
    if ([double]::TryParse($s, [System.Globalization.NumberStyles]::Float, $script:Invariant, [ref]$num)) { return [DateTime]::FromOADate($num).Date }
    throw "Cannot interpret '$s' as a date."
}

function ConvertTo-PassressDateTime {
    param($Value)
    if (Test-Blank $Value) { return $null }
    if ($Value -is [datetime]) { return $Value }
    if ($Value -is [double]) { return [DateTime]::FromOADate($Value) }
    $s = ([string]$Value).Trim()
    $dto = [datetimeoffset]::MinValue
    if ([datetimeoffset]::TryParse($s, $script:Invariant, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$dto)) { return $dto.UtcDateTime }
    throw "Cannot interpret '$s' as a date/time."
}

function Get-ShopTimeZone {
    param([Parameter(Mandatory)]$Config)
    foreach ($id in @([string]$Config.TimeZoneWindows, [string]$Config.TimeZoneIana)) {
        try { return [System.TimeZoneInfo]::FindSystemTimeZoneById($id) } catch { }
    }
    throw "Time zone not found ($($Config.TimeZoneWindows) / $($Config.TimeZoneIana))."
}

function ConvertTo-ShopLocalDate {
    # UTC ISO timestamp -> shop-local calendar date (Egypt observes DST, so never add a fixed offset).
    param($UtcValue, [Parameter(Mandatory)][System.TimeZoneInfo]$TimeZone)
    if (Test-Blank $UtcValue) { return $null }
    $dto = [datetimeoffset]::MinValue
    if ($UtcValue -is [datetime]) { $utc = [datetime]::SpecifyKind($UtcValue, [System.DateTimeKind]::Utc) }
    elseif ([datetimeoffset]::TryParse([string]$UtcValue, $script:Invariant, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$dto)) { $utc = $dto.UtcDateTime }
    else { throw "Bad timestamp '$UtcValue'." }
    return ([System.TimeZoneInfo]::ConvertTimeFromUtc($utc, $TimeZone)).Date
}

function Get-MonthKey { param($Date) if ($null -eq $Date) { return $null } return ([datetime]$Date).ToString('yyyy-MM', $script:Invariant) }

function ConvertTo-PassressBool {
    param($Value)
    if ($null -eq $Value) { return $false }
    if ($Value -is [bool]) { return $Value }
    $s = ([string]$Value).Trim().ToUpperInvariant()
    return ($s -eq 'TRUE' -or $s -eq '1' -or $s -eq 'YES' -or $s -eq 'Y')
}

function Format-PassressValue {
    param($Value, [string]$Type)
    if ($null -eq $Value) { return '' }
    if ($Value -is [string] -and $Value -eq '') { return '' }
    switch ($Type) {
        'number'   { return ([double]$Value).ToString('0.##########', $script:Invariant) }
        'int'      { return ([long][math]::Round([double]$Value)).ToString($script:Invariant) }
        'date'     { $d = ConvertTo-PassressDate $Value; return $d.ToString('yyyy-MM-dd', $script:Invariant) }
        'datetime' { $d = ConvertTo-PassressDateTime $Value; return $d.ToString('yyyy-MM-ddTHH:mm:ss', $script:Invariant) }
        'bool'     { if (ConvertTo-PassressBool $Value) { return 'TRUE' } else { return 'FALSE' } }
        default    { return [string]$Value }
    }
}

function ConvertFrom-PassressText {
    param([string]$Text, [string]$Type)
    if ($null -eq $Text -or $Text -eq '') { return $null }
    switch ($Type) {
        'number'   { return [double]::Parse($Text, [System.Globalization.NumberStyles]::Float, $script:Invariant) }
        'int'      { return [long][math]::Round([double]::Parse($Text, [System.Globalization.NumberStyles]::Float, $script:Invariant)) }
        'date'     { return ConvertTo-PassressDate $Text }
        'datetime' { return ConvertTo-PassressDateTime $Text }
        'bool'     { return (ConvertTo-PassressBool $Text) }
        default    { return $Text }
    }
}

# --------------------------------------------------------------------------- CSV (culture-independent)
function ConvertTo-PassressSchemaRows {
    # Projects arbitrary hashtables/objects onto the schema column list. Unknown keys are a programming error.
    param([Parameter(Mandatory)][string]$Workbook, [Parameter(Mandatory)][string]$Table, [AllowEmptyCollection()][object[]]$Rows)
    $ts = Get-PassressTableSchema -Workbook $Workbook -Table $Table
    $names = @($ts.Columns | ForEach-Object { $_.Name })
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($r in @($Rows)) {
        if ($null -eq $r) { continue }
        $keys = if ($r -is [System.Collections.IDictionary]) { @($r.Keys) } else { @($r.PSObject.Properties.Name) }
        foreach ($k in $keys) { if ($names -notcontains $k) { throw "Table $Workbook.$Table has no column '$k'." } }
        $o = [ordered]@{}
        foreach ($n in $names) {
            if ($r -is [System.Collections.IDictionary]) { $o[$n] = if ($r.Contains($n)) { $r[$n] } else { $null } }
            else { $p = $r.PSObject.Properties[$n]; $o[$n] = if ($p) { $p.Value } else { $null } }
        }
        $out.Add([pscustomobject]$o)
    }
    return , $out.ToArray()
}

function Export-PassressTable {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Workbook, [Parameter(Mandatory)][string]$Table, [AllowEmptyCollection()][object[]]$Rows, [Parameter(Mandatory)][string]$Directory)
    $ts = Get-PassressTableSchema -Workbook $Workbook -Table $Table
    $projected = ConvertTo-PassressSchemaRows -Workbook $Workbook -Table $Table -Rows $Rows
    if (-not (Test-Path -LiteralPath $Directory)) { New-Item -ItemType Directory -Path $Directory -Force | Out-Null }
    $path = Join-Path $Directory ($Table + '.csv')
    $tmp = $path + '.tmp'
    $enc = New-Object System.Text.UTF8Encoding($true)
    $sw = New-Object System.IO.StreamWriter($tmp, $false, $enc)
    try {
        $sw.WriteLine((($ts.Columns | ForEach-Object { '"' + $_.Name + '"' }) -join ','))
        foreach ($row in $projected) {
            $cells = foreach ($c in $ts.Columns) {
                $v = Format-PassressValue -Value $row.($c.Name) -Type $c.Type
                '"' + ($v -replace '"', '""' -replace "`r?`n", ' ') + '"'
            }
            $sw.WriteLine(($cells -join ','))
        }
    } finally { $sw.Close() }
    Move-Item -LiteralPath $tmp -Destination $path -Force   # atomic replace: Excel never sees a half-written file
    return [pscustomobject]@{ Table = $Table; Path = $path; Rows = $projected.Count }
}

function Import-PassressTable {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Workbook, [Parameter(Mandatory)][string]$Table, [Parameter(Mandatory)][string]$Directory, [switch]$AllowMissing)
    $ts = Get-PassressTableSchema -Workbook $Workbook -Table $Table
    $path = Join-Path $Directory ($Table + '.csv')
    if (-not (Test-Path -LiteralPath $path)) {
        if ($AllowMissing) { return , @() }
        throw "Expected table file not found: $path"
    }
    $raw = @(Import-Csv -LiteralPath $path -Encoding UTF8)
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($r in $raw) {
        $o = [ordered]@{}
        foreach ($c in $ts.Columns) {
            $p = $r.PSObject.Properties[$c.Name]
            $o[$c.Name] = if ($p) { ConvertFrom-PassressText -Text ([string]$p.Value) -Type $c.Type } else { $null }
        }
        $rows.Add([pscustomobject]$o)
    }
    return , $rows.ToArray()
}

# --------------------------------------------------------------------------- exceptions
function New-PassressException {
    param(
        [Parameter(Mandatory)][string]$CheckName, [ValidateSet('ERROR', 'WARNING', 'INFO')][string]$Severity = 'ERROR',
        [string]$AffectedRecord, [string]$OrderName, [string]$Classification,
        $ExpectedValue, $ActualValue, $Difference, [string]$RecommendedAction, [string]$RunId
    )
    $key = '{0}|{1}' -f $CheckName, $AffectedRecord
    $sha = [System.Security.Cryptography.SHA1]::Create()
    try { $hash = ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($key)) | ForEach-Object { $_.ToString('x2') }) -join '' } finally { $sha.Dispose() }
    return [ordered]@{
        ExceptionID = 'EX-' + $hash.Substring(0, 12); CheckName = $CheckName; Severity = $Severity; Status = 'OPEN'
        AffectedRecord = $AffectedRecord; OrderName = $OrderName; Classification = $Classification
        ExpectedValue = if ($null -eq $ExpectedValue) { $null } else { [string]$ExpectedValue }
        ActualValue = if ($null -eq $ActualValue) { $null } else { [string]$ActualValue }
        Difference = $Difference; RecommendedAction = $RecommendedAction; RunId = $RunId
    }
}

function Get-UniqueExceptions {
    param([AllowEmptyCollection()][object[]]$Exceptions)
    $seen = @{}; $out = New-Object System.Collections.Generic.List[object]
    foreach ($e in @($Exceptions)) { if ($null -eq $e) { continue }; if (-not $seen.ContainsKey($e.ExceptionID)) { $seen[$e.ExceptionID] = $true; $out.Add($e) } }
    return , $out.ToArray()
}

# --------------------------------------------------------------------------- files
function Get-PassressFileFingerprint {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "File not found: $Path" }
    $item = Get-Item -LiteralPath $Path
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    return [pscustomobject]@{ Path = $item.FullName; SizeBytes = $item.Length; LastWriteTimeUtc = $item.LastWriteTimeUtc.ToString('yyyy-MM-ddTHH:mm:ssZ', $script:Invariant); SHA256 = $hash }
}

function Backup-PassressFiles {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string[]]$Paths, [Parameter(Mandatory)][string]$BackupRoot, [Parameter(Mandatory)][string]$Label, [string]$RelativeTo)
    $stamp = (Get-Date).ToString('yyyy-MM-dd_HHmmss', $script:Invariant)
    $dest = Join-Path $BackupRoot ('{0}_{1}' -f $stamp, ($Label -replace '[^A-Za-z0-9_-]', '_'))
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    $copied = @()
    foreach ($p in $Paths) {
        if (Test-Path -LiteralPath $p) {
            # keep the path relative to the system root so 01..04 "outputs"/"state" folders never collide
            $rel = Split-Path $p -Leaf
            if ($RelativeTo) { $full = (Resolve-Path -LiteralPath $p).Path; $rootFull = (Resolve-Path -LiteralPath $RelativeTo).Path.TrimEnd('\', '/'); if ($full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) { $rel = $full.Substring($rootFull.Length).TrimStart('\', '/') } }
            $target = Join-Path $dest $rel
            $parent = Split-Path $target -Parent; if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
            if ((Get-Item -LiteralPath $p).PSIsContainer) { Copy-Item -LiteralPath $p -Destination $target -Recurse -Force }
            else { Copy-Item -LiteralPath $p -Destination $target -Force }
            $copied += $target
        }
    }
    return [pscustomobject]@{ Folder = $dest; Items = $copied }
}

function Write-PassressJson { param([Parameter(Mandatory)]$Object, [Parameter(Mandatory)][string]$Path)
    $dir = Split-Path $Path -Parent; if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, ($Object | ConvertTo-Json -Depth 20), (New-Object System.Text.UTF8Encoding($false)))
}
function Read-PassressJson { param([Parameter(Mandatory)][string]$Path) if (-not (Test-Path -LiteralPath $Path)) { return $null }; return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json) }

Export-ModuleMember -Function *-Passress*, Get-Money, Get-RoundedMoney, Test-Blank, Get-SafeDivide, Get-ShopTimeZone, ConvertTo-ShopLocalDate, Get-MonthKey, Format-PassressValue, ConvertFrom-PassressText, New-PassressException, Get-UniqueExceptions, Write-PassressJson, Read-PassressJson, Set-PassressLogFile, New-PassressRunId
