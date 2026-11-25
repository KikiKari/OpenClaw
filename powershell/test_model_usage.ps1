#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "126271be7ac47af7402ae5674d4e3b861d7735da1a68b5941eb37629f9e9bfab", "source_sha256": "95f62a3e3f38308dd9be80e09ec85e4a14455ab95457febb8f915c0f54685141", "target_language": "powershell"}
# test_model_usage.py — portiert nach powershell
# Quelle: python, workspace@local:skills/github-clones/openclaw/skills/model-usage/scripts/test_model_usage.py
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Tests for model_usage helpers.
#>

using namespace System
using namespace System.Collections.Generic
using namespace System.Management.Automation

function Test-PositiveIntAcceptsValidNumbers {
    [CmdletBinding()]
    param()

    # Test that positive_int accepts valid numbers
    $result1 = PositiveInt -Value "1"
    $result2 = PositiveInt -Value "7"

    if ($result1 -ne 1) {
        throw "Expected 1, but got $result1"
    }

    if ($result2 -ne 7) {
        throw "Expected 7, but got $result2"
    }

    Write-Host "Test-PositiveIntAcceptsValidNumbers passed"
}

function Test-PositiveIntRejectsZeroAndNegative {
    [CmdletBinding()]
    param()

    # Test that positive_int rejects zero
    try {
        PositiveInt -Value "0"
        throw "Expected ArgumentTypeException for value '0'"
    } catch [System.Management.Automation.RuntimeException] {
        if (-not $_.Exception.Message.Contains("must be a positive integer")) {
            throw "Unexpected exception message: $($_.Exception.Message)"
        }
    }

    # Test that positive_int rejects negative numbers
    try {
        PositiveInt -Value "-3"
        throw "Expected ArgumentTypeException for value '-3'"
    } catch [System.Management.Automation.RuntimeException] {
        if (-not $_.Exception.Message.Contains("must be a positive integer")) {
            throw "Unexpected exception message: $($_.Exception.Message)"
        }
    }

    Write-Host "Test-PositiveIntRejectsZeroAndNegative passed"
}

function Test-FilterByDaysKeepsRecentEntries {
    [CmdletBinding()]
    param()

    $today = Get-Date
    $entries = @(
        @{
            date = ($today.AddDays(-5)).ToString("yyyy-MM-dd")
            modelBreakdowns = @()
        },
        @{
            date = ($today.AddDays(-1)).ToString("yyyy-MM-dd")
            modelBreakdowns = @()
        },
        @{
            date = $today.ToString("yyyy-MM-dd")
            modelBreakdowns = @()
        }
    )

    $filtered = FilterByDays -Entries $entries -Days 2

    if ($filtered.Count -ne 2) {
        throw "Expected 2 entries, but got $($filtered.Count)"
    }

    $expectedDate1 = ($today.AddDays(-1)).ToString("yyyy-MM-dd")
    $expectedDate2 = $today.ToString("yyyy-MM-dd")

    if ($filtered[0].date -ne $expectedDate1) {
        throw "Expected '$expectedDate1', but got '$($filtered[0].date)'"
    }

    if ($filtered[1].date -ne $expectedDate2) {
        throw "Expected '$expectedDate2', but got '$($filtered[1].date)'"
    }

    Write-Host "Test-FilterByDaysKeepsRecentEntries passed"
}

function PositiveInt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Value
    )

    try {
        $intValue = [int]$Value
        if ($intValue -le 0) {
            throw "Value must be a positive integer"
        }
        return $intValue
    } catch {
        throw [ArgumentException]::new("Value '$Value' must be a positive integer")
    }
}

function FilterByDays {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object[]]$Entries,
        
        [Parameter(Mandatory=$true)]
        [int]$Days
    )

    $cutoffDate = (Get-Date).AddDays(-$Days)
    $filteredEntries = @()

    foreach ($entry in $Entries) {
        $entryDate = [DateTime]::ParseExact($entry.date, "yyyy-MM-dd", $null)
        if ($entryDate -ge $cutoffDate) {
            $filteredEntries += $entry
        }
    }

    # Sort by date ascending
    $sortedEntries = $filteredEntries | Sort-Object { [DateTime]::ParseExact($_.date, "yyyy-MM-dd", $null) }
    
    return $sortedEntries
}

# Run tests
try {
    Test-PositiveIntAcceptsValidNumbers
    Test-PositiveIntRejectsZeroAndNegative
    Test-FilterByDaysKeepsRecentEntries
    Write-Host "All tests passed successfully!"
} catch {
    Write-Error "Test failed: $($_.Exception.Message)"
    exit 1
}
