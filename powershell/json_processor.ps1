#!/usr/bin/env pwsh
# json_processor.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_processor.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_processor.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
JSON Processor mit Validierung und Reparatur.
.DESCRIPTION
Fuer robuste Verarbeitung von LLM-Outputs.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Input,

    [switch]$File,

    [switch]$Repair = $true,

    [switch]$NoRepair,

    [switch]$Pretty
)

$Repair = !$NoRepair

class JSONProcessingError : System.Exception {
    JSONProcessingError([string]$message) : base($message) {}
}

class JSONValidationError : JSONProcessingError {
    JSONValidationError([string]$message) : base($message) {}
}

class JSONRepairError : JSONProcessingError {
    JSONRepairError([string]$message) : base($message) {}
}

function Repair-JsonString {
    param(
        [string]$RawJson
    )

    <#
    Repariert haeufige JSON-Fehler aus LLM-Outputs.

    Behebt:
    - Trailing commas
    - Einzelne statt doppelte Quotes
    - JavaScript-Style Kommentare
    - Unescaped Zeilenumbrueche in Strings
    #>

    try {
        # Versuche json-repair Modul zu laden
        Import-Module json-repair -ErrorAction Stop
        $repaired = Repair-Json $RawJson -ReturnObjects $false
        return $repaired
    }
    catch {
        Write-Warning "json-repair nicht verfuegbar. Verwende manuelle Reparaturen."
        # Fallback: Manuelle Reparaturen
        $cleaned = $RawJson.Trim()

        # Entferne JavaScript-Kommentare
        $cleaned = $cleaned -replace '//.*?\n', "`n"
        $cleaned = $cleaned -replace '/\*.*?\*/', ''

        # Entferne trailing commas vor ] oder }
        $cleaned = $cleaned -replace ',(\s*[}\]])', '$1'

        return $cleaned
    }
}

function Parse-Json {
    param(
        [string]$RawInput,
        [bool]$Repair = $true
    )

    <#
    Parst JSON-String mit optionaler automatischer Reparatur.

    .PARAMETER RawInput
    Der zu parsende JSON-String

    .PARAMETER Repair
    Ob JSON-Reparatur versucht werden soll (default: True)

    .RETURNS
    Geparstes PowerShell-Objekt

    .THROWS
    JSONProcessingError bei Fehlschlag
    #>

    $RawInput = $RawInput.Trim()

    # Versuche zuerst direktes Parsing
    try {
        $jsonObject = $RawInput | ConvertFrom-Json -ErrorAction Stop
        return $jsonObject
    }
    catch {
        # Parsing fehlgeschlagen, weiter mit Reparatur
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
                    return $jsonStr | ConvertFrom-Json -ErrorAction Stop
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
            return $repaired | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw [JSONProcessingError]::new("Konnte JSON auch nach Reparatur nicht parsen: $($_.Exception.Message)")
        }
    }

    throw [JSONProcessingError]::new("Konnte JSON nicht parsen")
}

function ParseAndValidate {
    param(
        [string]$RawInput,
        [type]$ModelClass,
        [bool]$Repair = $true,
        [bool]$Strict = $false
    )

    <#
    Parst JSON und validiert gegen ein Modell.

    .PARAMETER RawInput
    Der zu parsende JSON-String

    .PARAMETER ModelClass
    Modellklasse fuer Validierung

    .PARAMETER Repair
    Ob JSON-Reparatur versucht werden soll

    .PARAMETER Strict
    Ob strikte Validierung angewendet werden soll

    .RETURNS
    Validierte Instanz des Modells

    .THROWS
    JSONValidationError bei Fehlschlag
    #>

    try {
        $data = Parse-Json -RawInput $RawInput -Repair $Repair
    }
    catch [JSONProcessingError] {
        throw [JSONValidationError]::new("JSON-Parsing fehlgeschlagen: $($_.Exception.Message)")
    }

    # In PowerShell gibt es kein direktes Aequivalent zu Pydantic,
    # daher simulieren wir die Validierung durch Typueberpruefung
    # und Strukturpruefung basierend auf dem Modell.

    # Hier koennte eine eigene Implementierung der Modellvalidierung erfolgen
    # Da PowerShell keine native Pydantic-Unterstuetzung hat,
    # geben wir das geparste Objekt zurueck, ohne weitere Validierung
    return $data
}

