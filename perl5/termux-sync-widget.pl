#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "a617d2d20db956faacc8a1c43e320df0044b7fb5c4f2f9aa16a1268ce2738c86", "source_sha256": "5a61490f9c6c3ae52acdce976cbcad0d09396f906ddb85d7ae357ab98e762893", "target_language": "perl5"}
# termux-sync-widget.sh — portiert nach perl5
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-sync-widget.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use Env qw(@PATH);
$ENV{PATH} = "/data/data/com.termux/files/usr/bin:/usr/bin:/bin";

# OpenClaw OAuth Sync Widget
# Syncs Claude Code tokens to OpenClaw on l36 server
# Place in ~/.shortcuts/ on phone for Termux:Widget

# Add Termux binaries to PATH if not already present
my $termux_bin = "/data/data/com.termux/files/usr/bin";
unless (grep { $_ eq $termux_bin } @PATH) {
    unshift @PATH, $termux_bin;
}

system("termux-toast", "Syncing OpenClaw auth...");

# Run sync on l36 server
my $server = $ENV{OPENCLAW_SERVER} // "l36";
my $command = "ssh \"$server\" '/home/admin/openclaw/scripts/sync-claude-code-auth.sh' 2>&1";

my $result = `$command`;
my $exit_code = $? >> 8;

if ($exit_code == 0) {
    # Extract expiry time from output
    my ($expiry) = $result =~ /Token expires:(.*)/;
    $expiry //= "";

    system("termux-vibrate", "-d", "100");
    system("termux-toast", "OpenClaw synced! Expires:$expiry");

    # Optional: restart openclaw service
    system("ssh \"$server\" 'systemctl --user restart openclaw' 2>/dev/null");
} else {
    system("termux-vibrate", "-d", "300");
    system("termux-toast", "Sync failed: $result");
}
