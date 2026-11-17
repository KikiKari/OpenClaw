#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "5e0938b489b35f433ca0bf2f871484fb6fd2d2f3a18e274c22455923a02317c4", "source_sha256": "8621f6f7e524474de82b3d877ee62bbcbd9fa3b247b69c437b063b71fa995f5a", "target_language": "powershell"}
# ops-hub-heartbeat.js — portiert nach powershell
# Quelle: javascript, OpenClaw@gateway1:scripts/ops-hub-heartbeat.js
# auch in: OpenClaw@gateway2:scripts/ops-hub-heartbeat.js
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# Aktualisiere den Statusbericht mit aktueller Zeit
$statusPath = Join-Path $PSScriptRoot "../docs/ops-hub/status.md"

function Update-Heartbeat {
    try {
        $content = Get-Content -Path $statusPath -Encoding UTF8 -Raw
    } catch {
        Write-Error "❌ Konnte status.md nicht lesen: $($_.Exception.Message)"
        return
    }

    $now = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
    $updated = $content -replace "(Letzter Heartbeat:) .*$", "`$1 $now"

    try {
        Set-Content -Path $statusPath -Value $updated -Encoding UTF8
        Write-Host "✅ Heartbeat aktualisiert: $now"
    } catch {
        Write-Error "❌ Konnte status.md nicht schreiben: $($_.Exception.Message)"
    }
}

Update-Heartbeat
