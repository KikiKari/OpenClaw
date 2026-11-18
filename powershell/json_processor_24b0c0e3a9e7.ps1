#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "8fd5eb568f36b749952f79e9c57207f67f330a081bbc1042ce9f13313c1fb66d", "source_sha256": "f68a161573356fe83ce98ebe454cffaef6896f81d310cd932a9847500e671f9b", "target_language": "powershell"}
# json_processor.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_processor.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_processor.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
JSON Processor mit Validierung und Reparatur.
Fuer robuste Verarbeitung von LLM-Outputs.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Input,

    [switch]$File,

    [switch]$Repair,

    [switch]$NoRepair,

    [switch]$Pretty
)

# Standardmaessig Reparatur aktivieren
$repairEnabled = $true
if ($NoRepair) {
    $repairEnabled = $false
}
elseif ($Repair) {
    $repairEnabled = $true
}

# Hilfsfunktion fuer Fehlerausgabe
function Write-ErrorAndExit {
    param([string]$Message, [int]$ExitCode = 1)
    Write-Error $Message
    exit $ExitCode
}

# Pruefe ob JSON-Modul vorhanden ist
try {
    $null = Get-Module -ListAvailable -Name Newtonsoft.Json
    $hasNewtonsoft = $true
}
catch {
    $hasNewtonsoft = $false
}

# Reparatur-Funktion (vereinfacht)
function Repair-JsonString {
    param([string]$RawJson)

    if (-not $script:hasNewtonsoft) {
        # Fallback-Reparaturen ohne externe Module
        $cleaned = $RawJson.Trim()

        # Entferne JavaScript-Kommentare (vereinfacht)
        $cleaned = $cleaned -replace '//.*?$', ''
        $cleaned = $cleaned -replace '/\*.*?\*/', ''

        # Entferne trailing commas vor ] oder }
        $cleaned = $cleaned -replace ',(\s*[\]}])', '$1'

        return $cleaned
    }
    else {
        # Mit Newtonsoft.Json koennte man hier komplexere Reparaturen machen
        return $RawJson
    }
}

# Hauptfunktion zum Parsen von JSON
function Parse-Json {
    param(
        [string]$RawInput,
        [bool]$Repair = $true
    )

    $RawInput = $RawInput.Trim()

    # Versuche direktes Parsen
    try {
        $result = $RawInput | ConvertFrom-Json
        return $result
    }
    catch {
        # Ignoriere Fehler und versuche Reparatur
    }

    # Extrahiere JSON aus Markdown-Code-Bloecken
    if ($RawInput -match '```') {
        # Suche nach JSON in ```json ... ``` oder ``` ... ```
        $patterns = @(
            '```json\s*(.*?)\s*```'
            '```\s*(\{.*?\})\s*```'
            '```\s*(\[.*?\])\s*```'
        )

        foreach ($pattern in $patterns) {
            $matches = [regex]::Matches($RawInput, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
            foreach ($match in $matches) {
                try {
                    $jsonStr = $match.Groups[1].Value
                    $result = $jsonStr | ConvertFrom-Json
                    return $result
                }
                catch {
                    continue
                }
            }
        }
    }

    # Versuche Reparatur
    if ($Repair) {
        try {
            $repaired = Repair-JsonString -RawJson $RawInput
            $result = $repaired | ConvertFrom-Json
            return $result
        }
        catch {
            throw "Konnte JSON nicht parsen auch nach Reparatur: $_"
        }
    }

    throw "Konnte JSON nicht parsen"
}

# Sicheres JSON-Parsing mit Default-Wert
function Safe-JsonLoad {
    param(
        [string]$RawInput,
        [object]$Default = $null,
        [bool]$Repair = $true
    )

    try {
        return Parse-Json -RawInput $RawInput -Repair $Repair
    }
    catch {
        return $Default
    }
}

# Hauptprogramm
try {
    $content = ""
    if ($File) {
        if (Test-Path $Input) {
            $content = Get-Content -Path $Input -Raw
        }
        else {
            Write-ErrorAndExit "Datei nicht gefunden: $Input"
        }
    }
    else {
        $content = $Input
    }

    $result = Parse-Json -RawInput $content -Repair $repairEnabled

    if ($Pretty) {
        $output = $result | ConvertTo-Json -Depth 10
    }
    else {
        $output = $result | ConvertTo-Json -Compress
    }

    Write-Output $output
}
catch {
    Write-ErrorAndExit "Fehler: $_"
}
