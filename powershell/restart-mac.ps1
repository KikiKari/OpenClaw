#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "a29315bfd014a8f3156b2321558870a19909d42a305d054e45215c78dc879982", "source_sha256": "fbf046d1988d19407db864ee85d468151b410a1dc1cab4374f1f8119c6fb9897", "target_language": "powershell"}
# restart-mac.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/restart-mac.sh
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
Reset OpenClaw like Trimmy: kill running instances, rebuild, repackage, relaunch, verify.

.DESCRIPTION
This script performs a full reset of OpenClaw by killing existing processes,
rebuilding the application, repackaging it, and launching it again.

.PARAMETER Wait
Wait for other restart to complete instead of exiting.

.PARAMETER NoSign
Force no code signing (fastest for development).

.PARAMETER Sign
Force code signing (will fail if no signing key available).

.PARAMETER AttachOnly
Launch app with --attach-only (skip launchd install).

.PARAMETER NoAttachOnly
Launch app without attach-only override.

.PARAMETER Help
Show help information.
#>

param(
    [switch]$Wait,
    [switch]$NoSign,
    [switch]$Sign,
    [switch]$AttachOnly = $true,
    [switch]$NoAttachOnly,
    [switch]$Help
)

# Helper functions
function Write-Log {
    param([string]$Message)
    Write-Output $Message
}

function Write-Fail {
    param([string]$Message)
    Write-Error "ERROR: $Message" -ErrorAction Stop
}

# Show help if requested
if ($Help) {
    Write-Log "Usage: $($MyInvocation.MyCommand.Name) [-Wait] [-NoSign] [-Sign] [-AttachOnly|-NoAttachOnly]"
    Write-Log "  -Wait           Wait for other restart to complete instead of exiting"
    Write-Log "  -NoSign         Force no code signing (fastest for development)"
    Write-Log "  -Sign           Force code signing (will fail if no signing key available)"
    Write-Log "  -AttachOnly     Launch app with --attach-only (skip launchd install)"
    Write-Log "  -NoAttachOnly   Launch app without attach-only override"
    Write-Log ""
    Write-Log "Env:"
    Write-Log "  OPENCLAW_GATEWAY_WAIT_SECONDS=0  Wait time before gateway port check (unsigned only)"
    Write-Log ""
    Write-Log "Unsigned recovery:"
    Write-Log "  node openclaw.mjs daemon install --force --runtime node"
    Write-Log "  node openclaw.mjs daemon restart"
    Write-Log ""
    Write-Log "Reset unsigned overrides:"
    Write-Log "  rm ~/.openclaw/disable-launchagent"
    Write-Log ""
    Write-Log "Default behavior: Auto-detect signing keys, fallback to --no-sign if none found"
    exit 0
}

# Validate conflicting parameters
if ($NoSign -and $Sign) {
    Write-Fail "Cannot use -Sign and -NoSign together"
}

# Set variables similar to bash script
$ROOT_DIR = Join-Path $PSScriptRoot ".." | Resolve-Path
$APP_BUNDLE = if ($env:OPENCLAW_APP_BUNDLE) { $env:OPENCLAW_APP_BUNDLE } else { "" }
$APP_PROCESS_PATTERN = "OpenClaw.app/Contents/MacOS/OpenClaw"
$DEBUG_PROCESS_PATTERN = Join-Path $ROOT_DIR "apps/macos/.build/debug/OpenClaw"
$LOCAL_PROCESS_PATTERN = Join-Path $ROOT_DIR "apps/macos/.build-local/debug/OpenClaw"
$RELEASE_PROCESS_PATTERN = Join-Path $ROOT_DIR "apps/macos/.build/release/OpenClaw"
$LAUNCH_AGENT = Join-Path $env:HOME "Library/LaunchAgents/ai.openclaw.mac.plist"
$LOCK_KEY = (Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($ROOT_DIR))) -Algorithm SHA256).Hash.Substring(0,8)
$LOCK_DIR = Join-Path (if ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }) "openclaw-restart-$LOCK_KEY"
$LOCK_PID_FILE = Join-Path $LOCK_DIR "pid"
$WAIT_FOR_LOCK = if ($Wait) { 1 } else { 0 }
$LOG_PATH = if ($env:OPENCLAW_RESTART_LOG) { $env:OPENCLAW_RESTART_LOG } else { "/tmp/openclaw-restart.log" }
$NO_SIGN = if ($NoSign) { 1 } else { 0 }
$SIGN = if ($Sign) { 1 } else { 0 }
$AUTO_DETECT_SIGNING = if ($NoSign -or $Sign) { 0 } else { 1 }
$GATEWAY_WAIT_SECONDS = if ($env:OPENCLAW_GATEWAY_WAIT_SECONDS) { [int]$env:OPENCLAW_GATEWAY_WAIT_SECONDS } else { 0 }
$LAUNCHAGENT_DISABLE_MARKER = Join-Path $env:HOME ".openclaw/disable-launchagent"
$ATTACH_ONLY = if ($NoAttachOnly) { 0 } else { 1 }

