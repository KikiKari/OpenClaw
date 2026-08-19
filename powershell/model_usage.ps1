#!/usr/bin/env pwsh
# model_usage.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/model-usage/scripts/model_usage.py
# auch in: OpenClaw@gateway2:skills/model-usage/scripts/model_usage.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Summarize CodexBar local cost usage by model.

.DESCRIPTION
Defaults to current model (most recent daily entry), or list all models.
#>

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

function Write-ErrorLine {
    param([string]$Message)
    Write-Error $Message
}

function Invoke-CodexbarCost {
    param([string]$ProviderParam)

    $cmd = @("codexbar", "cost", "--format", "json", "--provider", $ProviderParam)
    try {
        $output = & $cmd 2>$null | Out-String
        return $output
    }
    catch {
        if ($_.Exception.Message -like "*is not recognized*") {
            throw "codexbar not found on PATH. Install CodexBar CLI first."
        }
        else {
            throw "codexbar cost failed (exit $LASTEXITCODE)."
        }
    }
}

function Load-Payload {
    param(
        [string]$InputPath,
        [string]$ProviderParam
    )

    if ($InputPath) {
        if ($InputPath -eq "-") {
            $raw = $input | Out-String
        }
        else {
            $raw = Get-Content -Path $InputPath -Raw -Encoding UTF8
        }
        $data = $raw | ConvertFrom-Json
    }
    else {
        $output = Invoke-CodexbarCost -ProviderParam $ProviderParam
        $data = $output | ConvertFrom-Json
    }

    if ($data -is [PSCustomObject]) {
        return $data
    }

    if ($data -is [array]) {
        foreach ($entry in $data) {
            if ($entry -is [PSCustomObject] -and $entry.provider -eq $ProviderParam) {
                return $entry
            }
        }
        throw "Provider '$ProviderParam' not found in codexbar payload."
    }

    throw "Unsupported JSON input format."
}

class ModelCost {
    [string]$Model
    [float]$Cost

    ModelCost([string]$model, [float]$cost) {
        $this.Model = $model
        $this.Cost = $cost
    }
}

function Parse-DailyEntries {
    param([PSCustomObject]$Payload)

    $daily = $Payload.daily
    if (-not $daily) {
        return @()
    }
    if ($daily -isnot [array]) {
        return @()
    }
    
    $result = @()
    foreach ($entry in $daily) {
        if ($entry -is [PSCustomObject]) {
            $result += $entry
        }
    }
    return $result
}

function Parse-Date {
    param([string]$Value)

    try {
        return [DateTime]::ParseExact($Value, "yyyy-MM-dd", $null).Date
    }
    catch {
        return $null
    }
}

function Filter-ByDays {
    param(
        [array]$Entries,
        [int]$DaysParam
    )

    if (-not $DaysParam) {
        return $Entries
    }
    
    $cutoff = (Get-Date).Date.AddDays(-($DaysParam - 1))
    $filtered = @()
    
    foreach ($entry in $Entries) {
        $day = $entry.date
        if ($day -is [string]) {
            $parsed = Parse-Date -Value $day
            if ($parsed -and $parsed -ge $cutoff) {
                $filtered += $entry
            }
        }
    }
    return $filtered
}

function Aggregate-Costs {
    param([array]$Entries)

    $totals = @{}
    foreach ($entry in $Entries) {
        $breakdowns = $entry.modelBreakdowns
        if (-not $breakdowns) {
            continue
        }
        if ($breakdowns -isnot [array]) {
            continue
        }
        foreach ($item in $breakdowns) {
            if ($item -isnot [PSCustomObject]) {
                continue
            }
            $model = $item.modelName
            $cost = $item.cost
            if ($model -is [string] -and ($cost -is [int] -or $cost -is [double])) {
                if (-not $totals.ContainsKey($model)) {
                    $totals[$model] = 0.0
                }
                $totals[$model] += [double]$cost
            }
        }
    }
    return $totals
}

function Pick-CurrentModel {
    param([array]$Entries)

    if (-not $Entries) {
        return @{ Model = $null; Date = $null }
    }
    
    $sortedEntries = $Entries | Sort-Object { $_.date }
    
    for ($i = $sortedEntries.Count - 1; $i -ge 0; $i--) {
        $entry = $sortedEntries[$i]
        $breakdowns = $entry.modelBreakdowns
        if ($breakdowns -is [array] -and $breakdowns.Count -gt 0) {
            $scored = @()
            foreach ($item in $breakdowns) {
                if ($item -isnot [PSCustomObject]) {
                    continue
                }
                $model = $item.modelName
                $cost = $item.cost
                if ($model -is [string] -and ($cost -is [int] -or $cost -is [double])) {
                    $scored += [ModelCost]::new($model, [double]$cost)
                }
            }
            if ($scored.Count -gt 0) {
                $scored = $scored | Sort-Object Cost -Descending
                return @{
                    Model = $scored[0].Model
                    Date = if ($entry.date -is [string]) { $entry.date } else { $null }
                }
            }
        }
        
        $modelsUsed = $entry.modelsUsed
        if ($modelsUsed -is [array] -and $modelsUsed.Count -gt 0) {
            $last = $modelsUsed[-1]
            if ($last -is [string]) {
                return @{
                    Model = $last
                    Date = if ($entry.date -is [string]) { $entry.date } else { $null }
                }
            }
        }
    }
    return @{ Model = $null; Date = $null }
}

function Format-USD {
    param([Nullable[float]]$Value)

    if ($null -eq $Value) {
        return "—"
    }
    return "$('{0:N2}' -f $Value)"
}

