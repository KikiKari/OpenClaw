#!/usr/bin/env perl
# abstraction-provenance: {"artifact_sha256": "7a33875939321e431071cbc715bc6369beaf428a576b1f1490fabb6238fcfbf3", "source_sha256": "2a9ca592fdc915cfb281aa77dde9f07ffd3de83ce5abb8d87c77d46668d75dd6", "target_language": "perl5"}
# openclaw-maintenance.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway1:scripts/openclaw-maintenance.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

# === 1. Service-/Config-Drift ===
system("openclaw", "doctor");

# === 2. Plugin-Stage (aktive Varianten, NICHT plugins doctor) ===
system("openclaw", "plugins", "registry", "--refresh");
system("openclaw", "plugins", "update", "--all");

# === 3. Tasks ===
system("openclaw", "tasks", "maintenance", "--apply");

# === 4. Sessions – alle Agents auf einmal ===
system("openclaw", "sessions", "cleanup", "--enforce", "--all-agents");

# === 5. Memory – status/index decken alle Agents ab ===
system("openclaw", "memory", "status", "--deep", "--fix");
system("openclaw", "memory", "index", "--force");

# === 6. Memory promote – MUSS pro Agent ===
foreach my $AGENT (qw(main knecht docs ops-hub cron)) {
    system("openclaw", "memory", "promote", "--apply", "--agent", $AGENT);
}

# === 7. Secrets ===
system("openclaw", "secrets", "reload");
