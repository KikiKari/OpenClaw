#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "e64e164d805e5d566e0fd6c98ca9d9bbccfe65bd8ef72a653dc0ffc95901f2e9", "source_sha256": "c372bc97113533b0ca2400d318d3cd0e8cd55cea37f0cc563ab714990cc9efb6", "target_language": "powershell"}
# run_sync_agent.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway2:scripts/run_sync_agent.py
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

<# Sandbox-Wrapper fuer sync_agent.py: mappt hartcodierte Host-Pfade auf /workspace. #>
$ErrorActionPreference = "Stop"

# Fuege Pfade zum Python-Suchpfad hinzu
$env:PYTHONPATH = "/workspace/scripts:/workspace/skills/clawhub-git-sync-agent/scripts" + $(if ($env:PYTHONPATH) { ":$env:PYTHONPATH" } else { "" })

# Setze die Variablen im sync_agent-Modul
$pythonCode = @'
import sys
from pathlib import Path
sys.path.insert(0, "/workspace/scripts")
sys.path.insert(0, "/workspace/skills/clawhub-git-sync-agent/scripts")
import sync_agent
WS = Path("/workspace")
sync_agent.CLAWHUB_DIR = WS / "skills"
sync_agent.GIT_DIR = WS / "git" / "skills"
sync_agent.STATE_FILE = WS / "db" / "sync_state.json"
sync_agent.main()
'@

# Fuehre den Python-Code aus
python3 -c $pythonCode
