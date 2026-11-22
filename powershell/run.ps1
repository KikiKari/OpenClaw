#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "8622fcaab4207347a7d1ca713bf03cd4652709f4d89728b6351abbaf9e9d039b", "source_sha256": "9bab70cc20775da1defcfadbbbef9ceb0f983a51d1a3988a76a20843d64c8471", "target_language": "powershell"}
# run.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/install-sh-nonroot/run.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = 'Stop'

$INSTALL_URL = if ($env:OPENCLAW_INSTALL_URL) { $env:OPENCLAW_INSTALL_URL } else { "https://openclaw.bot/install.sh" }
$DEFAULT_PACKAGE = "openclaw"
$PACKAGE_NAME = if ($env:OPENCLAW_INSTALL_PACKAGE) { $env:OPENCLAW_INSTALL_PACKAGE } else { $DEFAULT_PACKAGE }
$SCRIPT_DIR = Split-Path $MyInvocation.MyCommand.Path -Parent

# Source cli-verify.sh equivalent
. "$SCRIPT_DIR/../install-sh-common/cli-verify.ps1"

Write-Host "==> Pre-flight: ensure git absent"
if (Get-Command git -ErrorAction SilentlyContinue) {
  Write-Error "git is present unexpectedly"
  exit 1
}

Write-Host "==> Pre-flight: ensure supported Node is already present"
node -e @'
  const version = process.versions.node.split(".").map(Number);
  const ok =
    version.length >= 2 &&
    (version[0] > 22 || (version[0] === 22 && version[1] >= 16));
  if (!ok) {
    process.stderr.write(`unsupported node ${process.versions.node}\n`);
    process.exit(1);
  }
'@

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
  throw "npm not found"
}

Write-Host "==> Run installer (non-root user)"
curl -fsSL $INSTALL_URL | bash

# Ensure PATH picks up user npm prefix
$env:PATH = "$env:HOME/.npm-global/bin;$env:PATH"

Write-Host "==> Verify git installed"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "git not installed"
}

$EXPECTED_VERSION = if ($env:OPENCLAW_INSTALL_EXPECT_VERSION) { $env:OPENCLAW_INSTALL_EXPECT_VERSION } else { "" }
if ($EXPECTED_VERSION -ne "") {
  $LATEST_VERSION = $EXPECTED_VERSION
} else {
  $LATEST_VERSION = quiet_npm view $PACKAGE_NAME version
}

Write-Host "==> Verify CLI installed"
verify_installed_cli $PACKAGE_NAME $LATEST_VERSION

Write-Host "OK"
