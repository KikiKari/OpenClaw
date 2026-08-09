#!/usr/bin/env tclsh
# abstractions-manager.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway2:scripts/abstractions-manager.sh
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

# Execute the abstractions manager cron script with all arguments passed through
exec /home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh {*}$argv
