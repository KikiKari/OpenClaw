#!/usr/bin/env pwsh
# validate_tool_output.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/json-utils/scripts/validate_tool_output.py
# auch in: OpenClaw@gateway2:skills/json-utils/scripts/validate_tool_output.py
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Validiert Tool-Outputs gegen ein Pydantic-Schema.
Fuer OpenClaw Tool-Call-Validierung.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$JsonInput,
    
    [Parameter(Mandatory=$true)]
    [string]$Schema,
    
    [switch]$File,
    
    [switch]$Repair = $true,
    
    [switch]$Strict
)

# Import necessary modules
try {
    Add-Type -AssemblyName System.Text.Json
} catch {
    Write-Error "Error: Failed to load required assemblies"
    exit 1
}

function ParseAndValidate {
    param(
        [string]$RawInput,
        [object]$ModelClass,
        [bool]$Repair = $true,
        [bool]$Strict = $false
    )
    
    try {
        $data = $RawInput | ConvertFrom-Json -Depth 100
        return ValidateObject -Data $data -ModelClass $ModelClass -Strict $Strict
    } catch {
        throw "JSON parsing failed: $($_.Exception.Message)"
    }
}

function ValidateObject {
    param(
        [object]$Data,
        [object]$ModelClass,
        [bool]$Strict
    )
    
    $result = @{}
    
    # Process each property in the schema
    foreach ($prop in $ModelClass.properties.GetEnumerator()) {
        $key = $prop.Key
        $value = $Data.$key
        $schemaInfo = $prop.Value
        
        # Handle missing required fields
        if ($null -eq $value -and $ModelClass.required -contains $key) {
            if ($schemaInfo.default) {
                $value = $schemaInfo.default
            } else {
                throw "Required field '$key' is missing and has no default value"
            }
        }
        
        # Type validation/conversion
        if ($null -ne $value) {
            switch ($schemaInfo.type) {
                "integer" {
                    if ($value -isnot [int]) {
                        if ($value -is [string] -and [int]::TryParse($value, [ref]$null)) {
                            $value = [int]$value
                        } else {
                            throw "Field '$key' must be an integer"
                        }
                    }
                }
                "number" {
                    if ($value -isnot [double] -and $value -isnot [int]) {
                        if ($value -is [string] -and [double]::TryParse($value, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$null)) {
                            $value = [double]$value
                        } else {
                            throw "Field '$key' must be a number"
                        }
                    }
                }
                "boolean" {
                    if ($value -isnot [bool]) {
                        if ($value -eq "true") { $value = $true }
                        elseif ($value -eq "false") { $value = $false }
                        else {
                            throw "Field '$key' must be a boolean"
                        }
                    }
                }
                "array" {
                    if ($value -isnot [array] -and $value -isnot [System.Collections.IList]) {
                        throw "Field '$key' must be an array"
                    }
                }
                "object" {
                    if ($value -isnot [pscustomobject] -and $value -isnot [hashtable]) {
                        throw "Field '$key' must be an object"
                    }
                }
                default { # string
                    if ($value -isnot [string]) {
                        $value = "$value"
                    }
                }
            }
            
            $result[$key] = $value
        } elseif ($schemaInfo.default) {
            $result[$key] = $schemaInfo.default
        }
    }
    
    # Handle strict mode - check for unexpected fields
    if ($Strict -and $Data -is [pscustomobject]) {
        $dataKeys = $Data.PSObject.Properties.Name
        $schemaKeys = $ModelClass.properties.Keys
        $unexpectedFields = $dataKeys | Where-Object { $schemaKeys -notcontains $_ }
        
        if ($unexpectedFields.Count -gt 0) {
            throw "Unexpected fields in strict mode: $($unexpectedFields -join ', ')"
        }
    }
    
    return [PSCustomObject]$result
}

function CreateDynamicModel {
    param([hashtable]$Schema)
    
    return $Schema
}

try {
    # Load schema
    $schemaContent = Get-Content -Path $Schema -Raw -ErrorAction Stop
    $schemaObj = $schemaContent | ConvertFrom-Json -AsHashtable -ErrorAction Stop
} catch {
    Write-Error "Error loading schema: $($_.Exception.Message)"
    exit 1
}

try {
    # Load input
    if ($File) {
        $rawInput = Get-Content -Path $JsonInput -Raw -ErrorAction Stop
    } else {
        $rawInput = $JsonInput
    }
} catch {
    Write-Error "Error loading input: $($_.Exception.Message)"
    exit 1
}

try {
    # Create dynamic model and validate
    $modelClass = CreateDynamicModel -Schema $schemaObj
    $result = ParseAndValidate -RawInput $rawInput -ModelClass $modelClass -Repair $Repair -Strict $Strict
    
    # Output result as JSON
    $result | ConvertTo-Json -Depth 100 | Write-Output
} catch {
    Write-Error "Validation error: $($_.Exception.Message)"
    exit 1
}
