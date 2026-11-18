#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "1ad769f945a19b4a42408f26a772fe3c50ce960b44e18c7122c9cf68aa012a71", "source_sha256": "47740d82dac30833751ad7e0c569c7c084b01b1468243a6aebaf3f4a526f0a93", "target_language": "powershell"}
# pplx-refresh.sh — portiert nach powershell
# Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-refresh.sh
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

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
$ErrorActionPreference = 'Stop'

$HERE = Split-Path -Parent $MyInvocation.MyCommand.Definition
$CFG = if ($env:PERPLEXITY_CONFIG_DIR) { $env:PERPLEXITY_CONFIG_DIR } else { "$HOME/.perplexity-mcp" }
$PROFILE = if ($env:PERPLEXITY_PROFILE) { $env:PERPLEXITY_PROFILE } else { "codespace" }
$COOKIE_FILE = if ($args[0]) { $args[0] } else { "$HOME/pplx-cookies.txt" }

if (-not (Test-Path $COOKIE_FILE) -or (Get-Item $COOKIE_FILE).Length -eq 0) {
    Write-Error "✗ Cookie file empty/missing: $COOKIE_FILE"
    Write-Host "  Export __Secure-next-auth.session-token from your local browser"
    Write-Host "  (DevTools → Application → Cookies → www.perplexity.ai) into that file."
    exit 1
}

# 1. ensure the extension daemon has a usable browser (idempotent)
& bash "$HERE/pplx-setup.sh"

# 2. daemon pid + vault passphrase (never guessed — read from the live daemon)
$LOCK = "$CFG/daemon.lock"
if (-not (Test-Path $LOCK)) {
    Write-Error "✗ no daemon.lock at $LOCK — is the extension running?"
    exit 1
}
$lockContent = Get-Content $LOCK -Raw | ConvertFrom-Json
$PID = $lockContent.pid
if (-not (Get-Process -Id $PID -ErrorAction SilentlyContinue)) {
    Write-Error "✗ daemon pid $PID not running"
    exit 1
}
$proc = Get-Process -Id $PID
$envVars = $proc.StartInfo.Environment
if (-not $envVars.ContainsKey('PERPLEXITY_VAULT_PASSPHRASE')) {
    Write-Error "✗ no PERPLEXITY_VAULT_PASSPHRASE in daemon env"
    exit 1
}
$PASS = $envVars['PERPLEXITY_VAULT_PASSPHRASE']

# 3. locate the perplexity-user-mcp dist (populate npx cache if needed)
$DIST = Get-ChildItem "$HOME/.npm/_npx" -Recurse -Directory -ErrorAction SilentlyContinue | 
        Where-Object { $_.FullName -like "*perplexity-user-mcp*" -and $_.Name -eq "dist" } | 
        Select-Object -First 1 -ExpandProperty FullName
if (-not $DIST) {
    npx -y perplexity-user-mcp --version > $null 2>&1
    $DIST = Get-ChildItem "$HOME/.npm/_npx" -Recurse -Directory -ErrorAction SilentlyContinue | 
            Where-Object { $_.FullName -like "*perplexity-user-mcp*" -and $_.Name -eq "dist" } | 
            Select-Object -First 1 -ExpandProperty FullName
}

# 4. inject
$env:PERPLEXITY_VAULT_PASSPHRASE = $PASS
$env:PERPLEXITY_CONFIG_DIR = $CFG
$env:PERPLEXITY_PROFILE = $PROFILE
$env:PPLX_DIST = $DIST
node "$HERE/pplx-inject.mjs" $COOKIE_FILE

# 5. trigger daemon reinit
[DateTimeOffset]::Now.ToUnixTimeSeconds() > "$CFG/profiles/$PROFILE/.reinit"
Write-Host "→ reinit triggered, waiting for daemon..."

# 6. verify
$STAT = "$CFG/profiles/$PROFILE/daemon-status.json"
for ($i = 1; $i -le 20; $i++) {
    Start-Sleep -Seconds 1.5
    if (Test-Path $STAT) {
        $statusContent = Get-Content $STAT -Raw | ConvertFrom-Json
        $AUTH = $statusContent.authenticated
        $TIER = $statusContent.tier
        if ($AUTH -eq $true) {
            Write-Host "✅ authenticated — tier: $TIER"
            exit 0
        }
    }
}
Write-Host "⚠️  not authenticated yet. Check: tail -20 $CFG/daemon.log"
exit 1
