#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "759b2c2ca67abbe4641a3a52683a21d8e15af8791fe0423b8cb0cf0730cb4396", "source_sha256": "40b902ee3739509c4b2ef72ed57b4d983e5b509f6e446d20ab14d630d9773322", "target_language": "powershell"}
# json_batch_processor.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_batch_processor.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_batch_processor.py
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Batch JSON Processor - Verarbeitet mehrere JSON-Dateien oder JSON-Lines (NDJSON).
#>

param(
    [Parameter(Mandatory=$true)]
    [string[]]$Inputs,

    [switch]$Jsonl,

    [switch]$Repair = $true,

    [int]$Workers = 4,

    [string]$Output,

    [switch]$Summary
)

# Import required modules
Import-Module Microsoft.PowerShell.Utility

# Global variables
$HAS_PYDANTIC = $false
$JSON_PROCESSOR_SCRIPT = "$PSScriptRoot/json_processor.ps1"

# Check if json_processor script exists
if (-not (Test-Path $JSON_PROCESSOR_SCRIPT)) {
    Write-Error "Required script 'json_processor.ps1' not found."
    exit 1
}

# Source the json_processor functions
. $JSON_PROCESSOR_SCRIPT

class BatchResult {
    [int]$Index
    [string]$Source
    [bool]$Success
    [object]$Data
    [string]$Error

    BatchResult([int]$index, [string]$source, [bool]$success, [object]$data, [string]$error) {
        $this.Index = $index
        $this.Source = $source
        $this.Success = $success
        $this.Data = $data
        $this.Error = $error
    }

    [hashtable]ToDict() {
        return @{
            index = $this.Index
            source = $this.Source
            success = $this.Success
            data = $this.Data
            error = $this.Error
        }
    }
}

function Read-Jsonl {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    $results = @()
    $lines = Get-Content -Path $FilePath -Encoding UTF8
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $lineNum = $i + 1
        $line = $lines[$i].Trim()
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        try {
            $obj = ConvertFrom-Json -InputObject $line
            $results += $obj
        } catch {
            $batchResult = [BatchResult]::new($lineNum, "${FilePath}:${lineNum}", $false, $null, "JSON decode error: $_")
            $results += $batchResult
        }
    }
    return $results
}

function Process-Batch {
    param(
        [array]$Inputs,
        [scriptblock]$Processor,
        [int]$MaxWorkers = 4
    )

    $results = @()
    $jobs = @()

    # Create jobs for each input
    for ($idx = 0; $idx -lt $Inputs.Count; $idx++) {
        $inp = $Inputs[$idx]
        $job = Start-Job -ScriptBlock $Processor -ArgumentList $inp, $idx
        $jobs += [PSCustomObject]@{
            Job = $job
            Index = $idx
        }
    }

    # Collect job results
    foreach ($jobInfo in $jobs) {
        $jobResult = Receive-Job -Job $jobInfo.Job -Wait
        Remove-Job -Job $jobInfo.Job
        $results += $jobResult
    }

    # Sort by index
    $results = $results | Sort-Object { $_.Index }
    return $results
}

function Process-FileBatch {
    param(
        [array]$FilePaths,
        [bool]$Repair = $true,
        [object]$ValidateModel = $null,
        [int]$MaxWorkers = 4
    )

    $processor = {
        param($path, $idx)
        try {
            $content = Get-Content -Path $path -Raw -Encoding UTF8
            $data = $null
            if ($ValidateModel -and $HAS_PYDANTIC) {
                $data = ParseAndValidate -JsonString $content -ModelType $ValidateModel -Repair $Repair
            } else {
                $data = ParseJson -JsonString $content -Repair $Repair
            }
            return [BatchResult]::new($idx, [string]$path, $true, $data, $null)
        } catch [JSONProcessingError] {
            return [BatchResult]::new($idx, [string]$path, $false, $null, $_.Exception.Message)
        } catch {
            return [BatchResult]::new($idx, [string]$path, $false, $null, "$($_.Exception.GetType().Name): $($_.Exception.Message)")
        }
    }

    return Process-Batch -Inputs $FilePaths -Processor $processor -MaxWorkers $MaxWorkers
}

function Process-JsonlFile {
    param(
        [string]$FilePath,
        [bool]$Repair = $true,
        [object]$ValidateModel = $null
    )

    $results = @()
    $lines = Get-Content -Path $FilePath -Encoding UTF8
    for ($lineNum = 0; $lineNum -lt $lines.Count; $lineNum++) {
        $currentLineNum = $lineNum + 1
        $line = $lines[$lineNum].Trim()
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        try {
            $data = $null
            if ($ValidateModel -and $HAS_PYDANTIC) {
                $data = ParseAndValidate -JsonString $line -ModelType $ValidateModel -Repair $Repair
            } else {
                $data = ParseJson -JsonString $line -Repair $Repair
            }
            $results += [BatchResult]::new($currentLineNum, "${FilePath}:${currentLineNum}", $true, $data, $null)
        } catch [JSONProcessingError] {
            $results += [BatchResult]::new($currentLineNum, "${FilePath}:${currentLineNum}", $false, $null, $_.Exception.Message)
        }
    }
    return $results
}

function Write-Jsonl {
    param(
        [array]$Results,
        [string]$OutputPath,
        [bool]$OnlySuccessful = $true
    )

    $outputLines = @()
    foreach ($result in $Results) {
        if ($OnlySuccessful -and -not $result.Success) {
            continue
        }
        $dict = $result.ToDict()
        $jsonLine = ConvertTo-Json -InputObject $dict -Compress
        $outputLines += $jsonLine
    }
    Set-Content -Path $OutputPath -Value $outputLines -Encoding UTF8
}

# Main execution
try {
    $allResults = @()

    if ($Jsonl) {
        # JSON-Lines Modus
        foreach ($inputPath in $Inputs) {
            $results = Process-JsonlFile -FilePath $inputPath -Repair $Repair
            $allResults += $results
        }
    } else {
        # Standard JSON Batch
        $allResults = Process-FileBatch -FilePaths $Inputs -Repair $Repair -MaxWorkers $Workers
    }

    # Ausgabe
    $successful = ($allResults | Where-Object { $_.Success }).Count
    $failed = $allResults.Count - $successful

    if ($Summary) {
        Write-Host "Processed: $($allResults.Count)"
        Write-Host "Successful: $successful"
        Write-Host "Failed: $failed"
    } else {
        foreach ($result in $allResults) {
            if ($result.Success) {
                $jsonOutput = ConvertTo-Json -InputObject $result.Data -Depth 10
                Write-Output $jsonOutput
            } else {
                Write-Error "ERROR [$($result.Source)]: $($result.Error)"
            }
        }
    }

    # Optional: JSONL Output
    if ($Output) {
        Write-Jsonl -Results $allResults -OutputPath $Output -OnlySuccessful $false
        Write-Error "`nResults written to: $Output"
    }

    # Exit code
    if ($failed -eq 0) {
        exit 0
    } else {
        exit 1
    }
} catch {
    Write-Error "An unexpected error occurred: $_"
    exit 1
}
