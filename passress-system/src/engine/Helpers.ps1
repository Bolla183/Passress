# Engine helpers (dot-sourced by Passress.Engine.psm1). PowerShell 5.1 compatible.

function Get-JsonValue {
    # Safe nested property access for parsed JSON (never throws under StrictMode).
    param($Object, [Parameter(Mandatory)][string]$Path)
    $cur = $Object
    foreach ($part in $Path.Split('.')) {
        if ($null -eq $cur) { return $null }
        if ($cur -is [System.Collections.IDictionary]) { if ($cur.Contains($part)) { $cur = $cur[$part] } else { return $null } ; continue }
        $p = $cur.PSObject.Properties[$part]
        if ($null -eq $p) { return $null }
        $cur = $p.Value
    }
    return $cur
}

function Get-ConnectionNodes {
    # Accepts a GraphQL connection ({nodes:[]} or {edges:[{node}]}) or a plain list.
    param($Connection)
    if ($null -eq $Connection) { return , @() }
    if ($Connection -is [System.Array]) { return , @($Connection) }
    $nodes = Get-JsonValue $Connection 'nodes'
    if ($null -ne $nodes) { return , @($nodes) }
    $edges = Get-JsonValue $Connection 'edges'
    if ($null -ne $edges) { return , @(@($edges) | ForEach-Object { Get-JsonValue $_ 'node' }) }
    return , @()
}

function Get-MoneyValue { param($Object, [string]$Path) return (Get-Money (Get-JsonValue $Object ($Path + '.shopMoney.amount'))) }

function Get-SumOf {
    param([AllowEmptyCollection()][object[]]$Items, [Parameter(Mandatory)][string]$Property)
    $s = 0.0
    foreach ($i in @($Items)) {
        if ($null -eq $i) { continue }
        $v = if ($i -is [System.Collections.IDictionary]) { $i[$Property] } else { $i.$Property }
        if ($null -ne $v -and "$v" -ne '') { $s += [double]$v }
    }
    return (Get-RoundedMoney $s)
}

function Get-RowValue { param($Row, [string]$Name) if ($Row -is [System.Collections.IDictionary]) { return $Row[$Name] } $p = $Row.PSObject.Properties[$Name]; if ($p) { return $p.Value } return $null }

function Add-ToMap { param([hashtable]$Map, [string]$Key, [double]$Value) if (-not $Map.ContainsKey($Key)) { $Map[$Key] = 0.0 }; $Map[$Key] = [double]$Map[$Key] + $Value }

function Get-MapValue { param([hashtable]$Map, [string]$Key, $Default = 0) if ($null -ne $Key -and $Map.ContainsKey($Key)) { return $Map[$Key] } return $Default }

function Test-MoneyEqual { param([double]$A, [double]$B) return ([math]::Abs($A - $B) -lt 0.005) }

function New-List { return , (New-Object System.Collections.Generic.List[object]) }

function Get-MonthRange {
    # All months from first to last inclusive (yyyy-MM strings).
    param([AllowEmptyCollection()][string[]]$Months)
    $valid = @($Months | Where-Object { $_ } | Sort-Object -Unique)
    if ($valid.Count -eq 0) { return , @() }
    $inv = [System.Globalization.CultureInfo]::InvariantCulture
    $start = [datetime]::ParseExact($valid[0] + '-01', 'yyyy-MM-dd', $inv)
    $end = [datetime]::ParseExact($valid[$valid.Count - 1] + '-01', 'yyyy-MM-dd', $inv)
    $out = @(); $m = $start
    while ($m -le $end) { $out += $m.ToString('yyyy-MM', $inv); $m = $m.AddMonths(1) }
    return , $out
}

function ConvertTo-PassressRowSet {
    # Every value becomes a real array without $null members (guards against PowerShell's one-element / empty-array unrolling).
    param([hashtable]$Map, [string[]]$Keys = @())
    $out = @{}
    foreach ($k in (@($Map.Keys) + $Keys)) { if ($null -eq $k) { continue }; $v = $Map[$k]; $out[$k] = @($v | Where-Object { $null -ne $_ }) }
    return $out
}
