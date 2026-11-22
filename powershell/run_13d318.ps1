#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "c15a0f0c0d818b29a26a8b74fc47516487a357423e4520ba2a72c2f97417172a", "source_sha256": "13d3188a43593fc462e34986e11913f715c38d3ec54128b71ba71024d5419be6", "target_language": "powershell"}
# run.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/cleanup-smoke/run.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

Set-Location /repo

$env:OPENCLAW_STATE_DIR = "/tmp/openclaw-test"
$env:OPENCLAW_CONFIG_PATH = "$env:OPENCLAW_STATE_DIR/openclaw.json"

Write-Host "==> Build"
if (!(pnpm build > /tmp/openclaw-cleanup-build.log 2>&1)) {
  Get-Content /tmp/openclaw-cleanup-build.log
  exit 1
}

Write-Host "==> Seed state"
New-Item -ItemType Directory -Path "$env:OPENCLAW_STATE_DIR/credentials" -Force
New-Item -ItemType Directory -Path "$env:OPENCLAW_STATE_DIR/agents/main/sessions" -Force
Set-Content -Path $env:OPENCLAW_CONFIG_PATH -Value "{}"
Set-Content -Path "$env:OPENCLAW_STATE_DIR/credentials/marker.txt" -Value "creds"
Set-Content -Path "$env:OPENCLAW_STATE_DIR/agents/main/sessions/sessions.json" -Value "session"

Write-Host "==> Reset (config+creds+sessions)"
if (!(pnpm openclaw reset --scope config+creds+sessions --yes --non-interactive > /tmp/openclaw-cleanup-reset.log 2>&1)) {
  Get-Content /tmp/openclaw-cleanup-reset.log
  exit 1
}

if (Test-Path $env:OPENCLAW_CONFIG_PATH) {
  Write-Error "Config file still exists"
  exit 1
}
if (Test-Path "$env:OPENCLAW_STATE_DIR/credentials") {
  Write-Error "Credentials directory still exists"
  exit 1
}
if (Test-Path "$env:OPENCLAW_STATE_DIR/agents/main/sessions") {
  Write-Error "Sessions directory still exists"
  exit 1
}

Write-Host "==> Recreate minimal config"
New-Item -ItemType Directory -Path "$env:OPENCLAW_STATE_DIR/credentials" -Force
Set-Content -Path $env:OPENCLAW_CONFIG_PATH -Value "{}"

Write-Host "==> Uninstall (state only)"
if (!(pnpm openclaw uninstall --state --yes --non-interactive > /tmp/openclaw-cleanup-uninstall.log 2>&1)) {
  Get-Content /tmp/openclaw-cleanup-uninstall.log
  exit 1
}

if (Test-Path $env:OPENCLAW_STATE_DIR) {
  Write-Error "State directory still exists"
  exit 1
}

Write-Host "OK"
