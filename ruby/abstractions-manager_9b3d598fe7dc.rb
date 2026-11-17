#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "84747d4e534afe9cf7c59246aa9fe4993abfee0c43c805b900eaea6b1bddd6a0", "source_sha256": "76a9327ec4d8b7b9abcabfcbbbf89350cb4a3a4fdc0c949a0b343fe059dc87a8", "target_language": "ruby"}
# abstractions-manager.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway2:scripts/abstractions-manager.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Führe das externe Skript mit denselben Argumenten aus
exec('/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh', *ARGV)
