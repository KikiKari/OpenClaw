#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "bc777fbbddc6c05e98cf3cf400b754d7c9dc329ed613f4405733f835d5efb7c9", "source_sha256": "f55ff3c9a1d0fb13ff0d5dd08f91e1c1a304c7d83f3d1bb93f165f2437d276b9", "target_language": "powershell"}
# json_schema_validator.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_schema_validator.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_schema_validator.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
JSON Schema Validator - Validiert JSON gegen JSON Schema Draft 7/2020-12.
Erweitert Pydantic mit externen Schema-Dateien.
#>

# Prüfe ob Newtonsoft.Json.Schema verfügbar ist
$hasJsonSchema = $false
try {
    Add-Type -AssemblyName "Newtonsoft.Json"
    Add-Type -AssemblyName "Newtonsoft.Json.Schema"
    $hasJsonSchema = $true
} catch {
    $hasJsonSchema = $false
}

# JSON Processing Funktionen (ersetzt json_processor.py)
function Parse-Json {
    param(
        [string]$RawInput,
        [bool]$Repair = $true
    )
    
    try {
        return ConvertFrom-Json $RawInput
    } catch {
        if ($Repair) {
            # Entferne einfache Anführungszeichen und versuche erneut
            $repaired = $RawInput -replace "'", '"'
            try {
                return ConvertFrom-Json $repaired
            } catch {
                throw "JSON parsing failed after repair attempt: $_"
            }
        } else {
            throw "JSON parsing failed: $_"
        }
    }
}

class SchemaValidationError : System.Exception {
    SchemaValidationError([string]$message) : base($message) {}
}

function Load-Schema {
    param(
        [object]$SchemaSource
    )
    
    if ($SchemaSource -is [hashtable] -or $SchemaSource -is [System.Collections.Specialized.OrderedDictionary]) {
        return $SchemaSource
    }
    
    $schemaPath = [System.IO.Path]::GetFullPath($SchemaSource)
    if (Test-Path $schemaPath) {
        try {
            $content = Get-Content -Path $schemaPath -Raw
            return ConvertFrom-Json $content -AsHashtable
        } catch {
            throw [SchemaValidationError]::new("Invalid JSON in schema file: $_")
        }
    }
    
    # Versuche als JSON String zu parsen
    try {
        return ConvertFrom-Json $SchemaSource -AsHashtable
    } catch {
        throw [SchemaValidationError]::new("Schema not found or invalid: $SchemaSource")
    }
}

function Validate-WithJsonSchema {
    param(
        [object]$Data,
        [object]$Schema,
        [string]$Draft = "auto"
    )
    
    if (-not $hasJsonSchema) {
        throw [SchemaValidationError]::new("Newtonsoft.Json.Schema not available.")
    }
    
    $schemaDict = Load-Schema $Schema
    
    try {
        # Konvertiere PowerShell-Objekt zu JSON-String für Validierung
        $jsonData = ConvertTo-Json $Data -Depth 100
        $jsonSchema = ConvertTo-Json $schemaDict -Depth 100
        
        # Validierung mit Newtonsoft.Json.Schema
        $schemaObj = [Newtonsoft.Json.Schema.JSchema]::Parse($jsonSchema)
        $valid = [Newtonsoft.Json.Schema.SchemaExtensions]::IsValid(
            [Newtonsoft.Json.Linq.JToken]::Parse($jsonData), 
            $schemaObj
        )
        
        if (-not $valid) {
            throw [SchemaValidationError]::new("Schema validation failed")
        }
        
        return $true
    } catch [SchemaValidationError] {
        throw $_
    } catch {
        throw [SchemaValidationError]::new("Schema validation failed: $_")
    }
}

function Validate-AndConvert {
    param(
        [string]$RawInput,
        [object]$Schema,
        [bool]$Repair = $true
    )
    
    $data = Parse-Json $RawInput -Repair $Repair
    Validate-WithJsonSchema $data $Schema
    return $data
}

class SchemaBuilder {
    static [hashtable] Object([hashtable]$Properties, [string[]]$Required) {
        $schema = @{
            type = "object"
            properties = $Properties
        }
        if ($Required) {
            $schema.required = $Required
        }
        return $schema
    }
    
    static [hashtable] String([string[]]$Enum, [string]$Pattern, [int]$MinLength) {
        $schema = @{ type = "string" }
        if ($Enum) {
            $schema.enum = $Enum
        }
        if ($Pattern) {
            $schema.pattern = $Pattern
        }
        if ($MinLength -ne $null) {
            $schema.minLength = $MinLength
        }
        return $schema
    }
    
    static [hashtable] Integer([int]$Minimum, [int]$Maximum) {
        $schema = @{ type = "integer" }
        if ($Minimum -ne $null) {
            $schema.minimum = $Minimum
        }
        if ($Maximum -ne $null) {
            $schema.maximum = $Maximum
        }
        return $schema
    }
    
    static [hashtable] Array([hashtable]$Items, [int]$MinItems) {
        $schema = @{
            type = "array"
            items = $Items
        }
        if ($MinItems -ne $null) {
            $schema.minItems = $MinItems
        }
        return $schema
    }
}

function Main {
    param(
        [string[]]$Args
    )
    
    # Parameter Parsing
    $inputArg = ""
    $schema = ""
    $isFile = $false
    $repair = $true
    
    for ($i = 0; $i -lt $Args.Count; $i++) {
        $arg = $Args[$i]
        switch ($arg) {
            {$_ -eq "--schema" -or $_ -eq "-s"} {
                $schema = $Args[$i + 1]
                $i++
            }
            {$_ -eq "--file" -or $_ -eq "-f"} {
                $isFile = $true
            }
            {$_ -eq "--repair" -or $_ -eq "-r"} {
                $repair = $true
            }
            {$_ -eq "--no-repair"} {
                $repair = $false
            }
            default {
                if (-not $inputArg) {
                    $inputArg = $arg
                }
            }
        }
    }
    
    if (-not $inputArg -or -not $schema) {
        Write-Error "Usage: script.ps1 <input> --schema <schema> [--file] [--repair]"
        exit 1
    }
    
    # Lade Input (Auto-detect file vs string)
    $rawInput = ""
    if ($isFile -or (Test-Path $inputArg)) {
        $rawInput = Get-Content -Path $inputArg -Raw
    } else {
        $rawInput = $inputArg
    }
    
    try {
        $result = Validate-AndConvert $rawInput $schema -Repair $repair
        $jsonResult = ConvertTo-Json $result -Depth 100
        Write-Output $jsonResult
        Write-Error "✓ Validation passed" -ErrorAction SilentlyContinue
    } catch {
        Write-Error "✗ Validation failed: $_" -ErrorAction Stop
        exit 1
    }
}

# Führe Hauptprogramm aus wenn Script direkt aufgerufen wird
if ($MyInvocation.InvocationName -eq '&' -or $MyInvocation.InvocationName -eq 'Main') {
    Main $args
}