# Ensure local node binaries are discoverable
$env:PATH = "$ROOT_DIR/node_modules/.bin:$env:PATH"

function Run-Step {
    param(
        [string]$Label,
        [scriptblock]$ScriptBlock
    )
    
    Write-Log "==> $Label"
    try {
        & $ScriptBlock
    } catch {
        Write-Fail "$Label failed"
    }
}

function Cleanup {
    if (Test-Path $LOCK_DIR) {
        Remove-Item -Recurse -Force $LOCK_DIR -ErrorAction SilentlyContinue
    }
}

function Acquire-Lock {
    while ($true) {
        try {
            New-Item -ItemType Directory -Path $LOCK_DIR -ErrorAction Stop | Out-Null
            Set-Content -Path $LOCK_PID_FILE -Value $PID
            return
        } catch {
            # Directory already exists
        }

        $existing_pid = ""
        if (Test-Path $LOCK_PID_FILE) {
            $existing_pid = Get-Content $LOCK_PID_FILE -ErrorAction SilentlyContinue
        }

        if ($existing_pid -and (Get-Process -Id $existing_pid -ErrorAction SilentlyContinue)) {
            if ($WAIT_FOR_LOCK -eq 1) {
                Write-Log "==> Another restart is running (pid $existing_pid); waiting..."
                while (Get-Process -Id $existing_pid -ErrorAction SilentlyContinue) {
                    Start-Sleep -Seconds 1
                }
                continue
            }
            Write-Log "==> Another restart is running (pid $existing_pid); re-run with --wait."
            exit 0
        }

        Remove-Item -Recurse -Force $LOCK_DIR -ErrorAction SilentlyContinue
    }
}

function Check-SigningKeys {
    try {
        $result = security find-identity -p codesigning -v 2>$null
        return $result -match "(Developer ID Application|Apple Distribution|Apple Development)"
    } catch {
        return $false
    }
}

# Register cleanup handler
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Forward -Action { Cleanup } | Out-Null

# Setup logging
New-Item -ItemType Directory -Path (Split-Path $LOG_PATH -Parent) -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item -Force $LOG_PATH -ErrorAction SilentlyContinue
Start-Transcript -Path $LOG_PATH -Append | Out-Null
Write-Log "==> Log: $LOG_PATH"
if ($NO_SIGN -eq 1) {
    Write-Log "==> Using --no-sign (unsigned flow enabled)"
}
if ($ATTACH_ONLY -eq 1) {
    Write-Log "==> Using --attach-only (skip launchd install)"
}

Acquire-Lock

