#Requires -Version 5.1
<#
  Passress.Excel - Excel COM automation (Windows + Excel 2016/2019/365 desktop only).
  Safety rules:
   * Always starts its OWN Excel instance and records its process id; only that process is ever terminated.
   * Never touches workbooks the user has open (locked files are refused).
   * Never saves after a failed operation - callers close with SaveChanges = $false.
   * Workbooks are saved as .xlsx (xlOpenXMLWorkbook = 51) - no macros.
#>
Set-StrictMode -Version 2.0
Import-Module (Join-Path $PSScriptRoot 'Passress.Common.psm1') -Force -DisableNameChecking

if ($env:OS -eq 'Windows_NT' -and -not ('PassressWin32' -as [type])) {
    Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class PassressWin32 { [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId); }
'@
}

$script:Brand = @{ Olive = 0x394D24; Espresso = 0x4A2E1F; White = 0xFFFFFF; Light = 0xFAFAFA; Border = 0xE5E5E5; Input = 0xF3F6EE }
function ConvertTo-ExcelColor { param([int]$Rgb) $r = ($Rgb -shr 16) -band 0xFF; $g = ($Rgb -shr 8) -band 0xFF; $b = $Rgb -band 0xFF; return ($r + ($g * 256) + ($b * 65536)) }

# --------------------------------------------------------------------------- instance management
function New-PassressExcel {
    [CmdletBinding()] param([switch]$Visible)
    if ($env:OS -ne 'Windows_NT') { throw 'Excel COM automation requires Windows with Microsoft Excel desktop installed.' }
    try { $xl = New-Object -ComObject Excel.Application } catch { throw "EXCEL_COM_UNAVAILABLE: could not start Excel via COM ($($_.Exception.Message))." }
    $xl.Visible = [bool]$Visible; $xl.DisplayAlerts = $false; $xl.AskToUpdateLinks = $false; $xl.EnableEvents = $false; $xl.ScreenUpdating = $false
    try { $xl.AutomationSecurity = 3 } catch { }   # msoAutomationSecurityForceDisable: never run macros in files we open
    $procId = [uint32]0
    [void][PassressWin32]::GetWindowThreadProcessId([IntPtr]$xl.Hwnd, [ref]$procId)
    return [pscustomobject]@{ App = $xl; ProcessId = [int]$procId; Version = $xl.Version; Build = $xl.Build }
}

