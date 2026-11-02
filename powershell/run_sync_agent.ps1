#!/usr/bin/env pwsh
# run_sync_agent.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway2:scripts/run_sync_agent.py
# Erzeugt: 2026-11-02 durch ABSTRACTIONS_MANAGER.py

<# Sandbox-Wrapper fuer sync_agent.py: mappt hartcodierte Host-Pfade auf /workspace. #>
$ErrorActionPreference = "Stop"

# Fuege Pfade zum Python-Suchpfad hinzu
$env:PYTHONPATH = "/workspace/scripts:/workspace/skills/clawhub-git-sync-agent/scripts" + $(if ($env:PYTHONPATH) { ":$env:PYTHONPATH" } else { "" })

# Setze die Variablen im sync_agent-Modul
$syncAgentScript = Get-Content -Path "/workspace/skills/clawhub-git-sync-agent/scripts/sync_agent.py" -Raw

# Ersetze die Variablendefinitionen in der Datei
$syncAgentScript = $syncAgentScript -replace 'CLAWHUB_DIR = .*', 'CLAWHUB_DIR = Path("/workspace/skills")'
$syncAgentScript = $syncAgentScript -replace 'GIT_DIR = .*', 'GIT_DIR = Path("/workspace/git/skills")'
$syncAgentScript = $syncAgentScript -replace 'STATE_FILE = .*', 'STATE_FILE = Path("/workspace/db/sync_state.json")'

# Speichere die geaenderte Version temporär
$tempScript = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tempScript -Value $syncAgentScript

try {
    # Fuehre das geänderte Skript aus
    python3 $tempScript
} finally {
    # Entferne die temporaere Datei
    if (Test-Path $tempScript) {
        Remove-Item $tempScript -Force
    }
}
