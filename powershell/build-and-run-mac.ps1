#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "374b7cd79d6fe89746779b07a3f6f080274f049fd5df72a115006edc87cc791f", "source_sha256": "fe4cfd779f66ea7706f9bdfe3744e5d0a5b102609de3aca3ad086e40c76e8a2f", "target_language": "powershell"}
# build-and-run-mac.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/build-and-run-mac.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"
Set-Location "$(Split-Path $MyInvocation.MyCommand.Path)/../apps/macos"

$BUILD_PATH = ".build-local"
$PRODUCT = "OpenClaw"
$BIN = "$BUILD_PATH/debug/$PRODUCT"

Write-Host "`n▶️  Building $PRODUCT (debug, build path: $BUILD_PATH)"
swift build -c debug --product "$PRODUCT" --build-path "$BUILD_PATH"

Write-Host "`n⏹  Stopping existing $PRODUCT..."
Get-Process -Name "$PRODUCT" -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host "`n🚀 Launching $BIN ..."
Start-Process -FilePath "$BIN" -NoNewWindow -RedirectStandardOutput "/tmp/openclaw.log" -RedirectStandardError "/tmp/openclaw.log" -PassThru
$PID = (Get-Job -Tail 1).Id
Write-Host "Started $PRODUCT. Logs: /tmp/openclaw.log"
