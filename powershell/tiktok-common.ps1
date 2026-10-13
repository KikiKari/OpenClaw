#!/usr/bin/env pwsh
# tiktok-common.js — portiert nach powershell
# Quelle: javascript, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/tiktok-common.js
# Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

# Reuse the basic skill's normalization, load, selector, URL, and result
# contract so both extractors classify identical inputs consistently.
$scriptPath = Join-Path $PSScriptRoot '../../tiktok-live/scripts/tiktok-common.ps1'
if (Test-Path $scriptPath) {
    . $scriptPath
} else {
    throw "Required script not found: $scriptPath"
}
