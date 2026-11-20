#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "f05f397d3f13657525c9e2bbd183c9eb484e5fa76f95858195557c73f3beb8e3", "source_sha256": "994170e8e95ae7e8bd7564512b31b67821e81c5b77b3b9fd41bad3d0fc2ee46c", "target_language": "powershell"}
# ios-pull-gateway-log.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/dev/ios-pull-gateway-log.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

param(
    [string]$DeviceUDID = "00008130-000630CE0146001C",
    [string]$BundleID = "ai.openclaw.ios.dev.mariano.test",
    [string]$Dest = "/tmp/openclaw-gateway.log"
)

# Kopiere die Logdatei vom iOS-Gerät
& xcrun devicectl device copy from `
    --device $DeviceUDID `
    --domain-type appDataContainer `
    --domain-identifier $BundleID `
    --source Documents/openclaw-gateway.log `
    --destination $Dest | Out-Null

Write-Output "Pulled to: $Dest"

# Zeige die letzten 200 Zeilen der Logdatei an
Get-Content -Path $Dest -Tail 200
