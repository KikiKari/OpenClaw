#!/usr/bin/env pwsh
# ABSTRACTIONS_MANAGER.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway2:skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
# Erzeugt: 2026-08-08 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Skill-Einstieg fuer den kanonischen Abstractions Manager.
#>

$KANONISCHER_MANAGER = "/home/openclaw/.openclaw/workspace/abstractions/ABSTRACTIONS_MANAGER.py"

if (-not (Test-Path $KANONISCHER_MANAGER -PathType Leaf)) {
    Write-Error "Kanonischer Abstractions Manager fehlt: $KANONISCHER_MANAGER"
    exit 1
}

python3 $KANONISCHER_MANAGER
