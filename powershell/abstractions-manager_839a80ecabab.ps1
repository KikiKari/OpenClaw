#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "088284d8f9ed11f93114096022f08ff5b7c02ebaeaa69c3a1f504f4ecc0afc90", "source_sha256": "76a9327ec4d8b7b9abcabfcbbbf89350cb4a3a4fdc0c949a0b343fe059dc87a8", "target_language": "powershell"}
# abstractions-manager.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway2:scripts/abstractions-manager.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

& "/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh" @args