function Kill-AllOpenClaw {
    for ($i = 1; $i -le 10; $i++) {
        Get-Process | Where-Object { $_.Path -like "*$APP_PROCESS_PATTERN*" } | Stop-Process -Force -ErrorAction SilentlyContinue
        Get-Process | Where-Object { $_.Path -like "*$DEBUG_PROCESS_PATTERN*" } | Stop-Process -Force -ErrorAction SilentlyContinue
        Get-Process | Where-Object { $_.Path -like "*$LOCAL_PROCESS_PATTERN*" } | Stop-Process -Force -ErrorAction SilentlyContinue
        Get-Process | Where-Object { $_.Path -like "*$RELEASE_PROCESS_PATTERN*" } | Stop-Process -Force -ErrorAction SilentlyContinue
        Get-Process -Name "OpenClaw" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        
        $stillRunning = $false
        try {
            if ((Get-Process | Where-Object { $_.Path -like "*$APP_PROCESS_PATTERN*" }).Count -gt 0) { $stillRunning = $true }
            if ((Get-Process | Where-Object { $_.Path -like "*$DEBUG_PROCESS_PATTERN*" }).Count -gt 0) { $stillRunning = $true }
            if ((Get-Process | Where-Object { $_.Path -like "*$LOCAL_PROCESS_PATTERN*" }).Count -gt 0) { $stillRunning = $true }
            if ((Get-Process | Where-Object { $_.Path -like "*$RELEASE_PROCESS_PATTERN*" }).Count -gt 0) { $stillRunning = $true }
            if ((Get-Process -Name "OpenClaw" -ErrorAction SilentlyContinue).Count -gt 0) { $stillRunning = $true }
        } catch {
            # Ignore errors
        }
        
        if (-not $stillRunning) {
            return
        }
        Start-Sleep -Milliseconds 300
    }
}

function Stop-LaunchAgent {
    try {
        launchctl bootout gui/"$env:UID"/ai.openclaw.mac 2>$null
    } catch {
        # Ignore errors
    }
}

# 1) Kill all running instances first.
Write-Log "==> Killing existing OpenClaw instances"
Kill-AllOpenClaw
Stop-LaunchAgent

# Bundle Gateway-hosted Canvas A2UI assets.
Run-Step "bundle canvas a2ui" { 
    bash -lc "cd '$ROOT_DIR' && pnpm canvas:a2ui:bundle" 
}

# 2) Rebuild into the same path the packager consumes (.build).
Run-Step "clean build cache" { 
    bash -lc "cd '$ROOT_DIR/apps/macos' && rm -rf .build .build-swift .swiftpm 2>/dev/null || true" 
}
Run-Step "swift build" { 
    bash -lc "cd '$ROOT_DIR/apps/macos' && swift build -q --product OpenClaw" 
}

if ($AUTO_DETECT_SIGNING -eq 1) {
    if (Check-SigningKeys) {
        Write-Log "==> Signing keys detected, will code sign"
        $SIGN = 1
    } else {
        Write-Log "==> No signing keys found, will skip code signing (--no-sign)"
        $NO_SIGN = 1
    }
}

if ($NO_SIGN -eq 1) {
    $env:ALLOW_ADHOC_SIGNING = 1
    $env:SIGN_IDENTITY = "-"
    New-Item -ItemType Directory -Path "$env:HOME/.openclaw" -Force -ErrorAction SilentlyContinue | Out-Null
    Run-Step "disable launchagent writes" { 
        touch $LAUNCHAGENT_DISABLE_MARKER 
    }
} elseif ($SIGN -eq 1) {
    if (-not (Check-SigningKeys)) {
        Write-Fail "No signing identity found. Use --no-sign or install a signing key."
    }
    Remove-Item Env:\ALLOW_ADHOC_SIGNING -ErrorAction SilentlyContinue
    Remove-Item Env:\SIGN_IDENTITY -ErrorAction SilentlyContinue
}

# 3) Package app (no embedded gateway).
Run-Step "package app" { 
    bash -lc "cd '$ROOT_DIR' && SKIP_TSC=${env:SKIP_TSC:-1} '$ROOT_DIR/scripts/package-mac-app.sh'" 
}

function Choose-AppBundle {
    if ($APP_BUNDLE -and (Test-Path $APP_BUNDLE)) {
        return
    }

    if (Test-Path "/Applications/OpenClaw.app") {
        $script:APP_BUNDLE = "/Applications/OpenClaw.app"
        return
    }

    if (Test-Path "$ROOT_DIR/dist/OpenClaw.app") {
        $script:APP_BUNDLE = "$ROOT_DIR/dist/OpenClaw.app"
        if (-not (Test-Path "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework")) {
            Write-Fail "dist/OpenClaw.app missing Sparkle after packaging"
        }
        return
    }

    Write-Fail "App bundle not found. Set OPENCLAW_APP_BUNDLE to your installed OpenClaw.app"
}

Choose-AppBundle

