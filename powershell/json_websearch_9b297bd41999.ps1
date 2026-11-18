#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "0543ca9ff45b27e24230965b41fe18f6d064cca249351f9cd12b3590b8f7ee35", "source_sha256": "d3ab9d6951153a42390fb59c1a50b0c901cf4c399dcb731b89865fdc293f3ac9", "target_language": "powershell"}
# json_websearch.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/json_websearch.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/json_websearch.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

<#
JSON Utils + WebSearch integration.
Fetch API schemas from web, validate real API responses, batch-validate endpoints.
#>

using namespace System.Collections.Generic
using namespace System.IO

class WebSearchResult {
    [string]$Query
    [object]$JsonData
    [List[string]]$ValidationErrors
    [bool]$SchemaMatched
    [string]$SourceUrl
    
    WebSearchResult(
        [string]$query,
        [object]$jsonData,
        [List[string]]$validationErrors,
        [bool]$schemaMatched,
        [string]$sourceUrl
    ) {
        $this.Query = $query
        $this.JsonData = $jsonData
        $this.ValidationErrors = $validationErrors
        $this.SchemaMatched = $schemaMatched
        $this.SourceUrl = $sourceUrl
    }
}

class WebSearchJSON {
    [bool]$UseRepair
    [bool]$JsonAvailable
    
    WebSearchJSON([bool]$useRepair = $true) {
        $this.UseRepair = $useRepair
        
        # Check if json-utils module is available
        $jsonUtilsAvailable = $false
        try {
            $null = Get-Module -Name json-utils -ListAvailable
            $jsonUtilsAvailable = $true
        }
        catch {
            $jsonUtilsAvailable = $false
        }
        $this.JsonAvailable = $jsonUtilsAvailable
        
        if (-not $jsonUtilsAvailable) {
            Write-Warning "json-utils not found. Some features disabled."
        }
    }
    
    [WebSearchResult] SearchAndValidate(
        [string]$query,
        [object]$schema = $null,
        [string]$schemaPath = $null
    ) {
        <#
        Search web for JSON data, validate against schema.
        
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
                @{path = "/items"; method = "GET"},
                @{path = "/items"; method = "POST"}
            )
        }
        
        # Validate with json-utils if available
        $validationErrors = [List[string]]::new()
        $schemaMatched = $false
        
        if ($this.JsonAvailable -and ($schema -or $schemaPath)) {
            try {
                if ($schemaPath) {
                    $schemaContent = Get-Content $schemaPath -Raw
                    $schemaObj = $schemaContent | ConvertFrom-Json
                    # Basic schema validation simulation
                    if (-not $mockResponse.ContainsKey("api")) {
                        throw "Missing required property: api"
                    }
                }
                $schemaMatched = $true
            }
            catch {
                $validationErrors.Add($_.Exception.Message)
            }
        }
        
        return [WebSearchResult]::new(
            $query,
            $mockResponse,
            $validationErrors,
            $schemaMatched,
            "https://api.github.com/search?q=" + ($query -replace ' ', '+')
        )
    }
    
    [object] ValidateApiResponse(
        [string]$responseData,
        [string]$endpoint,
        [object]$expectedSchema = $null
    ) {
        <#
        Validate an API response with auto-repair.
        
        Uses json-utils for robust parsing.
        #>
        
        if (-not $this.JsonAvailable) {
            return $responseData | ConvertFrom-Json
        }
        
        # Use json-utils parser with auto-repair simulation
        try {
            $result = $responseData | ConvertFrom-Json
        }
        catch {
            # Basic repair simulation
            if ($this.UseRepair) {
                try {
                    # Try to fix common JSON issues
                    $repairedData = $responseData -replace "`"`"", "null" `
                                           -replace ",\s*}", "}" `
                                           -replace ",\s*]", "]"
                    $result = $repairedData | ConvertFrom-Json
                }
                catch {
                    throw "Failed to parse JSON even with repair: $($_.Exception.Message)"
                }
            }
            else {
                throw "Failed to parse JSON: $($_.Exception.Message)"
            }
        }
        
        if ($expectedSchema) {
            try {
                # Basic schema validation simulation
                if ($result -isnot [PSCustomObject] -and $result -isnot [Hashtable]) {
                    throw "Response is not a JSON object"
                }
            }
            catch {
                Write-Host "Schema validation failed for $endpoint`: $($_.Exception.Message)"
            }
        }
        
        return $result
    }
    
    [List[WebSearchResult]] BatchValidateEndpoints(
        [string[]]$endpoints,
        [string[]]$responses,
        [string]$schemaPath = $null
    ) {
        <#
        Batch-validate multiple API endpoint responses.
        #>
        
        $results = [List[WebSearchResult]]::new()
        
        for ($i = 0; $i -lt $endpoints.Length; $i++) {
            $endpoint = $endpoints[$i]
            $response = $responses[$i]
            
            try {
                $jsonData = $this.ValidateApiResponse($response, $endpoint)
                $results.Add([WebSearchResult]::new(
                    $endpoint,
                    $jsonData,
                    [List[string]]::new(),
                    $true,
                    $endpoint
                ))
            }
            catch {
                $errors = [List[string]]::new()
                $errors.Add($_.Exception.Message)
                $results.Add([WebSearchResult]::new(
                    $endpoint,
                    @{},
                    $errors,
                    $false,
                    $endpoint
                ))
            }
        }
        
        return $results
    }
    
    [object] GenerateApiSchema([string]$sampleResponse, [string]$endpoint) {
        <#
        Generate JSON Schema from sample API response.
        #>
        
        if (-not $this.JsonAvailable) {
            return @{}
        }
        
        try {
            $data = $sampleResponse | ConvertFrom-Json
        }
        catch {
            return @{}
        }
        
        function InferSchema {
            param(
                [object]$obj,
                [string]$path = "root"
            )
            
            if ($obj -is [PSCustomObject] -or $obj -is [Hashtable]) {
                $properties = @{}
                foreach ($key in $obj.PSObject.Properties.Name) {
                    $value = $obj.$key
                    $properties[$key] = InferSchema $value "$path.$key"
                }
                return @{
                    type = "object"
                    properties = $properties
                }
            }
            elseif ($obj -is [Array] -and $obj.Length -gt 0) {
                return @{
                    type = "array"
                    items = InferSchema $obj[0] "$path[]"
                }
            }
            elseif ($obj -is [string]) {
                return @{type = "string"}
            }
            elseif ($obj -is [int]) {
                return @{type = "integer"}
            }
            elseif ($obj -is [double] -or $obj -is [float] -or $obj -is [decimal]) {
                return @{type = "number"}
            }
            elseif ($obj -is [bool]) {
                return @{type = "boolean"}
            }
            else {
                return @{type = "null"}
            }
        }
        
        $inferredSchema = InferSchema $data
        $schema = @{
            '$schema' = "http://json-schema.org/draft-07/schema#"
            title = "$endpoint Response Schema"
        }
        
        foreach ($key in $inferredSchema.Keys) {
            $schema[$key] = $inferredSchema[$key]
        }
        
        return $schema
    }
}

