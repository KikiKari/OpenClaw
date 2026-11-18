#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "5aec235545c17339c15cc7b20b9f47670bb137257db805786ad605fb891d5a5c", "source_sha256": "502dcda47466a4ab74da59badbe4b12c4782ed031c43d5038f8bd8534373cd35", "target_language": "powershell"}
# model_usage.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/model-usage/scripts/model_usage.py
# auch in: OpenClaw@gateway2:skills/model-usage/scripts/model_usage.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Summarize CodexBar local cost usage by model.

.DESCRIPTION
Defaults to current model (most recent daily entry), or list all models.
#>

using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Text
using namespace System.Text.Json
using namespace System.Text.Json.Serialization

param(
    [ValidateSet("codex", "claude")]
    [string]$Provider = "codex",
    
    [ValidateSet("current", "all")]
    [string]$Mode = "current",
    
    [string]$Model,
    
    [string]$Input,
    
    [int]$Days,
    
    [ValidateSet("text", "json")]
    [string]$Format = "text",
    
    [switch]$Pretty
)

class ModelCost {
    [string]$Model
    [double]$Cost
    
    ModelCost([string]$model, [double]$cost) {
        $this.Model = $model
        $this.Cost = $cost
    }
}

function Write-ErrorMsg {
    param([string]$Msg)
    Write-Host $Msg -ForegroundColor Red
}

function Invoke-CodexBarCost {
    param([string]$Provider)
    
    try {
        $result = & codexbar cost --format json --provider $Provider 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "codexbar cost failed (exit $LASTEXITCODE)."
        }
        return $result
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        throw "codexbar not found on PATH. Install CodexBar CLI first."
    }
}

function Get-Payload {
    param(
        [string]$InputPath,
        [string]$Provider
    )
    
    if ($InputPath) {
        if ($InputPath -eq "-") {
            $raw = [Console]::In.ReadToEnd()
        }
        else {
            $raw = Get-Content -Path $InputPath -Raw -Encoding UTF8
        }
        $data = ConvertFrom-Json $raw -AsHashtable
    }
    else {
        $output = Invoke-CodexBarCost -Provider $Provider
        $data = ConvertFrom-Json $output -AsHashtable
    }
    
    if ($data -is [hashtable]) {
        return $data
    }
    
    if ($data -is [array]) {
        foreach ($entry in $data) {
            if ($entry -is [hashtable] -and $entry.provider -eq $Provider) {
                return $entry
            }
        }
        throw "Provider '$Provider' not found in codexbar payload."
    }
    
    throw "Unsupported JSON input format."
}

function Get-DailyEntries {
    param([hashtable]$Payload)
    
    $daily = $Payload.daily
    if (-not $daily) { return @() }
    if ($daily -isnot [array]) { return @() }
    return @($daily | Where-Object { $_ -is [hashtable] })
}

function Parse-Date {
    param([string]$Value)
    
    try {
        return [datetime]::ParseExact($Value, "yyyy-MM-dd", $null).Date
    }
    catch {
        return $null
    }
}

function Filter-ByDays {
    param(
        [array]$Entries,
        [int]$Days
    )
    
    if (-not $Days) { return $Entries }
    $cutoff = [datetime]::Today.AddDays(-($Days - 1))
    $filtered = [List[hashtable]]::new()
    
    foreach ($entry in $Entries) {
        $day = $entry.date
        if (-not $day -or $day -isnot [string]) { continue }
        $parsed = Parse-Date $day
        if ($parsed -and $parsed -ge $cutoff) {
            $filtered.Add($entry)
        }
    }
    return $filtered.ToArray()
}

function Aggregate-Costs {
    param([array]$Entries)
    
    $totals = @{}
    
    foreach ($entry in $Entries) {
        $breakdowns = $entry.modelBreakdowns
        if (-not $breakdowns -or $breakdowns -isnot [array]) { continue }
        
        foreach ($item in $breakdowns) {
            if ($item -isnot [hashtable]) { continue }
            $model = $item.modelName
            $cost = $item.cost
            if (-not $model -or $model -isnot [string]) { continue }
            if ($cost -isnot [double] -and $cost -isnot [int]) { continue }
            
            $current = if ($totals.ContainsKey($model)) { $totals[$model] } else { 0.0 }
            $totals[$model] = $current + [double]$cost
        }
    }
    return $totals
}

function Get-CurrentModel {
    param([array]$Entries)
    
    if (-not $Entries) { return $null, $null }
    
    $sortedEntries = $Entries | Sort-Object { $_.date ?? "" }
    
    foreach ($entry in [array]::Reverse($sortedEntries)) {
        $breakdowns = $entry.modelBreakdowns
        if ($breakdowns -is [array] -and $breakdowns.Count -gt 0) {
            $scored = [List[ModelCost]]::new()
            
            foreach ($item in $breakdowns) {
                if ($item -isnot [hashtable]) { continue }
                $model = $item.modelName
                $cost = $item.cost
                if ($model -is [string] -and ($cost -is [double] -or $cost -is [int])) {
                    $scored.Add([ModelCost]::new($model, [double]$cost))
                }
            }
            
            if ($scored.Count -gt 0) {
                $sorted = $scored | Sort-Object Cost -Descending
                $date = if ($entry.date -is [string]) { $entry.date } else { $null }
                return $sorted[0].Model, $date
            }
        }
        
        $modelsUsed = $entry.modelsUsed
        if ($modelsUsed -is [array] -and $modelsUsed.Count -gt 0) {
            $last = $modelsUsed[-1]
            if ($last -is [string]) {
                $date = if ($entry.date -is [string]) { $entry.date } else { $null }
                return $last, $date
            }
        }
    }
    
    return $null, $null
}

