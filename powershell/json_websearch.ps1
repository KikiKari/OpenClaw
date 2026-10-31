#!/usr/bin/env pwsh
# json_websearch.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/json_websearch.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/json_websearch.py
# Erzeugt: 2026-10-31 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
JSON Utils + WebSearch integration.
.DESCRIPTION
Fetch API schemas from web, validate real API responses, batch-validate endpoints.
#>

param(
    [string]$Search,
    [string]$ValidateFile,
    [string]$Schema,
    [string]$GenerateSchema,
    [string]$Endpoint
)

class WebSearchResult {
    [string]$Query
    [hashtable]$JsonData
    [string[]]$ValidationErrors
    [bool]$SchemaMatched
    [string]$SourceUrl
}

class WebSearchJSON {
    [bool]$UseRepair
    [bool]$JsonAvailable

    WebSearchJSON([bool]$useRepair = $true) {
        $this.UseRepair = $useRepair
        $this.JsonAvailable = $false
        try {
            # Try to load json-utils functions
            . (Join-Path $PSScriptRoot "..\..\..\json-utils\scripts\json_processor.ps1")
            . (Join-Path $PSScriptRoot "..\..\..\json-utils\scripts\json_schema_validator.ps1")
            . (Join-Path $PSScriptRoot "..\..\..\json-utils\scripts\json_batch_processor.ps1")
            $this.JsonAvailable = $true
        } catch {
            Write-Warning "json-utils not found. Some features disabled."
        }
    }

    [WebSearchResult] SearchAndValidate([string]$query, [hashtable]$schema = $null, [string]$schemaPath = $null) {
        <#
        .SYNOPSIS
        Search web for JSON data, validate against schema.
        .DESCRIPTION
        This is a placeholder - in real usage, this would:
        1. Call WebSearch to find API docs
        2. Extract JSON examples/schemas from results
        3. Parse and validate with json-utils
        #>
        
        # Simulate web search result (would be actual search in production)
        $mockResponse = @{
            api = if ($query) { $query.Split()[0] } else { "unknown" }
            version = "1.0"
            endpoints = @(
                @{ path = "/items"; method = "GET" },
                @{ path = "/items"; method = "POST" }
            )
        }
        
        # Validate with json-utils if available
        $validationErrors = @()
        $schemaMatched = $false
        
        if ($this.JsonAvailable -and ($schema -or $schemaPath)) {
            try {
                if ($schemaPath) {
                    ValidateWithJsonSchema $mockResponse $schemaPath
                }
                $schemaMatched = $true
            } catch {
                $validationErrors += $_.Exception.Message
            }
        }
        
        return [WebSearchResult]@{
            Query = $query
            JsonData = $mockResponse
            ValidationErrors = $validationErrors
            SchemaMatched = $schemaMatched
            SourceUrl = "https://api.github.com/search?q=$($query.Replace(' ', '+'))"
        }
    }

    [hashtable] ValidateApiResponse([string]$responseData, [string]$endpoint, [hashtable]$expectedSchema = $null) {
        <#
        .SYNOPSIS
        Validate an API response with auto-repair.
        .DESCRIPTION
        Uses json-utils for robust parsing.
        #>
        if (-not $this.JsonAvailable) {
            return $responseData | ConvertFrom-Json -AsHashtable
        }
        
        # Use json-utils parser with auto-repair
        $result = ParseJson $responseData $this.UseRepair
        
        if ($expectedSchema) {
            try {
                ParseAndValidate ($result | ConvertTo-Json -Depth 100) $expectedSchema
            } catch {
                Write-Host "Schema validation failed for $endpoint`: $($_.Exception.Message)"
            }
        }
        
        return $result
    }

    [WebSearchResult[]] BatchValidateEndpoints([string[]]$endpoints, [string[]]$responses, [string]$schemaPath = $null) {
        <#
        .SYNOPSIS
        Batch-validate multiple API endpoint responses.
        #>
        $results = @()
        for ($i = 0; $i -lt $endpoints.Count; $i++) {
            $endpoint = $endpoints[$i]
            $response = $responses[$i]
            try {
                $jsonData = $this.ValidateApiResponse($response, $endpoint)
                $results += [WebSearchResult]@{
                    Query = $endpoint
                    JsonData = $jsonData
                    ValidationErrors = @()
                    SchemaMatched = $true
                    SourceUrl = $endpoint
                }
            } catch {
                $results += [WebSearchResult]@{
                    Query = $endpoint
                    JsonData = @{}
                    ValidationErrors = @($_.Exception.Message)
                    SchemaMatched = $false
                    SourceUrl = $endpoint
                }
            }
        }
        return $results
    }

    [hashtable] GenerateApiSchema([string]$sampleResponse, [string]$endpoint) {
        <#
        .SYNOPSIS
        Generate JSON Schema from sample API response.
        #>
        if (-not $this.JsonAvailable) {
            return @{}
        }
        
        $data = ParseJson $sampleResponse
        
        # Basic schema generation
        function InferSchema($obj, $path = "root") {
            if ($obj -is [hashtable]) {
                return @{
                    type = "object"
                    properties = ($obj.GetEnumerator() | ForEach-Object {
                        @{ $_.Key = (InferSchema $_.Value "$path.$($_.Key)") }
                    }) | ForEach-Object { $_ }
                }
            } elseif ($obj -is [array] -and $obj.Count -gt 0) {
                return @{
                    type = "array"
                    items = (InferSchema $obj[0] "$path[]")
                }
            } elseif ($obj -is [string]) {
                return @{ type = "string" }
            } elseif ($obj -is [int] -or $obj -is [long]) {
                return @{ type = "integer" }
            } elseif ($obj -is [double] -or $obj -is [decimal]) {
                return @{ type = "number" }
            } elseif ($obj -is [bool]) {
                return @{ type = "boolean" }
            } else {
                return @{ type = "null" }
            }
        }
        
        $schema = @{
            '$schema' = "http://json-schema.org/draft-07/schema#"
            title = "$endpoint Response Schema"
        }
        
        $inferred = InferSchema $data
        $schema += $inferred
        
        return $schema
    }
}

function Main {
    $ws = [WebSearchJSON]::new()
    
    if ($Search) {
        $result = $ws.SearchAndValidate($Search, $null, $Schema)
        Write-Output "Query: $($result.Query)"
        Write-Output "Data: $($result.JsonData | ConvertTo-Json -Depth 100)"
        Write-Output "Schema matched: $($result.SchemaMatched)"
        if ($result.ValidationErrors) {
            Write-Output "Errors: $($result.ValidationErrors -join ', ')"
        }
    } elseif ($GenerateSchema -and $Endpoint) {
        $sample = Get-Content -Path $GenerateSchema -Raw
        $schema = $ws.GenerateApiSchema($sample, $Endpoint)
        Write-Output ($schema | ConvertTo-Json -Depth 100)
    }
}

Main