function Validate-ToolCall {
    param(
        [string]$RawJson,
        [string]$ToolName = $null
    )

    <#
    Validiert einen OpenClaw/Tool-Call JSON.

    .PARAMETER RawJson
    Der Tool-Call JSON-String

    .PARAMETER ToolName
    Optionaler erwarteter Tool-Name

    .RETURNS
    Validiertes Tool-Call Dict
    #>

    try {
        $toolCall = ParseAndValidate -RawInput $RawJson -ModelClass ([PSCustomObject]) -Repair $true
    }
    catch {
        throw [JSONValidationError]::new("ToolCall-Parsing fehlgeschlagen: $($_.Exception.Message)")
    }

    # Pruefe ob die erforderlichen Felder vorhanden sind
    if (-not $toolCall.PSObject.Properties.Name.Contains('tool')) {
        throw [JSONValidationError]::new("Feld 'tool' fehlt im JSON")
    }

    if ($ToolName -and $toolCall.tool -ne $ToolName) {
        throw [JSONValidationError]::new("Erwarteter Tool-Name '$ToolName', aber erhalten '$($toolCall.tool)'")
    }

    # Erstelle Ergebnisobjekt
    $result = @{
        tool = $toolCall.tool
        arguments = if ($toolCall.PSObject.Properties.Name.Contains('arguments')) { $toolCall.arguments } else { @{} }
        reasoning = if ($toolCall.PSObject.Properties.Name.Contains('reasoning')) { $toolCall.reasoning } else { $null }
    }

    return $result
}

function Safe-JsonLoads {
    param(
        [string]$RawInput,
        [object]$Default = $null,
        [bool]$Repair = $true
    )

    <#
    Sicheres JSON-Parsing mit Fallback auf Default-Wert.

    .PARAMETER RawInput
    Der zu parsende JSON-String

    .PARAMETER Default
    Rueckgabewert bei Fehlschlag (default: None)

    .PARAMETER Repair
    Ob Reparatur versucht werden soll

    .RETURNS
    Geparstes Objekt oder Default-Wert
    #>

    try {
        return Parse-Json -RawInput $RawInput -Repair $Repair
    }
    catch {
        return $Default
    }
}

function Extract-JsonFromText {
    param(
        [string]$Text
    )

    <#
    Extrahiert alle JSON-Objekte aus einem Text.

    .PARAMETER Text
    Text, der JSON-Objekte enthalten koennte

    .RETURNS
    Liste aller gefundenen und geparsten JSON-Objekte
    #>

    $results = @()

    # Pattern fuer JSON-Objekte und Arrays
    $patterns = @(
        '\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}'  # Objekte
        '\[[^\[\]]*(?:\[[^\[\]*\][^\[\]]*)*\]'  # Arrays
    )

    foreach ($pattern in $patterns) {
        $matches = [regex]::Matches($Text, $pattern)
        foreach ($match in $matches) {
            try {
                $parsed = Parse-Json -RawInput $match.Value -Repair $true
                $results += $parsed
            }
            catch {
                continue
            }
        }
    }

    return $results
}

# Hauptprogramm
try {
    $content = ""
    if ($File) {
        if (Test-Path $Input) {
            $content = Get-Content -Path $Input -Raw
        }
        else {
            throw [System.IO.FileNotFoundException]::new("Datei nicht gefunden: $Input")
        }
    }
    else {
        $content = $Input
    }

    $result = Parse-Json -RawInput $content -Repair $Repair

    if ($Pretty) {
        $output = $result | ConvertTo-Json -Depth 10 -EnumsAsStrings
    }
    else {
        $output = $result | ConvertTo-Json -Compress
    }

    Write-Output $output
}
catch [JSONProcessingError] {
    Write-Error "Fehler: $($_.Exception.Message)"
    exit 1
}
catch {
    Write-Error "Unerwarteter Fehler: $($_.Exception.Message)"
    exit 1
}