# When signed, clear any previous launchagent override marker.
if ($NO_SIGN -ne 1 -and $ATTACH_ONLY -ne 1 -and (Test-Path $LAUNCHAGENT_DISABLE_MARKER)) {
    Run-Step "clear launchagent disable marker" { 
        Remove-Item -Force $LAUNCHAGENT_DISABLE_MARKER 
    }
}

# When unsigned, ensure the gateway LaunchAgent targets the repo CLI (before the app launches).
# This reduces noisy "could not connect" errors during app startup.
if ($NO_SIGN -eq 1 -and $ATTACH_ONLY -ne 1) {
    Run-Step "install gateway launch agent (unsigned)" { 
        bash -lc "cd '$ROOT_DIR' && node openclaw.mjs daemon install --force --runtime node" 
    }
    Run-Step "restart gateway daemon (unsigned)" { 
        bash -lc "cd '$ROOT_DIR' && node openclaw.mjs daemon restart" 
    }
    if ($GATEWAY_WAIT_SECONDS -gt 0) {
        Run-Step "wait for gateway (unsigned)" { 
            Start-Sleep -Seconds $GATEWAY_WAIT_SECONDS 
        }
    }
    
    $GATEWAY_PORT_SCRIPT = @"
const fs = require("node:fs");
const path = require("node:path");
try {
  const raw = fs.readFileSync(path.join(process.env.HOME, ".openclaw", "openclaw.json"), "utf8");
  const cfg = JSON.parse(raw);
  const port = cfg && cfg.gateway && typeof cfg.gateway.port === "number" ? cfg.gateway.port : 18789;
  process.stdout.write(String(port));
} catch {
  process.stdout.write("18789");
}
"@
    
    $GATEWAY_PORT = node -e $GATEWAY_PORT_SCRIPT
    Run-Step "verify gateway port $GATEWAY_PORT (unsigned)" { 
        bash -lc "lsof -iTCP:${GATEWAY_PORT} -sTCP:LISTEN | head -n 5 || true" 
    }
}

$ATTACH_ONLY_ARGS = @()
if ($ATTACH_ONLY -eq 1) {
    $ATTACH_ONLY_ARGS += "--args"
    $ATTACH_ONLY_ARGS += "--attach-only"
}

# 4) Launch the installed app in the foreground so the menu bar extra appears.
# LaunchServices can inherit a huge environment from this shell (secrets, prompt vars, etc.).
# That can cause launchd spawn failures and is undesirable for a GUI app anyway.
Run-Step "launch app" {
    $envVars = @{
        HOME = $env:HOME
        USER = if ($env:USER) { $env:USER } else { & id -un }
        LOGNAME = if ($env:LOGNAME) { $env:LOGNAME } else { & id -un }
        TMPDIR = if ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }
        PATH = "/usr/bin:/bin:/usr/sbin:/sbin"
        LANG = if ($env:LANG) { $env:LANG } else { "en_US.UTF-8" }
    }
    
    $originalEnv = Get-ChildItem Env:
    try {
        # Clear current environment
        Get-ChildItem Env: | ForEach-Object { Remove-Item "Env:$($_.Key)" }
        
        # Set minimal environment
        foreach ($kv in $envVars.GetEnumerator()) {
            Set-Item "Env:$($kv.Key)" $kv.Value
        }
        
        if ($ATTACH_ONLY_ARGS.Count -gt 0) {
            & /usr/bin/open $APP_BUNDLE @ATTACH_ONLY_ARGS
        } else {
            & /usr/bin/open $APP_BUNDLE
        }
    } finally {
        # Restore original environment
        $originalEnv | ForEach-Object { Set-Item "Env:$($_.Key)" $_.Value }
    }
}

# 5) Verify the app is alive.
Start-Sleep -Seconds 1.5
$appRunning = Get-Process | Where-Object { $_.Path -like "*$APP_PROCESS_PATTERN*" }

if ($appRunning) {
    Write-Log "OK: OpenClaw is running."
} else {
    Write-Fail "App exited immediately. Check $LOG_PATH or Console.app (User Reports)."
}

if ($NO_SIGN -eq 1 -and $ATTACH_ONLY -ne 1) {
    Run-Step "show gateway launch agent args (unsigned)" { 
        bash -lc "/usr/bin/plutil -p '$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist' | head -n 40 || true" 
    }
}