function Close-PassressExcel {
    param([Parameter(Mandatory)]$Session)
    try { foreach ($wb in @($Session.App.Workbooks)) { $wb.Close($false) } } catch { }
    try { $Session.App.Quit() } catch { }
    try { [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($Session.App) } catch { }
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    Start-Sleep -Seconds 2
    $p = Get-Process -Id $Session.ProcessId -ErrorAction SilentlyContinue
    if ($p -and $p.ProcessName -like 'EXCEL*') {
        Write-PassressLog -Level WARN -Message "Our Excel instance (PID $($Session.ProcessId)) did not exit; terminating that process only."
        Stop-Process -Id $Session.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

function Test-PassressFileUnlocked {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $true }
    try { $fs = [System.IO.File]::Open($Path, 'Open', 'ReadWrite', 'None'); $fs.Close(); return $true } catch { return $false }
}

function Open-PassressWorkbook {
    param([Parameter(Mandatory)]$Session, [Parameter(Mandatory)][string]$Path, [switch]$ReadOnly)
    if (-not $ReadOnly -and -not (Test-PassressFileUnlocked $Path)) { throw "WORKBOOK_LOCKED: $Path is open in Excel or another program. Close it and run again." }
    return $Session.App.Workbooks.Open($Path, 0, [bool]$ReadOnly)
}

# --------------------------------------------------------------------------- read / export tables
function Get-PassressListObject {
    param([Parameter(Mandatory)]$Workbook, [Parameter(Mandatory)][string]$Name)
    foreach ($ws in @($Workbook.Worksheets)) { foreach ($lo in @($ws.ListObjects)) { if ($lo.Name -eq $Name) { return $lo } } }
    return $null
}

function Read-PassressListObjectRows {
    # Returns rows as ordered dictionaries keyed by header; Excel serial dates are converted per schema type.
    param([Parameter(Mandatory)]$ListObject, $ColumnTypes)
    $headers = @(); foreach ($c in @($ListObject.ListColumns)) { $headers += [string]$c.Name }
    $rows = New-Object System.Collections.Generic.List[object]
    if ($null -eq $ListObject.DataBodyRange) { return , $rows.ToArray() }
    $vals = $ListObject.DataBodyRange.Value2
    $nr = $ListObject.DataBodyRange.Rows.Count; $nc = $headers.Count
    for ($r = 1; $r -le $nr; $r++) {
        $o = [ordered]@{}; $any = $false
        for ($c = 1; $c -le $nc; $c++) {
            $v = if ($nr -eq 1 -and $nc -eq 1) { $vals } else { $vals[$r, $c] }
            if ($null -ne $v -and "$v" -ne '') { $any = $true }
            $t = if ($ColumnTypes -and $ColumnTypes.ContainsKey($headers[$c - 1])) { $ColumnTypes[$headers[$c - 1]] } else { 'text' }
            if ($null -ne $v -and ($t -eq 'date' -or $t -eq 'datetime') -and $v -is [double]) { $v = [DateTime]::FromOADate($v) }
            $o[$headers[$c - 1]] = $v
        }
        if ($any) { $rows.Add($o) }   # fully blank rows (the spare input row) are skipped
    }
    return , $rows.ToArray()
}

function Export-PassressInputTables {
    # Snapshots every input table of a workbook to <folder>\inputs_snapshot\*.csv for the engine.
    param([Parameter(Mandatory)]$Workbook, [Parameter(Mandatory)][string]$Stage, [Parameter(Mandatory)][string]$Directory)
    $schema = Get-PassressSchema; $counts = @{}
    foreach ($t in @($schema.workbooks.$Stage.tables | Where-Object { $_.kind -eq 'input' })) {
        $ts = Get-PassressTableSchema -Workbook $Stage -Table $t.name
        $types = @{}; foreach ($c in $ts.Columns) { $types[$c.Name] = $c.Type }
        $lo = Get-PassressListObject -Workbook $Workbook -Name $t.name
        if ($null -eq $lo) { throw "INPUT_TABLE_MISSING: table $($t.name) not found in $Stage workbook." }
        $rows = Read-PassressListObjectRows -ListObject $lo -ColumnTypes $types
        $missingCols = @($ts.Columns | Where-Object { @($lo.ListColumns | ForEach-Object { $_.Name }) -notcontains $_.Name } | ForEach-Object { $_.Name })
        if ($missingCols.Count -gt 0) { throw "INPUT_TABLE_COLUMNS_CHANGED: $($t.name) is missing column(s) $($missingCols -join ', '). Do not rename or delete input columns." }
        $clean = @(); foreach ($r in $rows) { $o = [ordered]@{}; foreach ($c in $ts.Columns) { $o[$c.Name] = $r[$c.Name] }; $clean += $o }
        Export-PassressTable -Workbook $Stage -Table $t.name -Rows $clean -Directory $Directory | Out-Null
        $counts[$t.name] = $clean.Count
    }
    return $counts
}

# --------------------------------------------------------------------------- refresh
function Invoke-PassressWorkbookRefresh {
    # Refreshes every connection synchronously, one by one, so a failure is attributable and reported.
    param([Parameter(Mandatory)]$Session, [Parameter(Mandatory)]$Workbook)
    $results = @()
    foreach ($cn in @($Workbook.Connections)) {
        try { if ($cn.Type -eq 1) { $cn.OLEDBConnection.BackgroundQuery = $false } } catch { }
    }
    foreach ($cn in @($Workbook.Connections)) {
        $name = [string]$cn.Name; $start = Get-Date
        try { $cn.Refresh(); $results += [pscustomobject]@{ Connection = $name; Status = 'OK'; Error = $null; Seconds = [math]::Round(((Get-Date) - $start).TotalSeconds, 1) } }
        catch { $results += [pscustomobject]@{ Connection = $name; Status = 'FAILED'; Error = $_.Exception.Message; Seconds = [math]::Round(((Get-Date) - $start).TotalSeconds, 1) } }
    }
    try { $Session.App.CalculateUntilAsyncQueriesDone() } catch { }
    foreach ($ws in @($Workbook.Worksheets)) {
        foreach ($pt in @($ws.PivotTables())) {
            try { $pt.PivotCache().Refresh() } catch { $results += [pscustomobject]@{ Connection = 'PIVOT:' + $pt.Name; Status = 'FAILED'; Error = $_.Exception.Message; Seconds = 0 } }
            # Quarterly / annual pivots must never add up percentage rows.
            if ($pt.Name -like '*_NORATIO') { try { $pt.PivotFields('Section').PivotItems('RATIO').Visible = $false } catch { } }
        }
    }
    $Session.App.CalculateFull()
    return , $results
}

function Get-PassressListObjectRowCount {
    param([Parameter(Mandatory)]$Workbook, [Parameter(Mandatory)][string]$Name)
    $lo = Get-PassressListObject -Workbook $Workbook -Name $Name
    if ($null -eq $lo) { return -1 }
    if ($null -eq $lo.DataBodyRange) { return 0 }
    # a query table with zero rows still shows one empty body row
    $n = $lo.DataBodyRange.Rows.Count
    if ($n -eq 1) { $v = $lo.DataBodyRange.Value2; $blank = $true; foreach ($x in @($v)) { if ($null -ne $x -and "$x" -ne '') { $blank = $false } }; if ($blank) { return 0 } }
    return $n
}

# --------------------------------------------------------------------------- build helpers
function Get-PassressMType { param([string]$Type) switch ($Type) { 'number' { 'type number' } 'int' { 'Int64.Type' } 'date' { 'type date' } 'datetime' { 'type datetime' } 'bool' { 'type logical' } default { 'type text' } } }

function New-PassressCsvQueryFormula {
    # Power Query (Excel 2019 compatible) that loads one engine output CSV. Path built from the pRootFolder parameter.
    param([Parameter(Mandatory)][string]$Stage, [Parameter(Mandatory)][string]$Table)
    $ts = Get-PassressTableSchema -Workbook $Stage -Table $Table
    $folder = (Get-PassressSchema).workbooks.$Stage.folder
    $nonText = @($ts.Columns | Where-Object { $_.Type -ne 'text' } | ForEach-Object { '"' + $_.Name + '"' })
    $types = ($ts.Columns | ForEach-Object { '{{"{0}", {1}}}' -f $_.Name, (Get-PassressMType $_.Type) }) -join ', '
    $blankStep = if ($nonText.Count -gt 0) { "    Blanks = Table.ReplaceValue(Promoted, `"`", null, Replacer.ReplaceValue, {$($nonText -join ', ')}),`r`n" } else { "    Blanks = Promoted,`r`n" }
    return @"
// Generated by Build-PassressSystem.ps1 - loads $Table produced by the PASSRESS engine. Do not edit; the CSV is rebuilt on every controlled refresh.
let
    Source = Csv.Document(File.Contents(pRootFolder & "\$folder\outputs\$Table.csv"), [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
    Promoted = Table.PromoteHeaders(Source, [PromoteAllScalars = true]),
$blankStep    Typed = Table.TransformColumnTypes(Blanks, {$types}, "en-US")
in
    Typed
"@
}

function New-PassressUpstreamQueryFormula {
    # Reads LOG_REFRESH from the SAVED upstream workbook (Excel.Workbook(File.Contents(...))) for freshness display.
    param([Parameter(Mandatory)][string]$UpstreamStage)
    $file = (Get-PassressSchema).workbooks.$UpstreamStage.file
    return @"
// Freshness of the upstream workbook $UpstreamStage, read from its last SAVED version.
let
    Source = Excel.Workbook(File.Contents(pRootFolder & "\$file"), true),
    Log = Source{[Item = "LOG_REFRESH", Kind = "Table"]}[Data],
    Typed = Table.TransformColumnTypes(Log, {{"RunId", type text}, {"Stage", type text}, {"Status", type text}, {"EndedAt", type datetime}}, "en-US"),
    Last = Table.LastN(Typed, 1),
    Out = Table.SelectColumns(Last, {"RunId", "Stage", "Status", "EndedAt"})
in
    Out
"@
}

function Set-PassressRootParameter {
    param([Parameter(Mandatory)]$Workbook, [Parameter(Mandatory)][string]$RootFolder)
    $formula = '"' + ($RootFolder -replace '"', '""') + '" meta [IsParameterQuery = true, Type = "Text", IsParameterQueryRequired = true]'
    $q = $null; foreach ($x in @($Workbook.Queries)) { if ($x.Name -eq 'pRootFolder') { $q = $x } }
    if ($q) { $q.Formula = $formula } else { [void]$Workbook.Queries.Add('pRootFolder', $formula, 'Root folder of the PASSRESS system (change with Set-PassressRootFolder.ps1)') }
}

function Add-PassressQueryTable {
    # Adds a Power Query query and loads it to a new worksheet table (connection-backed ListObject).
    param([Parameter(Mandatory)]$Workbook, [Parameter(Mandatory)]$Worksheet, [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Formula, [string]$Anchor = 'A4', [int]$HeaderColor = $script:Brand.Espresso)
    foreach ($x in @($Workbook.Queries)) { if ($x.Name -eq $Name) { $x.Delete() } }
    [void]$Workbook.Queries.Add($Name, $Formula)
    $conn = "OLEDB;Provider=Microsoft.Mashup.OleDb.1;Data Source=`$Workbook`$;Location=$Name;Extended Properties=`"`""
    $lo = $Worksheet.ListObjects.Add(0, $conn, $true, 1, $Worksheet.Range($Anchor))
    $qt = $lo.QueryTable
    $qt.CommandType = 2; $qt.CommandText = "SELECT * FROM [$Name]"; $qt.BackgroundQuery = $false; $qt.RefreshStyle = 1; $qt.AdjustColumnWidth = $true; $qt.PreserveColumnInfo = $true
    $qt.Refresh($false) | Out-Null
    $lo.Name = $Name; $lo.TableStyle = 'TableStyleLight1'
    try { $lo.HeaderRowRange.Interior.Color = (ConvertTo-ExcelColor $HeaderColor); $lo.HeaderRowRange.Font.Color = (ConvertTo-ExcelColor $script:Brand.White); $lo.HeaderRowRange.Font.Bold = $true } catch { }
    return $lo
}

function Add-PassressInputTable {
    param([Parameter(Mandatory)]$Worksheet, [Parameter(Mandatory)]$TableSchema, [object[]]$SeedRows = @(), [hashtable]$Lists = @{}, [string]$ListSeparator = ',', [string]$Anchor = 'A4')
    $cols = @($TableSchema.Columns); $nc = $cols.Count
    $start = $Worksheet.Range($Anchor); $r0 = $start.Row; $c0 = $start.Column
    for ($i = 0; $i -lt $nc; $i++) { $Worksheet.Cells.Item($r0, $c0 + $i).Value2 = $cols[$i].Name }
    $seed = @($SeedRows | Where-Object { $null -ne $_ }); $nRows = [math]::Max(1, $seed.Count)
    for ($r = 0; $r -lt $seed.Count; $r++) {
        for ($i = 0; $i -lt $nc; $i++) {
            $v = Get-RowValue2 $seed[$r] $cols[$i].Name
            if ($null -eq $v) { continue }
            $cell = $Worksheet.Cells.Item($r0 + 1 + $r, $c0 + $i)
            if ($v -is [datetime]) { $cell.Value2 = $v.ToOADate() } elseif ($v -is [bool]) { $cell.Value2 = $v } else { $cell.Value2 = $v }
        }
    }
    $rng = $Worksheet.Range($Worksheet.Cells.Item($r0, $c0), $Worksheet.Cells.Item($r0 + $nRows, $c0 + $nc - 1))
    $lo = $Worksheet.ListObjects.Add(1, $rng, [System.Reflection.Missing]::Value, 1)
    $lo.Name = $TableSchema.Name; $lo.TableStyle = 'TableStyleLight1'
    $lo.HeaderRowRange.Interior.Color = (ConvertTo-ExcelColor $script:Brand.Olive); $lo.HeaderRowRange.Font.Color = (ConvertTo-ExcelColor $script:Brand.White); $lo.HeaderRowRange.Font.Bold = $true
    $lo.DataBodyRange.Interior.Color = (ConvertTo-ExcelColor $script:Brand.Input)
    for ($i = 0; $i -lt $nc; $i++) {
        $col = $lo.ListColumns.Item($i + 1); $body = $col.DataBodyRange; $t = $cols[$i].Type
        switch ($t) { 'number' { $body.NumberFormat = '#,##0.00' } 'int' { $body.NumberFormat = '0' } 'date' { $body.NumberFormat = 'yyyy-mm-dd' } 'datetime' { $body.NumberFormat = 'yyyy-mm-dd hh:mm' } default { $body.NumberFormat = '@' } }
        try { $lo.HeaderRowRange.Cells.Item(1, $i + 1).AddComment($cols[$i].Description) | Out-Null } catch { }
        if ($Lists.ContainsKey($cols[$i].Name)) {
            $body.Validation.Delete()
            $body.Validation.Add(3, 1, 1, (($Lists[$cols[$i].Name]) -join $ListSeparator))
            $body.Validation.IgnoreBlank = $true; $body.Validation.ErrorTitle = $cols[$i].Name; $body.Validation.ErrorMessage = 'Choose a value from the list.'
        } elseif ($t -eq 'date') {
            # serial number avoids locale-dependent date text (43831 = 2020-01-01; operator 7 = xlGreaterEqual)
            $body.Validation.Delete(); $body.Validation.Add(4, 1, 7, '43831'); $body.Validation.ErrorMessage = 'Enter a valid date on/after 2020-01-01 (yyyy-mm-dd).'
        } elseif ($t -eq 'number' -or $t -eq 'int') {
            $body.Validation.Delete(); $body.Validation.Add(2, 1, 1, '-999999999', '999999999'); $body.Validation.ErrorMessage = 'Enter a number.'
        }
    }
    $Worksheet.Range($Worksheet.Cells.Item($r0, $c0), $Worksheet.Cells.Item($r0, $c0 + $nc - 1)).EntireColumn.AutoFit() | Out-Null
    return $lo
}

function Get-RowValue2 { param($Row, [string]$Name) if ($Row -is [System.Collections.IDictionary]) { if ($Row.Contains($Name)) { return $Row[$Name] } return $null }; $p = $Row.PSObject.Properties[$Name]; if ($p) { return $p.Value } return $null }

function Set-PassressSheetHeader {
    param([Parameter(Mandatory)]$Worksheet, [Parameter(Mandatory)][string]$Title, [string]$Subtitle, [ValidateSet('INPUT', 'REPORT', 'HOME', 'CONTROL')][string]$Kind = 'REPORT')
    $Worksheet.Cells.Item(1, 1).Value2 = $Title; $Worksheet.Cells.Item(1, 1).Font.Size = 16; $Worksheet.Cells.Item(1, 1).Font.Bold = $true
    $Worksheet.Cells.Item(1, 1).Font.Color = (ConvertTo-ExcelColor $script:Brand.Olive)
    if ($Subtitle) { $Worksheet.Cells.Item(2, 1).Value2 = $Subtitle; $Worksheet.Cells.Item(2, 1).Font.Color = (ConvertTo-ExcelColor $script:Brand.Espresso); $Worksheet.Cells.Item(2, 1).Font.Italic = $true }
    $label = switch ($Kind) { 'INPUT' { 'INPUT SHEET - type here' } 'REPORT' { 'REPORT - read only, rebuilt on refresh' } 'CONTROL' { 'CONTROLS - checks must be 0 / OK' } default { '' } }
    if ($label) { $Worksheet.Cells.Item(1, 8).Value2 = $label; $Worksheet.Cells.Item(1, 8).Font.Bold = $true; $Worksheet.Cells.Item(1, 8).Font.Color = (ConvertTo-ExcelColor $(if ($Kind -eq 'INPUT') { $script:Brand.Olive } else { $script:Brand.Espresso })) }
    $Worksheet.Tab.Color = (ConvertTo-ExcelColor $(if ($Kind -eq 'INPUT') { $script:Brand.Olive } elseif ($Kind -eq 'HOME') { $script:Brand.Espresso } else { $script:Brand.Border }))
    $Worksheet.Cells.Font.Name = 'Calibri'
}

function Get-PassressBrand { return $script:Brand }

Export-ModuleMember -Function New-PassressExcel, Close-PassressExcel, Test-PassressFileUnlocked, Open-PassressWorkbook, Get-PassressListObject, Read-PassressListObjectRows, Export-PassressInputTables, Invoke-PassressWorkbookRefresh, Get-PassressListObjectRowCount, New-PassressCsvQueryFormula, New-PassressUpstreamQueryFormula, Set-PassressRootParameter, Add-PassressQueryTable, Add-PassressInputTable, Set-PassressSheetHeader, ConvertTo-ExcelColor, Get-PassressBrand
