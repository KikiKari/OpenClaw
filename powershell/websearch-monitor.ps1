#!/usr/bin/env pwsh
# websearch-monitor.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:scripts/websearch-monitor.sh
# auch in: OpenClaw@gateway2:scripts/websearch-monitor.sh
# Erzeugt: 2026-10-24 durch ABSTRACTIONS_MANAGER.py

<#
Web Search Script: Server-Monitoring mit Tavily
Verwendung: ./websearch-monitor.sh [TOPIC]
#>

param(
    [string]$Topic = "Linux kernel security updates"
)

# Security-News prüfen
Write-Output "Prüfe: $Topic"

# Versuche zuerst Tavily CLI
$tvlyExists = Get-Command tvly -ErrorAction SilentlyContinue

if ($tvlyExists) {
    $result = tvly search $Topic --topic news --time-range week --max-results 5 --include-answer advanced 2>$null
    
    if ($LASTEXITCODE -eq 0 -and $result) {
        $jsonResult = $result | ConvertFrom-Json
        if ($jsonResult.answer) {
            Write-Output $jsonResult.answer
        } else {
            Write-Output "Keine Zusammenfassung verfügbar"
        }
    } else {
        Write-Output "Keine Zusammenfassung verfügbar"
    }
} else {
    # Fallback zu einfacher Web-Suche
    try {
        $encodedTopic = [uri]::EscapeDataString($Topic)
        $response = Invoke-RestMethod -Uri "http://localhost:8888/search?q=$encodedTopic&format=json" -ErrorAction Stop
        
        if ($response.results) {
            $results = $response.results | Select-Object -First 3
            foreach ($item in $results) {
                Write-Output "$($item.title)"
                Write-Output "$($item.url)"
            }
        } else {
            Write-Output "SearXNG nicht verfügbar"
        }
    } catch {
        Write-Output "SearXNG nicht verfügbar"
    }
}
