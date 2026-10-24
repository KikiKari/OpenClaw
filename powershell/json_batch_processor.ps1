#!/usr/bin/env pwsh
# json_batch_processor.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_batch_processor.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_batch_processor.py
# Erzeugt: 2026-10-24 durch ABSTRACTIONS_MANAGER.py

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

# Globale Variablen
$HAS_PYDANTIC = $false
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$jsonProcessorPath = Join-Path $scriptDir "json_processor.ps1"

if (Test-Path $jsonProcessorPath) {
    . $jsonProcessorPath
} else {
    Write-Error "json_processor.ps1 nicht gefunden"
    exit 1
}

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
        [System.IO.FileInfo]$FilePath
    )
    
    <#
    Liest JSON-Lines (NDJSON) Datei Zeile für Zeile.
    
    Args:
        FilePath: Pfad zur .jsonl oder .ndjson Datei
    
    Returns:
        Generator von geparsten JSON-Objekten
    #>
    
    $lineNum = 0
    foreach ($line in Get-Content $FilePath.FullName -Encoding UTF8) {
        $lineNum++
        $line = $line.Trim()
        if (-not $line) { continue }
        
        try {
            $obj = $line | ConvertFrom-Json
            $obj
        } catch {
            [BatchResult]::new($lineNum, "$($FilePath.FullName):$lineNum", $false, $null, "JSON decode error: $($_.Exception.Message)")
        }
    }
}

function Invoke-ProcessBatch {
    param(
        [array]$Inputs,
        [scriptblock]$Processor,
        [int]$MaxWorkers = 4
    )
    
    <#
    Verarbeitet eine Liste von Inputs parallel.
    
    Args:
        Inputs: Liste der zu verarbeitenden Eingaben (Strings oder Pfade)
        Processor: Skriptblock, der (input, index) -> BatchResult zurückgibt
        MaxWorkers: Anzahl paralleler Worker
    
    Returns:
        Liste der BatchResult-Objekte
    #>
    
    $results = @()
    $jobs = @()
    
    for ($idx = 0; $idx -lt $Inputs.Count; $idx++) {
        $inp = $Inputs[$idx]
        $job = Start-Job -ScriptBlock $Processor -ArgumentList $inp, $idx
        $jobs += [PSCustomObject]@{
            Job = $job
            Index = $idx
        }
    }
    
    foreach ($jobInfo in $jobs) {
        $jobResult = Receive-Job $jobInfo.Job -Wait
        Remove-Job $jobInfo.Job
        $results += $jobResult
    }
    
    # Sortiere nach Index
    $results = $results | Sort-Object { $_.Index }
    return $results
}

function Process-FileBatch {
    param(
        [System.IO.FileInfo[]]$FilePaths,
        [bool]$Repair = $true,
        $ValidateModel = $null,
        [int]$MaxWorkers = 4
    )
    
    <#
    Verarbeitet mehrere JSON-Dateien im Batch.
    
    Args:
        FilePaths: Liste der Datei-Pfade
        Repair: Ob JSON-Reparatur angewendet werden soll
        ValidateModel: Optionales Validierungsmodell
        MaxWorkers: Parallele Worker
    
    Returns:
        Liste der BatchResult-Objekte
    #>
    
    $processor = {
        param($path, $idx)
        
        try {
            $content = [System.IO.File]::ReadAllText($path.FullName, [System.Text.Encoding]::UTF8)
            
            if ($ValidateModel -and $HAS_PYDANTIC) {
                $data = ParseAndValidate $content $ValidateModel -Repair:$Repair
            } else {
                $data = Parse-Json $content -Repair:$Repair
            }
            
            [BatchResult]::new($idx, $path.FullName, $true, $data, $null)
        } catch [JSONProcessingError] {
            [BatchResult]::new($idx, $path.FullName, $false, $null, $_.Exception.Message)
        } catch {
            [BatchResult]::new($idx, $path.FullName, $false, $null, "$($_.Exception.GetType().Name): $($_.Exception.Message)")
        }
    }
    
    return Invoke-ProcessBatch -Inputs $FilePaths -Processor $processor -MaxWorkers $MaxWorkers
}

function Process-JsonlFile {
    param(
        [System.IO.FileInfo]$FilePath,
        [bool]$Repair = $true,
        $ValidateModel = $null
    )
    
    <#
    Verarbeitet eine JSON-Lines Datei.
    
    Args:
        FilePath: Pfad zur .jsonl Datei
        Repair: Ob Reparatur angewendet werden soll
        ValidateModel: Optionales Validierungsmodell
    
    Returns:
        Liste der BatchResult-Objekte
    #>
    
    $results = @()
    $lineNum = 0
    
    foreach ($line in Get-Content $FilePath.FullName -Encoding UTF8) {
        $lineNum++
        $line = $line.Trim()
        if (-not $line) { continue }
        
        try {
            if ($ValidateModel -and $HAS_PYDANTIC) {
                $data = ParseAndValidate $line $ValidateModel -Repair:$Repair
            } else {
                $data = Parse-Json $line -Repair:$Repair
            }
            
            $results += [BatchResult]::new($lineNum, "$($FilePath.FullName):$lineNum", $true, $data, $null)
        } catch [JSONProcessingError] {
            $results += [BatchResult]::new($lineNum, "$($FilePath.FullName):$lineNum", $false, $null, $_.Exception.Message)
        }
    }
    
    return $results
}

function Write-Jsonl {
    param(
        [BatchResult[]]$Results,
        [System.IO.FileInfo]$OutputPath,
        [bool]$OnlySuccessful = $true
    )
    
    <#
    Schreibt BatchResult-Liste als JSON-Lines.
    
    Args:
        Results: Liste der Ergebnisse
        OutputPath: Ausgabedatei
        OnlySuccessful: Nur erfolgreiche Ergebnisse schreiben
    #>
    
    $outputLines = @()
    foreach ($result in $Results) {
        if ($OnlySuccessful -and -not $result.Success) {
            continue
        }
        $outputLines += ($result.ToDict() | ConvertTo-Json -Compress)
    }
    
    $outputLines -join "`n" | Out-File $OutputPath.FullName -Encoding UTF8
}

function Main {
    $allResults = @()
    
    if ($Jsonl) {
        # JSON-Lines Modus
        foreach ($inputPath in $Inputs) {
            $results = Process-JsonlFile -FilePath (Get-Item $inputPath) -Repair $Repair
            $allResults += $results
        }
    } else {
        # Standard JSON Batch
        $filePaths = $Inputs | ForEach-Object { Get-Item $_ }
        $allResults = Process-FileBatch -FilePaths $filePaths -Repair $Repair -MaxWorkers $Workers
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
                Write-Output ($result.Data | ConvertTo-Json -Depth 100)
            } else {
                Write-Error "ERROR [$($result.Source)]: $($result.Error)"
            }
        }
    }
    
    # Optional: JSONL Output
    if ($Output) {
        Write-Jsonl -Results $allResults -OutputPath (Get-Item $Output) -OnlySuccessful $false
        Write-Error "`nResults written to: $Output"
    }
    
    # Exit code
    if ($failed -eq 0) {
        exit 0
    } else {
        exit 1
    }
}

Main
