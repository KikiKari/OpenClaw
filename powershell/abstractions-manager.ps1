#!/usr/bin/env pwsh
# abstractions-manager.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway2:scripts/abstractions-manager.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

$scriptPath = Join-Path $env:HOME ".openclaw/scripts/abstractions-manager-cron.sh"

# Forward all arguments to the cron script
& $scriptPath @args

# Exit with the same exit code as the invoked script
exit $LASTEXITCODE
