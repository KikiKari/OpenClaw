#!/usr/bin/env pwsh
# json_schema_validator.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/json_schema_validator.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/json_schema_validator.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
    JSON Schema Validator - Validates JSON against JSON Schema Draft 7/2020-12.
.DESCRIPTION
    Extended with external schema files support.
#>

# Import required modules
try {
    Add-Type -Path (Join-Path $PSScriptRoot "Newtonsoft.Json.Schema.dll") -ErrorAction Stop
    $HAS_JSONSCHEMA = $true
} catch {
    $HAS_JSONSCHEMA = $false
}

# Import helper functions
. (Join-Path $PSScriptRoot "json_processor.ps1")

class SchemaValidationError : System.Exception {
    SchemaValidationError($message) : base($message) {}
}

function Load-Schema {
    <#
    .SYNOPSIS
        Loads a JSON Schema from various sources.
    .PARAMETER SchemaSource
        Path to schema file, schema dictionary, or JSON string.
    .OUTPUTS
        Schema as hashtable.
    #>
    param(
        [Parameter(Mandatory=$true)]
        $SchemaSource
    )
    
    if ($SchemaSource -is [hashtable]) {
        return $SchemaSource
    }
    
    $schemaPath = [System.IO.Path]::GetFullPath($SchemaSource)
    if (Test-Path $schemaPath -PathType Leaf) {
        try {
            $content = Get-Content -Path $schemaPath -Raw
            return $content | ConvertFrom-Json -AsHashtable
        } catch {
            throw [SchemaValidationError]::new("Invalid JSON in schema file: $_")
        }
    }
    
    # Try parsing as JSON string
    try {
        return $SchemaSource | ConvertFrom-Json -AsHashtable
    } catch {
        throw [SchemaValidationError]::new("Schema not found or invalid: $SchemaSource")
    }
}

function Validate-WithJsonSchema {
    <#
    .SYNOPSIS
        Validates data against a JSON Schema.
    .PARAMETER Data
        Data to validate.
    .PARAMETER Schema
        JSON Schema (path, string, or hashtable).
    .PARAMETER Draft
        JSON Schema Draft Version ("auto", "draft7", "2020-12").
    .OUTPUTS
        $true if valid.
    #>
    param(
        [Parameter(Mandatory=$true)]
        $Data,
        
        [Parameter(Mandatory=$true)]
        $Schema,
        
        [string]$Draft = "auto"
    )
    
    if (-not $HAS_JSONSCHEMA) {
        throw [SchemaValidationError]::new("Newtonsoft.Json.Schema not available.")
    }
    
    $schemaDict = Load-Schema -SchemaSource $Schema
    
    try {
        $schemaString = $schemaDict | ConvertTo-Json -Depth 100
        $jSchema = [Newtonsoft.Json.Schema.JSchema]::Parse($schemaString)
        
        $dataString = $Data | ConvertTo-Json -Depth 100
        $validationResult = [Newtonsoft.Json.Schema.SchemaExtensions]::IsValid(
            ([Newtonsoft.Json.Linq.JToken]::Parse($dataString)),
            $jSchema,
            [ref]$null
        )
        
        if (-not $validationResult) {
            # In PowerShell we can't get detailed path info easily without more complex implementation
            throw [SchemaValidationError]::new("Schema validation failed")
        }
        
        return $true
    } catch [SchemaValidationError] {
        throw
    } catch {
        throw [SchemaValidationError]::new("Schema validation failed: $_")
    }
}

function Pydantic-ToJsonSchema {
    <#
    .SYNOPSIS
        Converts a class definition to JSON Schema.
    .PARAMETER ModelClass
        Class/model definition.
    .OUTPUTS
        JSON Schema as hashtable.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [type]$ModelClass
    )
    
    # This would require specific implementation based on actual model structure
    # Placeholder for demonstration purposes
    @{
        type = "object"
        properties = @{}
    }
}

function Validate-AndConvert {
    <#
    .SYNOPSIS
        Parses, repairs, and validates JSON against schema.
    .PARAMETER RawInput
        JSON string.
    .PARAMETER Schema
        JSON Schema.
    .PARAMETER Repair
        Whether to attempt repair.
    .OUTPUTS
        Validated data.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$RawInput,
        
        [Parameter(Mandatory=$true)]
        $Schema,
        
        [bool]$Repair = $true
    )
    
    $data = Parse-Json -RawInput $RawInput -Repair $Repair
    Validate-WithJsonSchema -Data $data -Schema $Schema
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
    
    # Simple argument parsing since we don't have argparse equivalent
    $inputArg = ""
    $schemaArg = ""
    $isFile = $false
    $repair = $true
    
    for ($i = 0; $i -lt $Args.Count; $i++) {
        switch ($Args[$i]) {
            {($_ -eq "--schema") -or ($_ -eq "-s")} {
                $schemaArg = $Args[++$i]
            }
            {($_ -eq "--file") -or ($_ -eq "-f")} {
                $isFile = $true
            }
            {($_ -eq "--repair") -or ($_ -eq "-r")} {
                $repair = $true
            }
            default {
                if (-not $inputArg) {
                    $inputArg = $Args[$i]
                }
            }
        }
    }
    
    if (-not $inputArg -or -not $schemaArg) {
        Write-Error "Missing required arguments"
        exit 1
    }
    
    # Load input (auto-detect file vs string)
    $rawInput = ""
    if ($isFile -or (Test-Path $inputArg -PathType Leaf)) {
        $rawInput = Get-Content -Path $inputArg -Raw
    } else {
        $rawInput = $inputArg
    }
    
    try {
        $result = Validate-AndConvert -RawInput $rawInput -Schema $schemaArg -Repair $repair
        $result | ConvertTo-Json -Depth 100 | Write-Output
        Write-Error "✓ Validation passed" -ErrorAction SilentlyContinue
    } catch {
        Write-Error "✗ Validation failed: $_" -ErrorAction Stop
        exit 1
    }
}

# Entry point
if ($MyInvocation.InvocationName -ne '.') {
    Main -Args $args
}