function Get-LatestDayCost {
    param(
        [array]$Entries,
        [string]$ModelParam
    )

    if (-not $Entries) {
        return @{ Date = $null; Cost = $null }
    }
    
    $sortedEntries = $Entries | Sort-Object { $_.date }
    
    for ($i = $sortedEntries.Count - 1; $i -ge 0; $i--) {
        $entry = $sortedEntries[$i]
        $breakdowns = $entry.modelBreakdowns
        if ($breakdowns -isnot [array]) {
            continue
        }
        foreach ($item in $breakdowns) {
            if ($item -isnot [PSCustomObject]) {
                continue
            }
            if ($item.modelName -eq $ModelParam) {
                $cost = if ($item.cost -is [int] -or $item.cost -is [double]) { [double]$item.cost } else { $null }
                $day = if ($entry.date -is [string]) { $entry.date } else { $null }
                return @{
                    Date = $day
                    Cost = $cost
                }
            }
        }
    }
    return @{ Date = $null; Cost = $null }
}

function Render-TextCurrent {
    param(
        [string]$ProviderParam,
        [string]$ModelParam,
        [string]$LatestDate,
        [Nullable[float]]$TotalCost,
        [Nullable[float]]$LatestCost,
        [string]$LatestCostDate,
        [int]$EntryCount
    )

    $lines = @(
        "Provider: $ProviderParam"
        "Current model: $ModelParam"
    )
    
    if ($LatestDate) {
        $lines += "Latest model date: $LatestDate"
    }
    
    $lines += "Total cost (rows): $(Format-USD -Value $TotalCost)"
    
    if ($LatestCostDate) {
        $lines += "Latest day cost: $(Format-USD -Value $LatestCost) ($LatestCostDate)"
    }
    
    $lines += "Daily rows: $EntryCount"
    
    return ($lines -join "`n")
}

function Render-TextAll {
    param(
        [string]$ProviderParam,
        [hashtable]$Totals
    )

    $lines = @(
        "Provider: $ProviderParam"
        "Models:"
    )
    
    $sortedItems = $Totals.GetEnumerator() | Sort-Object Value -Descending
    
    foreach ($item in $sortedItems) {
        $lines += "- $($item.Key): $(Format-USD -Value $item.Value)"
    }
    
    return ($lines -join "`n")
}

function Build-JsonCurrent {
    param(
        [string]$ProviderParam,
        [string]$ModelParam,
        [string]$LatestDate,
        [Nullable[float]]$TotalCost,
        [Nullable[float]]$LatestCost,
        [string]$LatestCostDate,
        [int]$EntryCount
    )

    return @{
        provider = $ProviderParam
        mode = "current"
        model = $ModelParam
        latestModelDate = $LatestDate
        totalCostUSD = $TotalCost
        latestDayCostUSD = $LatestCost
        latestDayCostDate = $LatestCostDate
        dailyRowCount = $EntryCount
    }
}

function Build-JsonAll {
    param(
        [string]$ProviderParam,
        [hashtable]$Totals
    )

    $modelsArray = @()
    $sortedItems = $Totals.GetEnumerator() | Sort-Object Value -Descending
    
    foreach ($item in $sortedItems) {
        $modelsArray += @{
            model = $item.Key
            totalCostUSD = $item.Value
        }
    }
    
    return @{
        provider = $ProviderParam
        mode = "all"
        models = $modelsArray
    }
}

try {
    $payload = Load-Payload -InputPath $Input -ProviderParam $Provider
}
catch {
    Write-ErrorLine -Message $_.Exception.Message
    exit 1
}

$entries = Parse-DailyEntries -Payload $payload
$entries = Filter-ByDays -Entries $entries -DaysParam $Days

if ($Mode -eq "current") {
    $model = $Model
    $latestDate = $null
    
    if (-not $model) {
        $currentResult = Pick-CurrentModel -Entries $entries
        $model = $currentResult.Model
        $latestDate = $currentResult.Date
    }
    
    if (-not $model) {
        Write-ErrorLine -Message "No model data found in codexbar cost payload."
        exit 2
    }
    
    $totals = Aggregate-Costs -Entries $entries
    $totalCost = if ($totals.ContainsKey($model)) { $totals[$model] } else { $null }
    
    $latestCostResult = Get-LatestDayCost -Entries $entries -ModelParam $model
    $latestCostDate = $latestCostResult.Date
    $latestCost = $latestCostResult.Cost
    
    if ($Format -eq "json") {
        $payloadOut = Build-JsonCurrent -ProviderParam $Provider -ModelParam $model -LatestDate $latestDate -TotalCost $totalCost -LatestCost $latestCost -LatestCostDate $latestCostDate -EntryCount $entries.Count
        
        if ($Pretty) {
            $jsonString = $payloadOut | ConvertTo-Json -Depth 10 -EnumsAsStrings
            $jsonString
        }
        else {
            $payloadOut | ConvertTo-Json -Depth 10 -EnumsAsStrings -Compress
        }
    }
    else {
        Render-TextCurrent -ProviderParam $Provider -ModelParam $model -LatestDate $latestDate -TotalCost $totalCost -LatestCost $latestCost -LatestCostDate $latestCostDate -EntryCount $entries.Count
    }
    exit 0
}

$totals = Aggregate-Costs -Entries $entries
if (-not $totals.Keys) {
    Write-ErrorLine -Message "No model breakdowns found in codexbar cost payload."
    exit 2
}

if ($Format -eq "json") {
    $payloadOut = Build-JsonAll -ProviderParam $Provider -Totals $totals
    
    if ($Pretty) {
        $jsonString = $payloadOut | ConvertTo-Json -Depth 10 -EnumsAsStrings
        $jsonString
    }
    else {
        $payloadOut | ConvertTo-Json -Depth 10 -EnumsAsStrings -Compress
    }
}
else {
    Render-TextAll -ProviderParam $Provider -Totals $totals
}
exit 0
