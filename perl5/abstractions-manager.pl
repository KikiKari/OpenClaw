#!/usr/bin/perl
# abstractions-manager.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway2:scripts/abstractions-manager.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

# Führe das externe Skript mit denselben Argumenten aus
exec('/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh', @ARGV) or die "Konnte abstractions-manager-cron.sh nicht ausführen: $!";
