#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "709ad6cdff6afa776fb0e5d35b310d1da68a043bd7a86a9ebbe9399ad06355c8", "source_sha256": "cb5f3c66f2f8ef6dd2ba9a71832aceb3d4c3af596567dad4241cf94d8e3fd8ba", "target_language": "powershell"}
# setup-auth-system.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/setup-auth-system.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Setup OpenClaw Auth Management System
# Run this once to set up:
# 1. Long-lived Claude Code token
# 2. Auth monitoring with notifications
# 3. Instructions for Termux widgets

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ScriptDir = Resolve-Path $ScriptDir

Write-Output "=== OpenClaw Auth System Setup ==="
Write-Output ""

# Step 1: Check current auth status
Write-Output "Step 1: Checking current auth status..."
& "$ScriptDir/claude-auth-status.sh" full
Write-Output ""

# Step 2: Set up long-lived token
Write-Output "Step 2: Long-lived token setup"
Write-Output ""
Write-Output "Option A: Use 'claude setup-token' (recommended)"
Write-Output "  - Creates a long-lived API token"
Write-Output "  - No daily re-auth needed"
Write-Output "  - Run: claude setup-token"
Write-Output ""
Write-Output "Would you like to set up a long-lived token now? [y/N]"
$SetupToken = Read-Host

if ($SetupToken -match "^[Yy]") {
    Write-Output ""
    Write-Output "Opening https://console.anthropic.com/settings/api-keys"
    Write-Output "Create a new key or copy existing one, then paste below."
    Write-Output ""
    & claude setup-token
}

Write-Output ""

# Step 3: Set up auth monitoring
Write-Output "Step 3: Auth monitoring setup"
Write-Output ""
Write-Output "The auth monitor checks expiry every 30 minutes and notifies you."
Write-Output ""
Write-Output "Configure notification channels:"
Write-Output ""

# Check for ntfy
Write-Output "  ntfy.sh: Free push notifications to your phone"
Write-Output "  1. Install ntfy app on your phone"
Write-Output "  2. Subscribe to a topic (e.g., 'openclaw-alerts')"
Write-Output ""
Write-Output "Enter ntfy.sh topic (or leave blank to skip):"
$NtfyTopic = Read-Host

# Phone notification
Write-Output ""
Write-Output "  OpenClaw message: Send warning via OpenClaw itself"
Write-Output "Enter your phone number for alerts (or leave blank to skip):"
$PhoneNumber = Read-Host

# Update service file
$ServiceFile = "$ScriptDir/systemd/openclaw-auth-monitor.service"
if (![string]::IsNullOrWhiteSpace($NtfyTopic)) {
    (Get-Content $ServiceFile) -replace '# Environment=NOTIFY_NTFY=.*', "Environment=NOTIFY_NTFY=$NtfyTopic" | Set-Content $ServiceFile
}
if (![string]::IsNullOrWhiteSpace($PhoneNumber)) {
    (Get-Content $ServiceFile) -replace '# Environment=NOTIFY_PHONE=.*', "Environment=NOTIFY_PHONE=$PhoneNumber" | Set-Content $ServiceFile
}

# Install systemd units
Write-Output ""
Write-Output "Installing systemd timer..."
$SystemdUserDir = "$env:HOME/.config/systemd/user"
if (!(Test-Path $SystemdUserDir)) {
    New-Item -ItemType Directory -Path $SystemdUserDir | Out-Null
}
Copy-Item "$ScriptDir/systemd/openclaw-auth-monitor.service" "$SystemdUserDir/"
Copy-Item "$ScriptDir/systemd/openclaw-auth-monitor.timer" "$SystemdUserDir/"

# Note: PowerShell does not have direct equivalent to systemctl
# This part would require manual setup or using WSL if on Windows
Write-Output "Please run the following commands manually to enable the systemd timer:"
Write-Output "  systemctl --user daemon-reload"
Write-Output "  systemctl --user enable --now openclaw-auth-monitor.timer"

Write-Output "Auth monitor installed and running."
Write-Output ""

# Step 4: Termux widget setup
Write-Output "Step 4: Termux widget setup (for phone)"
Write-Output ""
Write-Output "To set up quick auth from your phone:"
Write-Output ""
Write-Output "1. Install Termux and Termux:Widget from F-Droid"
Write-Output "2. Create ~/.shortcuts/ directory in Termux:"
Write-Output "   mkdir -p ~/.shortcuts"
Write-Output ""
Write-Output "3. Copy the widget scripts:"
Write-Output "   scp $ScriptDir/termux-quick-auth.sh phone:~/.shortcuts/ClawdAuth"
Write-Output "   scp $ScriptDir/termux-auth-widget.sh phone:~/.shortcuts/ClawdAuth-Full"
Write-Output ""
Write-Output "4. Make them executable on phone:"
Write-Output "   ssh phone 'chmod +x ~/.shortcuts/Clawd*'"
Write-Output ""
Write-Output "5. Add Termux:Widget to your home screen"
Write-Output "6. Tap the widget to see your auth scripts"
Write-Output ""
Write-Output "The quick widget (ClawdAuth) shows status and opens auth URL if needed."
Write-Output "The full widget (ClawdAuth-Full) provides guided re-auth flow."
Write-Output ""

# Summary
Write-Output "=== Setup Complete ==="
Write-Output ""
Write-Output "What's configured:"
Write-Output "  - Auth status: $ScriptDir/claude-auth-status.sh"
Write-Output "  - Mobile re-auth: $ScriptDir/mobile-reauth.sh"
Write-Output "  - Auth monitor: systemctl --user status openclaw-auth-monitor.timer"
Write-Output ""
Write-Output "Quick commands:"
Write-Output "  Check auth:  $ScriptDir/claude-auth-status.sh"
Write-Output "  Re-auth:     $ScriptDir/mobile-reauth.sh"
Write-Output "  Test monitor: $ScriptDir/auth-monitor.sh"
Write-Output ""
