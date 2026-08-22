#!/usr/bin/env pwsh
# pplx-refresh.sh — portiert nach powershell
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-refresh.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Refresh the codespace Perplexity session from a locally-exported cookie.
#
# Usage:
#   ./pplx-refresh.ps1 [cookie-file]
#
# cookie-file defaults to ~/pplx-cookies.txt. Put your local browser's
# __Secure-next-auth.session-token value (raw), or the whole Cookie header,
# or a JSON cookie export, into that file first.
#
# Steps: ensure daemon browser -> read daemon passphrase -> inject into vault
#        -> trigger reinit -> verify authenticated.

$ErrorActionPreference = "Stop"

$HERE = Split-Path $MyInvocation.MyCommand.Path -Parent
$CFG = if ($env:PERPLEXITY_CONFIG_DIR) { $env:PERPLEXITY_CONFIG_DIR } else { Join-Path $HOME ".perplexity-mcp" }
$PROFILE_NAME = if ($env:PERPLEXITY_PROFILE) { $env:PERPLEXITY_PROFILE } else { "codespace" }

$COOKIE_FILE = if ($args.Count -gt 0) { $args[0] } else { Join-Path $HOME "pplx-cookies.txt" }

if (-not (Test-Path $COOKIE_FILE -PathType Leaf) -or (Get-Item $COOKIE_FILE).Length -eq 0) {
    Write-Host "✗ Cookie file empty/missing: $COOKIE_FILE"
    Write-Host "  Export __Secure-next-auth.session-token from your local browser"
    Write-Host "  (DevTools → Application → Cookies → www.perplexity.ai) into that file."
    exit 1
}

# 1. ensure the extension daemon has a usable browser (idempotent)
& "$HERE/pplx-setup.sh"

# 2. daemon pid + vault passphrase (never guessed — read from the live daemon)
$LOCK = Join-Path $CFG "daemon.lock"
if (-not (Test-Path $LOCK)) {
    Write-Host "✗ no daemon.lock at $LOCK — is the extension running?"
    exit 1
}

$lockContent = Get-Content $LOCK -Raw | ConvertFrom-Json
$PID = $lockContent.pid

if (-not (Get-Process -Id $PID -ErrorAction SilentlyContinue)) {
    Write-Host "✗ daemon pid $PID not running"
    exit 1
}

# Read environment variables from process on Linux (via /proc/$PID/environ)
# This is Linux-specific and won't work on Windows/macOS
if ($IsLinux) {
    $environPath = "/proc/$PID/environ"
    if (Test-Path $environPath) {
        $envBytes = [System.IO.File]::ReadAllBytes($environPath)
        $envString = [System.Text.Encoding]::ASCII.GetString($envBytes)
        $envVars = $envString -split "`0"
        $passEntry = $envVars | Where-Object { $_ -like "PERPLEXITY_VAULT_PASSPHRASE=*" }
        if ($passEntry) {
            $PASS = ($passEntry -split "=", 2)[1]
        } else {
            Write-Host "✗ no PERPLEXITY_VAULT_PASSPHRASE in daemon env"
            exit 1
        }
    } else {
        Write-Host "✗ Cannot access /proc/$PID/environ"
        exit 1
    }
} else {
    Write-Host "✗ This script requires Linux /proc filesystem to read daemon environment"
    exit 1
}

# 3. locate the perplexity-user-mcp dist (populate npx cache if needed)
$DIST = ""
$npxPaths = Get-ChildItem -Path "$HOME/.npm/_npx" -Recurse -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -like "*perplexity-user-mcp/dist" } |
            Select-Object -First 1

if ($npxPaths) {
    $DIST = $npxPaths.FullName
}

if (-not $DIST) {
    # Try to populate npx cache
    try {
        npx -y perplexity-user-mcp --version >$null 2>&1
    } catch {
        # ignore errors
    }

    $npxPaths = Get-ChildItem -Path "$HOME/.npm/_npx" -Recurse -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -like "*perplexity-user-mcp/dist" } |
                Select-Object -First 1

    if ($npxPaths) {
        $DIST = $npxPaths.FullName
    }
}

# 4. inject
$env:PERPLEXITY_VAULT_PASSPHRASE = $PASS
$env:PERPLEXITY_CONFIG_DIR = $CFG
$env:PERPLEXITY_PROFILE = $PROFILE_NAME
$env:PPLX_DIST = $DIST
node "$HERE/pplx-inject.mjs" "$COOKIE_FILE"
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# 5. trigger daemon reinit
$reinitFile = Join-Path $CFG "profiles/$PROFILE_NAME/.reinit"
[DateTime]::UtcNow.ToUnixTimeSeconds().ToString() > $reinitFile
Write-Host "→ reinit triggered, waiting for daemon..."

# 6. verify
$STAT = Join-Path $CFG "profiles/$PROFILE_NAME/daemon-status.json"
for ($i = 1; $i -le 20; $i++) {
    Start-Sleep -Seconds 1.5
    $AUTH = ""
    $TIER = ""
    try {
        if (Test-Path $STAT) {
            $statData = Get-Content $STAT -Raw | ConvertFrom-Json
            $AUTH = $statData.authenticated
            $TIER = $statData.tier
        }
    } catch {
        # ignore parse errors
    }

    if ($AUTH -eq $true) {
        Write-Host "✅ authenticated — tier: $TIER"
        exit 0
    }
}
Write-Host "⚠️  not authenticated yet. Check: tail -20 $CFG/daemon.log"
exit 1
