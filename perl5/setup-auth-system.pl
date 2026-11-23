#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "e33379fb059fa916bd3b7c7eb8db154a4cefd88bd2a3383c905f78db9bdf29be", "source_sha256": "cb5f3c66f2f8ef6dd2ba9a71832aceb3d4c3af596567dad4241cf94d8e3fd8ba", "target_language": "perl5"}
# setup-auth-system.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/setup-auth-system.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile);

my $script_dir = dirname(abs_path($0));

print "=== OpenClaw Auth System Setup ===\n\n";

# Step 1: Check current auth status
print "Step 1: Checking current auth status...\n";
system("bash", catfile($script_dir, "claude-auth-status.sh"), "full");
print "\n";

# Step 2: Set up long-lived token
print "Step 2: Long-lived token setup\n\n";
print "Option A: Use 'claude setup-token' (recommended)\n";
print "  - Creates a long-lived API token\n";
print "  - No daily re-auth needed\n";
print "  - Run: claude setup-token\n\n";
print "Would you like to set up a long-lived token now? [y/N]\n";
my $setup_token = <STDIN>;
chomp $setup_token;

if ($setup_token =~ /^[Yy]/) {
    print "\n";
    print "Opening https://console.anthropic.com/settings/api-keys\n";
    print "Create a new key or copy existing one, then paste below.\n\n";
    system("claude setup-token");
}

print "\n";

# Step 3: Set up auth monitoring
print "Step 3: Auth monitoring setup\n\n";
print "The auth monitor checks expiry every 30 minutes and notifies you.\n\n";
print "Configure notification channels:\n\n";

# Check for ntfy
print "  ntfy.sh: Free push notifications to your phone\n";
print "  1. Install ntfy app on your phone\n";
print "  2. Subscribe to a topic (e.g., 'openclaw-alerts')\n\n";
print "Enter ntfy.sh topic (or leave blank to skip):\n";
my $ntfy_topic = <STDIN>;
chomp $ntfy_topic;

# Phone notification
print "\n";
print "  OpenClaw message: Send warning via OpenClaw itself\n";
print "Enter your phone number for alerts (or leave blank to skip):\n";
my $phone_number = <STDIN>;
chomp $phone_number;

# Update service file
my $service_file = catfile($script_dir, "systemd", "openclaw-auth-monitor.service");
if ($ntfy_topic ne "") {
    system("sed", "-i", "s|# Environment=NOTIFY_NTFY=.*|Environment=NOTIFY_NTFY=$ntfy_topic|", $service_file);
}
if ($phone_number ne "") {
    system("sed", "-i", "s|# Environment=NOTIFY_PHONE=.*|Environment=NOTIFY_PHONE=$phone_number|", $service_file);
}

# Install systemd units
print "\n";
print "Installing systemd timer...\n";
system("mkdir -p ~/.config/systemd/user");
system("cp " . catfile($script_dir, "systemd", "openclaw-auth-monitor.service") . " ~/.config/systemd/user/");
system("cp " . catfile($script_dir, "systemd", "openclaw-auth-monitor.timer") . " ~/.config/systemd/user/");
system("systemctl --user daemon-reload");
system("systemctl --user enable --now openclaw-auth-monitor.timer");

print "Auth monitor installed and running.\n\n";

# Step 4: Termux widget setup
print "Step 4: Termux widget setup (for phone)\n\n";
print "To set up quick auth from your phone:\n\n";
print "1. Install Termux and Termux:Widget from F-Droid\n";
print "2. Create ~/.shortcuts/ directory in Termux:\n";
print "   mkdir -p ~/.shortcuts\n\n";
print "3. Copy the widget scripts:\n";
print "   scp " . catfile($script_dir, "termux-quick-auth.sh") . " phone:~/.shortcuts/ClawdAuth\n";
print "   scp " . catfile($script_dir, "termux-auth-widget.sh") . " phone:~/.shortcuts/ClawdAuth-Full\n\n";
print "4. Make them executable on phone:\n";
print "   ssh phone 'chmod +x ~/.shortcuts/Clawd*'\n\n";
print "5. Add Termux:Widget to your home screen\n";
print "6. Tap the widget to see your auth scripts\n\n";
print "The quick widget (ClawdAuth) shows status and opens auth URL if needed.\n";
print "The full widget (ClawdAuth-Full) provides guided re-auth flow.\n\n";

# Summary
print "=== Setup Complete ===\n\n";
print "What's configured:\n";
print "  - Auth status: " . catfile($script_dir, "claude-auth-status.sh") . "\n";
print "  - Mobile re-auth: " . catfile($script_dir, "mobile-reauth.sh") . "\n";
print "  - Auth monitor: systemctl --user status openclaw-auth-monitor.timer\n\n";
print "Quick commands:\n";
print "  Check auth:  " . catfile($script_dir, "claude-auth-status.sh") . "\n";
print "  Re-auth:     " . catfile($script_dir, "mobile-reauth.sh") . "\n";
print "  Test monitor: " . catfile($script_dir, "auth-monitor.sh") . "\n\n";