function main {
    param()
    
    $search = $null
    $validateFile = $null
    $schema = $null
    $generateSchema = $null
    $endpoint = $null
    
    # Simple argument parsing for PowerShell
    for ($i = 0; $i -lt $args.Length; $i++) {
        if ($args[$i] -eq "--search" -and $i -lt $args.Length - 1) {
            $search = $args[$i + 1]
            $i++
        }
        elseif ($args[$i] -eq "--validate-file" -and $i -lt $args.Length - 1) {
            $validateFile = $args[$i + 1]
            $i++
        }
        elseif ($args[$i] -eq "--schema" -and $i -lt $args.Length - 1) {
            $schema = $args[$i + 1]
            $i++
        }
        elseif ($args[$i] -eq "--generate-schema" -and $i -lt $args.Length - 1) {
            $generateSchema = $args[$i + 1]
            $i++
        }
        elseif ($args[$i] -eq "--endpoint" -and $i -lt $args.Length - 1) {
            $endpoint = $args[$i + 1]
            $i++
        }
    }
    
    $ws = [WebSearchJSON]::new()
    
    if ($search) {
        $result = $ws.SearchAndValidate($search, $null, $schema)
        Write-Host "Query: $($result.Query)"
        Write-Host "Data: $($result.JsonData | ConvertTo-Json -Depth 10)"
        Write-Host "Schema matched: $($result.SchemaMatched)"
        if ($result.ValidationErrors.Count -gt 0) {
            Write-Host "Errors: $($result.ValidationErrors -join ', ')"
        }
    }
    elseif ($generateSchema -and $endpoint) {
        $sample = Get-Content $generateSchema -Raw
        $schemaObj = $ws.GenerateApiSchema($sample, $endpoint)
        $schemaObj | ConvertTo-Json -Depth 10
    }
}

if ($MyInvocation.InvocationName -ne ".") {
    main $args
}
