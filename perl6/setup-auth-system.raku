#!/usr/bin/env raku
# abstraction-provenance: {"artifact_sha256": "27a2c3cb456549b930b69d7ede3f1e65419d095b925cf00cd9c2e86cfe58dc45", "source_sha256": "cb5f3c66f2f8ef6dd2ba9a71832aceb3d4c3af596567dad4241cf94d8e3fd8ba", "target_language": "perl6"}
# setup-auth-system.sh — portiert nach perl6
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/setup-auth-system.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Setup OpenClaw Auth Management System
# Run this once to set up:
# 1. Long-lived Claude Code token
# 2. Auth monitoring with notifications
# 3. Instructions for Termux widgets

use v6;

my $script-dir = $*PROGRAM.parent.Str;

say "=== OpenClaw Auth System Setup ===";
say "";

# Step 1: Check current auth status
say "Step 1: Checking current auth status...";
try {
    run("$script-dir/claude-auth-status.sh", "full");
}
say "";

# Step 2: Set up long-lived token
say "Step 2: Long-lived token setup";
say "";
say "Option A: Use 'claude setup-token' (recommended)";
say "  - Creates a long-lived API token";
say "  - No daily re-auth needed";
say "  - Run: claude setup-token";
say "";
say "Would you like to set up a long-lived token now? [y/N]";
my $setup-token = prompt("").trim;

if $setup-token ~~ /^<[Yy]>/ {
    say "";
    say "Opening https://console.anthropic.com/settings/api-keys";
    say "Create a new key or copy existing one, then paste below.";
    say "";
    run("claude", "setup-token");
}

say "";

# Step 3: Set up auth monitoring
say "Step 3: Auth monitoring setup";
say "";
say "The auth monitor checks expiry every 30 minutes and notifies you.";
say "";
say "Configure notification channels:";
say "";

# Check for ntfy
say "  ntfy.sh: Free push notifications to your phone";
say "  1. Install ntfy app on your phone";
say "  2. Subscribe to a topic (e.g., 'openclaw-alerts')";
say "";
say "Enter ntfy.sh topic (or leave blank to skip):";
my $ntfy-topic = prompt("").trim;

# Phone notification
say "";
say "  OpenClaw message: Send warning via OpenClaw itself";
say "Enter your phone number for alerts (or leave blank to skip):";
my $phone-number = prompt("").trim;

# Update service file
my $service-file = "$script-dir/systemd/openclaw-auth-monitor.service";
if $ntfy-topic.chars > 0 {
    my $content = slurp($service-file);
    $content ~~ s|'# Environment=NOTIFY_NTFY=' .*|'Environment=NOTIFY_NTFY=' ~ $ntfy-topic|;
    spurt($service-file, $content);
}
if $phone-number.chars > 0 {
    my $content = slurp($service-file);
    $content ~~ s|'# Environment=NOTIFY_PHONE=' .*|'Environment=NOTIFY_PHONE=' ~ $phone-number|;
    spurt($service-file, $content);
}

# Install systemd units
say "";
say "Installing systemd timer...";
mkdir("~/.config/systemd/user".IO) unless "~/.config/systemd/user".IO.d;
copy("$script-dir/systemd/openclaw-auth-monitor.service", "~/.config/systemd/user/openclaw-auth-monitor.service");
copy("$script-dir/systemd/openclaw-auth-monitor.timer", "~/.config/systemd/user/openclaw-auth-monitor.timer");
run("systemctl", "--user", "daemon-reload");
run("systemctl", "--user", "enable", "--now", "openclaw-auth-monitor.timer");

say "Auth monitor installed and running.";
say "";

# Step 4: Termux widget setup
say "Step 4: Termux widget setup (for phone)";
say "";
say "To set up quick auth from your phone:";
say "";
say "1. Install Termux and Termux:Widget from F-Droid";
say "2. Create ~/.shortcuts/ directory in Termux:";
say "   mkdir -p ~/.shortcuts";
say "";
say "3. Copy the widget scripts:";
say "   scp $script-dir/termux-quick-auth.sh phone:~/.shortcuts/ClawdAuth";
say "   scp $script-dir/termux-auth-widget.sh phone:~/.shortcuts/ClawdAuth-Full";
say "";
say "4. Make them executable on phone:";
say "   ssh phone 'chmod +x ~/.shortcuts/Clawd*'";
say "";
say "5. Add Termux:Widget to your home screen";
say "6. Tap the widget to see your auth scripts";
say "";
say "The quick widget (ClawdAuth) shows status and opens auth URL if needed.";
say "The full widget (ClawdAuth-Full) provides guided re-auth flow.";
say "";

# Summary
say "=== Setup Complete ===";
say "";
say "What's configured:";
say "  - Auth status: $script-dir/claude-auth-status.sh";
say "  - Mobile re-auth: $script-dir/mobile-reauth.sh";
say "  - Auth monitor: systemctl --user status openclaw-auth-monitor.timer";
say "";
say "Quick commands:";
say "  Check auth:  $script-dir/claude-auth-status.sh";
say "  Re-auth:     $script-dir/mobile-reauth.sh";
say "  Test monitor: $script-dir/auth-monitor.sh";
say "";
