#!/usr/bin/env pwsh
# pplx-setup.sh — portiert nach powershell
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-setup.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# One-time (idempotent): make sure the Perplexity VS Code extension daemon can
# find a Chromium. The daemon uses its OWN bundled patchright, which pins a
# specific chromium revision; install exactly that revision.
$ErrorActionPreference = 'Stop'

$extprDirs = Get-ChildItem -Path "$env:HOME/.vscode-remote/extensions/nskha.perplexity-vscode-*" -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path "$($_.FullName)/dist/node_modules/patchright" } |
    Sort-Object { [version]$_.Name.Split('-')[-1] }

if ($extprDirs.Count -eq 0) {
    Write-Host "[setup] extension patchright not found — is the Perplexity extension installed?"
    exit 0
}

$EXTPR = $extprDirs[-1].FullName + "/dist/node_modules/patchright"

try {
    $EXP = node -e "const {chromium}=require('$EXTPR');console.log(chromium.executablePath())" 2>$null
} catch {
    $EXP = $null
}

if ($EXP -and (Test-Path $EXP)) {
    Write-Host "[setup] daemon browser already present: $EXP"
    exit 0
}

Write-Host "[setup] installing matching chromium for the extension daemon (expected: $($EXP ?? 'unknown'))..."
node "$EXTPR/cli.js" install chromium
Write-Host "[setup] done."
