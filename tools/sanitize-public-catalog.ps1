param(
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$privateRoot = Join-Path $ProjectRoot 'local-data\private-catalog'
New-Item -ItemType Directory -Path $privateRoot -Force | Out-Null

function Save-TextAtomic([string]$Path, [string]$Value) {
    $pending = "$Path.pending"
    [IO.File]::WriteAllText($pending, $Value, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $pending -Destination $Path -Force
}

foreach ($name in @('roster.json', 'ranch-dex.json', 'supplement.json')) {
    $source = Join-Path $ProjectRoot $name
    $backup = Join-Path $privateRoot $name
    if (-not (Test-Path -LiteralPath $backup)) {
        Copy-Item -LiteralPath $source -Destination $backup
    }
}

$rosterPath = Join-Path $ProjectRoot 'roster.json'
$rosterText = Get-Content -LiteralPath $rosterPath -Raw
$rosterText = [regex]::Replace($rosterText, '(?m)^\s*"slot"\s*:\s*"[^"]*",\r?\n', '')
$rosterText = [regex]::Replace($rosterText, '(?m)^\s*"id"\s*:\s*"[^"]*",\r?\n', '')
Save-TextAtomic $rosterPath $rosterText

$dexPath = Join-Path $ProjectRoot 'ranch-dex.json'
$dexText = Get-Content -LiteralPath $dexPath -Raw
$dexText = [regex]::Replace($dexText, '"volume"\s*:\s*\d+\s*,\s*"box"\s*:\s*\d+\s*,\s*"slot"\s*:\s*\d+\s*,\s*', '')
Save-TextAtomic $dexPath $dexText

$roster = @(Get-Content -LiteralPath $rosterPath -Raw | ConvertFrom-Json)
$dex = @(Get-Content -LiteralPath $dexPath -Raw | ConvertFrom-Json)

$rosterLeaked = @($roster | Where-Object {
    $_.PSObject.Properties.Name -contains 'slot' -or $_.PSObject.Properties.Name -contains 'id'
}).Count
$dexLeaked = @($dex | ForEach-Object { @($_.sources) } | Where-Object {
    $_.PSObject.Properties.Name -contains 'volume' -or
    $_.PSObject.Properties.Name -contains 'box' -or
    $_.PSObject.Properties.Name -contains 'slot'
}).Count

if ($rosterLeaked -ne 0 -or $dexLeaked -ne 0) {
    throw "Catalog sanitization failed: roster=$rosterLeaked dex=$dexLeaked"
}

Write-Output "Sanitized $($roster.Count) roster records and $($dex.Count) catalog records."
Write-Output "Private provenance backup: $privateRoot"
