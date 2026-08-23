#!/usr/bin/env pwsh
# test-search.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-search.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-search.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-search.sh
# auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-search.sh
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = 'Stop'

if (-not $env:PERPLEXITY_API_KEY) {
    Write-Error "PERPLEXITY_API_KEY is required"
    exit 1
}

$query = if ($args.Count -gt 0) { $args[0] } else { "Perplexity API Platform" }
$max_results = if ($env:PERPLEXITY_MAX_RESULTS) { $env:PERPLEXITY_MAX_RESULTS } else { "3" }
$max_tokens_per_page = if ($env:PERPLEXITY_MAX_TOKENS_PER_PAGE) { $env:PERPLEXITY_MAX_TOKENS_PER_PAGE } else { "256" }

$tmpdir = if ($env:TMPDIR) { $env:TMPDIR } else { if ($env:TEMP) { $env:TEMP } else { "/tmp" } }
$out = Join-Path $tmpdir "perplexity-search-test.json"

$body = @{
    query = $query
    max_results = [int]$max_results
    max_tokens_per_page = [int]$max_tokens_per_page
} | ConvertTo-Json

$headers = @{
    Authorization = "Bearer $($env:PERPLEXITY_API_KEY)"
    "Content-Type" = "application/json"
}

try {
    $response = Invoke-RestMethod -Uri 'https://api.perplexity.ai/search' -Method Post -Headers $headers -Body $body -OutFile $out -PassThru
    $code = $response.StatusCode
} catch {
    if ($_.Exception.Response) {
        $code = $_.Exception.Response.StatusCode.value__
    } else {
        $code = "000"
    }
    # Write the error response to the file if possible
    if (Test-Path variable:_.Exception.Response) {
        $errResponse = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errResponse)
        $reader.ReadToEnd() | Out-File -FilePath $out -Encoding utf8
    }
}

Write-Output "search_http=$code"

# Process the JSON output
$jsonContent = Get-Content -Path $out -Raw | ConvertFrom-Json

$resultCount = 0
$firstResult = $null

if ($jsonContent.PSObject.Properties.Name -contains "results") {
    $resultCount = @($jsonContent.results).Count
    if ($resultCount -gt 0) {
        $firstResult = $jsonContent.results[0]
    }
} elseif ($jsonContent.PSObject.Properties.Name -contains "data") {
    $resultCount = @($jsonContent.data).Count
    if ($resultCount -gt 0) {
        $firstResult = $jsonContent.data[0]
    }
}

$outputObj = [PSCustomObject]@{
    keys = $jsonContent.PSObject.Properties.Name
    result_count = $resultCount
    first = $firstResult
}

$outputObj | ConvertTo-Json -Depth 10
