#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "baa56b8a39ece2e87e67f067280f7351732e89ca7471727a4c47f65b5ddaa003", "source_sha256": "d32ac11e0dc05ad59745834c2a59aec92d846417b8f7f07d0d21d66ae469c743", "target_language": "powershell"}
# pplx-setup.sh — portiert nach powershell
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-setup.sh
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# One-time (idempotent): make sure the Perplexity VS Code extension daemon can
# find a Chromium. The daemon uses its OWN bundled patchright, which pins a
# specific chromium revision; install exactly that revision.
$ErrorActionPreference = 'Stop'

$extpr = Get-ChildItem -Path "$env:USERPROFILE/.vscode-remote/extensions/nskha.perplexity-vscode-*/dist/node_modules/patchright" -Directory -ErrorAction SilentlyContinue | 
    Sort-Object { [version]$_.Name } | 
    Select-Object -Last 1

if (-not $extpr) {
    Write-Host "[setup] extension patchright not found — is the Perplexity extension installed?"
    exit 0
}

try {
    $exp = node -e "const {chromium}=require('$($extpr.FullName)');console.log(chromium.executablePath())" 2>$null
} catch {
    $exp = $null
}

if ($exp -and (Test-Path $exp)) {
    Write-Host "[setup] daemon browser already present: $exp"
    exit 0
}

Write-Host "[setup] installing matching chromium for the extension daemon (expected: $(if ($exp) { $exp } else { 'unknown' }))"
node "$($extpr.FullName)/cli.js" install chromium
Write-Host "[setup] done."
