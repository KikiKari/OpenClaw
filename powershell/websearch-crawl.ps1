#!/usr/bin/env pwsh
# websearch-crawl.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:scripts/websearch-crawl.sh
# auch in: OpenClaw@gateway2:scripts/websearch-crawl.sh
# Erzeugt: 2026-10-24 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Web Search Script: Website Crawling mit Firecrawl
.DESCRIPTION
Startet einen Crawlvorgang auf einer Webseite über die Firecrawl-API und speichert das Ergebnis.
.PARAMETER WebsiteUrl
Die URL der zu crawlenden Webseite.
.PARAMETER OutputDir
Optionales Ausgabeverzeichnis (Standard: ./crawled).
.EXAMPLE
./websearch-crawl.ps1 https://beispiel.de ./ergebnisse
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$WebsiteUrl,
    
    [string]$OutputDir = "./crawled"
)

# API-Key ermitteln
$firecrawlApiKey = $env:FIRECRAWL_API_KEY
if (-not $firecrawlApiKey) {
    $openClawEnvPath = Join-Path $HOME ".openclaw" "openclaw.env"
    if (Test-Path $openClawEnvPath) {
        $content = Get-Content $openClawEnvPath
        $openRouterLine = $content | Where-Object { $_ -match 'OPENROUTER' }
        if ($openRouterLine) {
            $firecrawlApiKey = ($openRouterLine -split '"')[1]
        }
    }
}

if (-not $firecrawlApiKey) {
    Write-Error "FIRECRAWL_API_KEY nicht gefunden"
    exit 1
}

# Ausgabeverzeichnis erstellen
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
Write-Host "Crawling $WebsiteUrl..."

# Crawl starten
$body = @{
    url = $WebsiteUrl
    limit = 100
    scrapeOptions = @{ formats = @("markdown") }
} | ConvertTo-Json

$headers = @{
    Authorization = "Bearer $firecrawlApiKey"
    "Content-Type" = "application/json"
}

try {
    $response = Invoke-RestMethod -Uri "https://api.firecrawl.dev/v1/crawl" -Method Post -Headers $headers -Body $body
    $crawlId = $response.id
    
    if (-not $crawlId) {
        Write-Error "Fehler: Crawl konnte nicht gestartet werden"
        $response | ConvertTo-Json -Depth 10
        exit 1
    }
    
    Write-Host "Crawl ID: $crawlId"
    
    # Status prüfen
    while ($true) {
        $statusResponse = Invoke-RestMethod -Uri "https://api.firecrawl.dev/v1/crawl/$crawlId" -Headers @{Authorization = "Bearer $firecrawlApiKey"}
        $status = $statusResponse.status
        
        if (-not $status) { $status = "unknown" }
        
        Write-Host "Status: $status"
        
        if ($status -eq "completed") {
            $outputFile = Join-Path $OutputDir "$(Get-Date -Format 'yyyyMMdd')_crawl.json"
            $statusResponse | ConvertTo-Json -Depth 10 | Set-Content $outputFile
            Write-Host "Gespeichert in $OutputDir"
            break
        }
        elseif ($status -eq "failed") {
            Write-Error "Crawl fehlgeschlagen"
            exit 1
        }
        
        Start-Sleep -Seconds 5
    }
}
catch {
    Write-Error "API-Fehler: $($_.Exception.Message)"
    exit 1
}
