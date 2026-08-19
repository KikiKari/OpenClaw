#!/usr/bin/env perl
# openclaw-maintenance.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway2:scripts/openclaw-maintenance.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;
use File::Which qw(which);
use Env qw(HOME);

my $openclaw_bin = $ENV{OPENCLAW_BIN} // "$HOME/.local/bin/openclaw";

if (!-x $openclaw_bin) {
    print STDERR "ERROR: OpenClaw binary not found: $openclaw_bin\n";
    exit 1;
}

print "Using OpenClaw: " . `$openclaw_bin --version`;

# === 1. Service-/Config-Drift ===
system($openclaw_bin, "doctor") == 0 or die "Command failed: $openclaw_bin doctor";

# === 2. Plugin-Stage (Registry refresh only; updates are explicit/manual) ===
system($openclaw_bin, "plugins", "registry", "--refresh") == 0 or die "Command failed: $openclaw_bin plugins registry --refresh";
if ($ENV{RUN_PLUGIN_UPDATE} // 0 eq "1") {
    system($openclaw_bin, "plugins", "update", "--all") == 0 or die "Command failed: $openclaw_bin plugins update --all";
} else {
    print "Skipping plugin update. Run with RUN_PLUGIN_UPDATE=1 to enable.\n";
}

# === 3. Tasks ===
system($openclaw_bin, "tasks", "maintenance", "--apply") == 0 or die "Command failed: $openclaw_bin tasks maintenance --apply";

# === 4. Sessions – alle Agents auf einmal ===
system($openclaw_bin, "sessions", "cleanup", "--enforce", "--all-agents") == 0 or die "Command failed: $openclaw_bin sessions cleanup --enforce --all-agents";

# === 5. Memory – status/index decken alle Agents ab ===
system($openclaw_bin, "memory", "status", "--deep", "--fix") == 0 or die "Command failed: $openclaw_bin memory status --deep --fix";
system($openclaw_bin, "memory", "index", "--force") == 0 or die "Command failed: $openclaw_bin memory index --force";

# === 6. Memory promote – MUSS pro Agent ===
foreach my $agent (qw(main knecht docs ops-hub cron)) {
    system($openclaw_bin, "memory", "promote", "--apply", "--agent", $agent) == 0 or die "Command failed: $openclaw_bin memory promote --apply --agent $agent";
}

# === 7. Secrets ===
system($openclaw_bin, "secrets", "reload") == 0 or die "Command failed: $openclaw_bin secrets reload";
