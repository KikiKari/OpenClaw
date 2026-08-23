#!/usr/bin/env pwsh
# test_node3.sh — portiert nach powershell
# Quelle: shell, OpenClaw@gateway1:scripts/test_node3.sh
# auch in: OpenClaw@gateway2:scripts/test_node3.sh
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

# Test Node 3 Connection
$env:OPENCLAW_ALLOW_INSECURE_PRIVATE_WS = "1"
Write-Host "Starting node connection test..."
$proc = Start-Process -FilePath "/usr/local/bin/openclaw" -ArgumentList "node", "run", "--host", "152.53.145.65", "--port", "18789" -Wait -PassThru -NoNewWindow
Write-Host "Exit code: $($proc.ExitCode)"
