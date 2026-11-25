#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "173bd9f2770b78511e948c2f6866e563cd9d3cac8136dce11bd1db1e173c5d8b", "source_sha256": "9caa03d9bb15f9d91f7e2672653c8c81852b35f9076edf8b7f839f4f06ac7dfd", "target_language": "powershell"}
# translation-worker-node.sh — portiert nach powershell
# Quelle: shell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node.sh
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

# Run on the selected node after transferring its native worker. JSON stdin is
# forwarded unchanged to the worker in run mode.
$ErrorActionPreference = 'Stop'

if ($args.Count -ne 2) {
  Write-Error 'Usage: translation-worker-node.ps1 node2|node3|node4|node6 prepare|health|run'
  exit 2
}
switch ($args[0]) {
  'node2' { $worker = '/home/node/.openclaw/workers/translation-worker'; $expected = '565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286' }
  'node3' { $worker = '/home/openclaw/.openclaw/workers/translation-worker'; $expected = '9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de' }
  'node4' { $worker = '/root/.openclaw/workers/translation-worker'; $expected = '565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286' }
  'node6' { $worker = '/home/node/.openclaw/workers/translation-worker'; $expected = '9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de' }
  default { Write-Error 'Unknown or non-POSIX node'; exit 2 }
}
switch ($args[1]) {
  'prepare' {}
  'health' {}
  'run' {}
  default { Write-Error 'Unknown action'; exit 2 }
}
if (!(Test-Path $worker -PathType Leaf)) {
  Write-Error "Missing worker or symlink rejected: $worker"
  exit 1
}
$actual = (Get-FileHash $worker -Algorithm SHA256).Hash.ToLower()
if ($actual -ne $expected) {
  Write-Error "Worker checksum mismatch: $worker"
  exit 1
}
chmod +x $worker
switch ($args[1]) {
  'prepare' { "Worker verified and executable: $worker" }
  'health' { & $worker --health }
  'run' { & $worker }
}
