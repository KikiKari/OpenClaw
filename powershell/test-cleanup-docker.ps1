#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "f2b223670c96504ee07317ef08e2552409a544f0ae2afbbd45e2cb1b58d74df0", "source_sha256": "df77fd3273a53bf6d33c1c4df50c24d9526e06de477779a9b7a58f5b8ce3ed1d", "target_language": "powershell"}
# test-cleanup-docker.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/test-cleanup-docker.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ROOT_DIR = Resolve-Path "$scriptDir/.."

# Source the docker-e2e-logs.sh functionality
. "$ROOT_DIR/scripts/lib/docker-e2e-logs.ps1"

$IMAGE_NAME = if ($env:OPENCLAW_CLEANUP_SMOKE_IMAGE) { $env:OPENCLAW_CLEANUP_SMOKE_IMAGE } else { "openclaw-cleanup-smoke:local" }
$PLATFORM = if ($env:OPENCLAW_CLEANUP_SMOKE_PLATFORM) { $env:OPENCLAW_CLEANUP_SMOKE_PLATFORM } else { "linux/amd64" }

Write-Host "==> Build image: $IMAGE_NAME"
run_logged "cleanup-build" @( "docker", "build", "-t", $IMAGE_NAME, "-f", "$ROOT_DIR/scripts/docker/cleanup-smoke/Dockerfile", $ROOT_DIR )

Write-Host "==> Run cleanup smoke test"
docker run --rm --platform $PLATFORM -t $IMAGE_NAME
