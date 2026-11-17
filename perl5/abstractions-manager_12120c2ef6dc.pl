#!/usr/bin/perl
# abstraction-provenance: {"artifact_sha256": "d26124655a296acc3fded923942c6201e60961348b483f1a126bfd033255d7e4", "source_sha256": "76a9327ec4d8b7b9abcabfcbbbf89350cb4a3a4fdc0c949a0b343fe059dc87a8", "target_language": "perl5"}
# abstractions-manager.sh — portiert nach perl5
# Quelle: shell, OpenClaw@gateway2:scripts/abstractions-manager.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

use strict;
use warnings;

exec('/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh', @ARGV);
