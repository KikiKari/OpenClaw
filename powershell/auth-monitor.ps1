#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "b03b2a184bc5013fe2305c432db719b0f40fb97424fbb33f2ca942604e7376cd", "source_sha256": "1a67bf0d8a66b56fba5df9f18c7370e48304461313b9611ab6f238f553332b50", "target_language": "powershell"}
# auth-monitor.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/auth-monitor.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Auth Expiry Monitor
# Run via cron or systemd timer to get proactive notifications
# before Claude Code auth expires.
#
# Suggested cron: */30 * * * * /home/admin/openclaw/scripts/auth-monitor.sh
#
# Environment variables:
#   NOTIFY_PHONE - Phone number to send OpenClaw notification (e.g., +1234567890)
#   NOTIFY_NTFY  - ntfy.sh topic for push notifications (e.g., openclaw-alerts)
#   WARN_HOURS   - Hours before expiry to warn (default: 2)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ClaudeCreds = Join-Path $HOME '.claude/.credentials.json'
$StateFile = Join-Path $HOME '.openclaw/auth-monitor-state'

# Configuration
$WarnHours = if ($env:WARN_HOURS) { [int]$env:WARN_HOURS } else { 2 }
$NotifyPhone = if ($env:NOTIFY_PHONE) { $env:NOTIFY_PHONE } else { '' }
$NotifyNtfy = if ($env:NOTIFY_NTFY) { $env:NOTIFY_NTFY } else { '' }

# State tracking to avoid spam
$StateDir = Split-Path $StateFile -Parent
if (!(Test-Path $StateDir)) {
    New-Item -ItemType Directory -Path $StateDir | Out-Null
}

$LastNotified = 0
if (Test-Path $StateFile) {
    $LastNotified = [long](Get-Content $StateFile -Raw).Trim()
}
$Now = [long]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())

# Only notify once per hour max
$MinInterval = 3600

function Send-Notification {
    param(
        [string]$Message,
        [string]$Priority = 'default'
    )

    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"

    # Check if we notified recently
    if (($Now - $LastNotified) -lt $MinInterval) {
        Write-Host "Skipping notification (sent recently)"
        return
    }

    # Send via OpenClaw if phone configured and auth still valid
    if ($NotifyPhone) {
        # Check if we can still use openclaw
        try {
            $AuthStatus = & "$ScriptDir/claude-auth-status.sh" 'simple' 2>$null
            if ($AuthStatus -match 'OK|EXPIRING') {
                Write-Host "Sending via OpenClaw to $NotifyPhone..."
                openclaw send --to "$NotifyPhone" --message "$Message" 2>$null
            }
        } catch {
            # Ignore errors
        }
    }

    # Send via ntfy.sh if configured
    if ($NotifyNtfy) {
        Write-Host "Sending via ntfy.sh to $NotifyNtfy..."
        try {
            $Headers = @{
                'Title' = 'OpenClaw Auth Alert'
                'Priority' = $Priority
                'Tags' = 'warning,key'
            }
            $Body = $Message
            Invoke-RestMethod -Uri "https://ntfy.sh/$NotifyNtfy" -Method POST -Headers $Headers -Body $Body -ErrorAction SilentlyContinue | Out-Null
        } catch {
            # Ignore errors
        }
    }

    # Update state
    Set-Content -Path $StateFile -Value $Now
}

# Check auth status
if (!(Test-Path $ClaudeCreds)) {
    Send-Notification -Message "Claude Code credentials missing! Run: claude setup-token" -Priority 'high'
    exit 1
}

try {
    $Credentials = Get-Content $ClaudeCreds -Raw | ConvertFrom-Json
    $ExpiresAt = if ($Credentials.claudeAiOauth.expiresAt) { $Credentials.claudeAiOauth.expiresAt } else { 0 }
} catch {
    Send-Notification -Message "Failed to parse Claude Code credentials!" -Priority 'high'
    exit 1
}

$NowMs = $Now * 1000
$DiffMs = $ExpiresAt - $NowMs
$HoursLeft = [Math]::Floor($DiffMs / 3600000)
$MinsLeft = [Math]::Floor(($DiffMs % 3600000) / 60000)

if ($DiffMs -lt 0) {
    Send-Notification -Message "Claude Code auth EXPIRED! OpenClaw is down. Run: ssh l36 '~/openclaw/scripts/mobile-reauth.sh'" -Priority 'urgent'
    exit 1
} elseif ($HoursLeft -lt $WarnHours) {
    Send-Notification -Message "Claude Code auth expires in ${HoursLeft}h ${MinsLeft}m. Consider re-auth soon." -Priority 'high'
    exit 0
} else {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Auth OK: ${HoursLeft}h ${MinsLeft}m remaining"
    exit 0
}
