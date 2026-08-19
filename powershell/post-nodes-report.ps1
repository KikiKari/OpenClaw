#!/usr/bin/env pwsh
# post-nodes-report.js — portiert nach powershell
# Quelle: javascript, OpenClaw@gateway1:scripts/post-nodes-report.js
# auch in: OpenClaw@gateway2:scripts/post-nodes-report.js
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# Pfade
$DASHBOARD_PATH = Join-Path $PSScriptRoot "../dashboards/nodes-overview.md"
$REPORT_LOG = Join-Path $PSScriptRoot "../logs/nodes-report.log"

# Farbcodes
$C = @{
  green = "`e[32m"
  yellow = "`e[33m"
  red = "`e[31m"
  reset = "`e[0m"
}

function Post-Report {
  try {
    $content = Get-Content -Path $DASHBOARD_PATH -Raw -ErrorAction Stop
  } catch {
    Write-Error "$($C.red)❌ Fehler beim Lesen der Dashboard-Datei:$($C.reset) $($_.Exception.Message)"
    return
  }

  # Nachricht über OpenClaw message senden
  # Entferne Zeilenumbrüche und maskiere sie für die Shell
  $escapedContent = $content -replace '`n', '\\n' -replace '"', '\"'
  $messageCmd = "openclaw message send --target=main --message `"$escapedContent`""

  try {
    Invoke-Expression $messageCmd | Out-Null
    Write-Host "$($C.green)✅ Report erfolgreich im 'main'-Channel gepostet.$($C.reset)"
    "$([System.DateTime]::UtcNow.ToString('o')) Report posted." | Add-Content -Path $REPORT_LOG
  } catch {
    $errorMessage = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $_.Exception.Message }
    Write-Error "$($C.red)❌ Fehler beim Senden der Nachricht:$($C.reset) $errorMessage"
    "$([System.DateTime]::UtcNow.ToString('o')) Failed to post: $errorMessage" | Add-Content -Path $REPORT_LOG
  }
}

# Hauptausführung
Write-Host "$($C.yellow)📤 Sende Nodes-Übersicht in 'main'...$($C.reset)"
Post-Report
