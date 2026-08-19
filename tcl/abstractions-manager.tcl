#!/usr/bin/env tclsh8.6
# abstractions-manager.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway2:scripts/abstractions-manager.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# Execute the cron script with all arguments passed through
exec /home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh {*}$argv
