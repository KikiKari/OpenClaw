#!/usr/bin/env pwsh
# websearch-research.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway2:scripts/websearch-research.sh
# Erzeugt: 2026-10-24 durch ABSTRACTIONS_MANAGER.py

# Web Search Script: Deep Research für Incidents
# Verwendung: ./websearch-research.ps1 "Beschreibung des Problems"

param(
    [Parameter(Mandatory=$true)]
    [string]$Query,
    
    [string]$OutputDir = "./research"
)

if (-not $env:OPENROUTER_API_KEY) {
    Write-Host "Fehler: OPENROUTER_API_KEY Umgebungsvariable nicht gesetzt"
    exit 1
}

# Erstelle Ausgabeverzeichnis
$null = New-Item -ItemType Directory -Path $OutputDir -Force

# Erstelle Ausgabedatei mit Zeitstempel
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputFile = Join-Path $OutputDir "incident_$timestamp.md"

# Header schreiben
"# Incident Research" | Out-File -FilePath $outputFile -Encoding UTF8
"Datum: $(Get-Date)" | Out-File -FilePath $outputFile -Append -Encoding UTF8
"Query: $Query" | Out-File -FilePath $outputFile -Append -Encoding UTF8
"" | Out-File -FilePath $outputFile -Append -Encoding UTF8

Write-Host "Starte Recherche..."

# 1. EXA für schnelle Recherche
"## 1. Schnelle Recherche (EXA)" | Out-File -FilePath $outputFile -Append -Encoding UTF8

$bodyExa = @{
    model = "openai/gpt-5.4-mini"
    messages = @(@{role = "user"; content = $Query})
    plugins = @(@{id = "web"; engine = "exa"; max_results = 5})
} | ConvertTo-Json -Depth 3

try {
    $responseExa = Invoke-RestMethod -Uri "https://openrouter.ai/api/v1/chat/completions" `
        -Method Post `
        -Headers @{
            Authorization = "Bearer $env:OPENROUTER_API_KEY"
            "Content-Type" = "application/json"
        } `
        -Body $bodyExa
    
    $contentExa = $responseExa.choices[0].message.content
    if ($contentExa) {
        $contentExa | Out-File -FilePath $outputFile -Append -Encoding UTF8
    } else {
        "Keine Ergebnisse" | Out-File -FilePath $outputFile -Append -Encoding UTF8
    }
} catch {
    "Keine Ergebnisse" | Out-File -FilePath $outputFile -Append -Encoding UTF8
}

"" | Out-File -FilePath $outputFile -Append -Encoding UTF8
"---" | Out-File -FilePath $outputFile -Append -Encoding UTF8

# 2. Verifizierte Quellen (Perplexity)
"## 2. Verifizierte Fakten (Perplexity)" | Out-File -FilePath $outputFile -Append -Encoding UTF8

$bodyPerplexity = @{
    model = "perplexity/sonar:online"
    messages = @(@{role = "user"; content = "$Query troubleshooting"})
} | ConvertTo-Json -Depth 3

try {
    $responsePerplexity = Invoke-RestMethod -Uri "https://openrouter.ai/api/v1/chat/completions" `
        -Method Post `
        -Headers @{
            Authorization = "Bearer $env:OPENROUTER_API_KEY"
        } `
        -Body $bodyPerplexity
    
    $contentPerplexity = $responsePerplexity.choices[0].message.content
    if ($contentPerplexity) {
        $contentPerplexity | Out-File -FilePath $outputFile -Append -Encoding UTF8
    } else {
        "Keine Ergebnisse" | Out-File -FilePath $outputFile -Append -Encoding UTF8
    }
} catch {
    "Keine Ergebnisse" | Out-File -FilePath $outputFile -Append -Encoding UTF8
}

"" | Out-File -FilePath $outputFile -Append -Encoding UTF8
"Gespeichert in: $outputFile" | Out-File -FilePath $outputFile -Append -Encoding UTF8

Write-Host "Recherche abgeschlossen: $outputFile"
