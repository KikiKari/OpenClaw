#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "f88db86249c5739bc73ecc846278eba49349416b6c38a45b0abc81cf33c1a605", "source_sha256": "04afaeaf031d1de3a9c71606dba8c1d6ea78b3b575d8ecf94af9256d4dc3886d", "target_language": "powershell"}
# post-nodes-report.js — portiert nach powershell
# Quelle: javascript, OpenClaw@gateway1:scripts/post-nodes-report.js
# auch in: OpenClaw@gateway2:scripts/post-nodes-report.js
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Pfade
$DASHBOARD_PATH = Join-Path (Split-Path $PSScriptRoot -Parent) "dashboards/nodes-overview.md"
$REPORT_LOG = Join-Path (Split-Path $PSScriptRoot -Parent) "logs/nodes-report.log"

# Farbcodes
$C = @{
    green = "`e[32m"
    yellow = "`e[33m"
    red = "`e[31m"
    reset = "`e[0m"
}

function Post-Report {
    $content = $null
    try {
        $content = Get-Content -Path $DASHBOARD_PATH -Raw -Encoding UTF8
    }
    catch {
        Write-Error "$($C.red)❌ Fehler beim Lesen der Dashboard-Datei:$($C.reset) $($_.Exception.Message)"
        return
    }

    # Nachricht über OpenClaw message senden
    $escapedContent = $content -replace "`n", "\n" -replace "`r", ""
    $messageCmd = "openclaw", "message", "send", "--target=main", "--message", $escapedContent

    try {
        $result = & @messageCmd 2>&1
        Write-Host "$($C.green)✅ Report erfolgreich im 'main'-Channel gepostet.$($C.reset)"
        Add-Content -Path $REPORT_LOG -Value "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')] Report posted."
    }
    catch {
        $errorMsg = if ($_.Exception -is [System.Management.Automation.RemoteException]) {
            $_.Exception.Message
        }
        else {
            $_.Exception.Message
        }
        Write-Error "$($C.red)❌ Fehler beim Senden der Nachricht:$($C.reset) $errorMsg"
        Add-Content -Path $REPORT_LOG -Value "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ')] Failed to post: $($_.Exception.Message)"
    }
}

# Hauptausführung
Write-Host "$($C.yellow)📤 Sende Nodes-Übersicht in 'main'...$($C.reset)"
Post-Report
