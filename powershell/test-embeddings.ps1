#!/usr/bin/env pwsh
# test-embeddings.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-embeddings.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-embeddings.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-embeddings.sh
# auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-embeddings.sh
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = 'Stop'

if (-not $env:PERPLEXITY_API_KEY) {
    Write-Error "PERPLEXITY_API_KEY is required"
    exit 1
}

$out = Join-Path ([System.IO.Path]::GetTempPath()) "perplexity-embeddings-test.json"

$payload = @{
    input = @(
        "Scientists explore the universe driven by curiosity."
        "Curiosity compels us to seek explanations, not just observations."
        "Historical discoveries began with curious questions."
        "The pursuit of knowledge distinguishes human curiosity from mere stimulus response."
        "Philosophy examines the nature of curiosity."
    )
    model = "pplx-embed-v1-4b"
} | ConvertTo-Json

$response = Invoke-WebRequest -Uri 'https://api.perplexity.ai/v1/embeddings' `
    -Method POST `
    -Headers @{
        Authorization = "Bearer $env:PERPLEXITY_API_KEY"
        'Content-Type' = 'application/json'
    } `
    -Body $payload `
    -OutFile $out `
    -PassThru

Write-Output "embeddings_http=$($response.StatusCode)"

$result = Get-Content $out | ConvertFrom-Json
$output = @{
    keys = ($result | Get-Member -MemberType NoteProperty).Name
    model = if ($result.PSObject.Properties.Name -contains 'model') { $result.model } else { $null }
    item_count = if ($result.PSObject.Properties.Name -contains 'data') { ($result.data | Measure-Object).Count } else { 0 }
    first_dim = if ($result.PSObject.Properties.Name -contains 'data' -and $result.data.Count -gt 0 -and $result.data[0].PSObject.Properties.Name -contains 'embedding') { ($result.data[0].embedding | Measure-Object).Count } else { 0 }
    error = if ($result.PSObject.Properties.Name -contains 'error') { $result.error } else { $null }
} | ConvertTo-Json

Write-Output $output
