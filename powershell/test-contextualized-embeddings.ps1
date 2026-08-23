#!/usr/bin/env pwsh
# test-contextualized-embeddings.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
# auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
# auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-contextualized-embeddings.sh
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

if (-not $env:PERPLEXITY_API_KEY) {
    Write-Error "PERPLEXITY_API_KEY is required"
    exit 1
}

$out = if ($env:TMPDIR) { Join-Path $env:TMPDIR "perplexity-contextualized-embeddings-test.json" } else { "/tmp/perplexity-contextualized-embeddings-test.json" }

$payload = @{
    input = @(@(
        "OpenClaw can route web search through Perplexity.",
        "The Perplexity MCP server exposes search and reasoning tools.",
        "Contextualized embeddings improve document chunk retrieval."
    ))
    model = "pplx-embed-context-v1-4b"
} | ConvertTo-Json -Compress

$response = Invoke-WebRequest -Uri "https://api.perplexity.ai/v1/contextualizedembeddings" `
    -Method POST `
    -Headers @{
        "Authorization" = "Bearer $($env:PERPLEXITY_API_KEY)"
        "Content-Type" = "application/json"
    } `
    -Body $payload `
    -OutFile $out `
    -PassThru

$code = $response.StatusCode
Write-Output "contextualized_embeddings_http=$code"

$resp = Get-Content $out | ConvertFrom-Json
@{
    keys = $resp.PSObject.Properties.Name
    model = if ($resp.model) { $resp.model } else { $null }
    document_count = if ($resp.data) { $resp.data.Count } else { 0 }
    first_chunk_count = if ($resp.data -and $resp.data[0].data) { $resp.data[0].data.Count } else { 0 }
    error = if ($resp.error) { $resp.error } else { $null }
} | ConvertTo-Json