function Format-USD {
    param([object]$Value)
    
    if ($null -eq $Value) { return "—" }
    return "${$Value:0.00}" -replace '\B(?=(\d{3})+(?!\d))', ','
}

function Get-LatestDayCost {
    param(
        [array]$Entries,
        [string]$Model
    )
    
    if (-not $Entries) { return $null, $null }
    
    $sortedEntries = $Entries | Sort-Object { $_.date ?? "" }
    
    foreach ($entry in [array]::Reverse($sortedEntries)) {
        $breakdowns = $entry.modelBreakdowns
        if ($breakdowns -isnot [array]) { continue }
        
        foreach ($item in $breakdowns) {
            if ($item -isnot [hashtable]) { continue }
            if ($item.modelName -eq $Model) {
                $cost = if ($item.cost -is [double] -or $item.cost -is [int]) { [double]$item.cost } else { $null }
                $day = if ($entry.date -is [string]) { $entry.date } else { $null }
                return $day, $cost
            }
        }
    }
    
    return $null, $null
}

function Render-TextCurrent {
    param(
        [string]$Provider,
        [string]$Model,
        [string]$LatestDate,
        [double]$TotalCost,
        [double]$LatestCost,
        [string]$LatestCostDate,
        [int]$EntryCount
    )
    
    $lines = @(
        "Provider: $Provider",
        "Current model: $Model"
    )
    
    if ($LatestDate) {
        $lines += "Latest model date: $LatestDate"
    }
    
    $lines += "Total cost (rows): $(Format-USD $TotalCost)"
    
    if ($LatestCostDate) {
        $lines += "Latest day cost: $(Format-USD $LatestCost) ($LatestCostDate)"
    }
    
    $lines += "Daily rows: $EntryCount"
    return $lines -join "`n"
}

function Render-TextAll {
    param(
        [string]$Provider,
        [hashtable]$Totals
    )
    
    $lines = @(
        "Provider: $Provider",
        "Models:"
    )
    
    $sorted = $Totals.GetEnumerator() | Sort-Object Value -Descending
    foreach ($item in $sorted) {
        $lines += "- $($item.Key): $(Format-USD $item.Value)"
    }
    
    return $lines -join "`n"
}

function Build-JsonCurrent {
    param(
        [string]$Provider,
        [string]$Model,
        [string]$LatestDate,
        [double]$TotalCost,
        [double]$LatestCost,
        [string]$LatestCostDate,
        [int]$EntryCount
    )
    
    return @{
        provider = $Provider
        mode = "current"
        model = $Model
        latestModelDate = $LatestDate
        totalCostUSD = $TotalCost
        latestDayCostUSD = $LatestCost
        latestDayCostDate = $LatestCostDate
        dailyRowCount = $EntryCount
    }
}

function Build-JsonAll {
    param(
        [string]$Provider,
        [hashtable]$Totals
    )
    
    $models = $Totals.GetEnumerator() | 
        Sort-Object Value -Descending | 
        ForEach-Object {
            @{
                model = $_.Key
                totalCostUSD = $_.Value
            }
        }
    
    return @{
        provider = $Provider
        mode = "all"
        models = $models
    }
}

try {
    $payload = Get-Payload -InputPath $Input -Provider $Provider
}
catch {
    Write-ErrorMsg $_.Exception.Message
    exit 1
}

$entries = Get-DailyEntries -Payload $payload
$entries = Filter-ByDays -Entries $entries -Days $Days

if ($Mode -eq "current") {
    $model = $Model
    $latestDate = $null
    
    if (-not $model) {
        $model, $latestDate = Get-CurrentModel -Entries $entries
    }
    
    if (-not $model) {
        Write-ErrorMsg "No model data found in codexbar cost payload."
        exit 2
    }
    
    $totals = Aggregate-Costs -Entries $entries
    $totalCost = if ($totals.ContainsKey($model)) { $totals[$model] } else { $null }
    $latestCostDate, $latestCost = Get-LatestDayCost -Entries $entries -Model $model
    
    if ($Format -eq "json") {
        $payloadOut = Build-JsonCurrent -Provider $Provider -Model $model -LatestDate $latestDate `
            -TotalCost $totalCost -LatestCost $latestCost -LatestCostDate $latestCostDate `
            -EntryCount $entries.Count
        
        $jsonOptions = [JsonSerializerOptions]::new()
        $jsonOptions.WriteIndented = $Pretty
        if ($Pretty) {
            $jsonOptions.Encoder = [JavaScriptEncoder]::UnsafeRelaxedJsonEscaping
        }
        
        Write-Host ([JsonSerializer]::Serialize($payloadOut, $jsonOptions))
    }
    else {
        Write-Host (Render-TextCurrent -Provider $Provider -Model $model -LatestDate $latestDate `
            -TotalCost $totalCost -LatestCost $latestCost -LatestCostDate $latestCostDate `
            -EntryCount $entries.Count)
    }
    exit 0
}

$totals = Aggregate-Costs -Entries $entries
if ($totals.Count -eq 0) {
    Write-ErrorMsg "No model breakdowns found in codexbar cost payload."
    exit 2
}

if ($Format -eq "json") {
    $payloadOut = Build-JsonAll -Provider $Provider -Totals $totals
    
    $jsonOptions = [JsonSerializerOptions]::new()
    $jsonOptions.WriteIndented = $Pretty
    if ($Pretty) {
        $jsonOptions.Encoder = [JavaScriptEncoder]::UnsafeRelaxedJsonEscaping
    }
    
    Write-Host ([JsonSerializer]::Serialize($payloadOut, $jsonOptions))
}
else {
    Write-Host (Render-TextAll -Provider $Provider -Totals $totals)
}
exit 0
