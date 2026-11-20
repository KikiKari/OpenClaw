#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "ae38b660cd7e38d29729249b3519d248a425a0804096a152a1d546c8b1874df7", "source_sha256": "ed82b1410f121f3b1436d54099143d7010035ba702c64f21d2669fce9dd3f2ae", "target_language": "powershell"}
# format.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/Swabble/scripts/format.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"
$ROOT = (Resolve-Path "$PSScriptRoot/..").Path
$CONFIG = "$ROOT/.swiftformat"
if (-not (Get-Command swiftformat -ErrorAction SilentlyContinue)) {
    Write-Error "swiftformat command not found"
    exit 1
}
swiftformat --config "$CONFIG" "$ROOT/Sources"
