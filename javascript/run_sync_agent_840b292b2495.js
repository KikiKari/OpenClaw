#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "2fcaae0c0b1420b293976b7fefdcbd2a416b354a99a150c3c3ccc9c7e71a3e74", "source_sha256": "c372bc97113533b0ca2400d318d3cd0e8cd55cea37f0cc563ab714990cc9efb6", "target_language": "javascript"}
// run_sync_agent.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway2:scripts/run_sync_agent.py
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

/* Sandbox-Wrapper für sync_agent.js: mappt hartcodierte Host-Pfade auf /workspace. */
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

// Simuliere sys.path.insert durch Anpassung des Modulsuchpfades
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Füge Pfade zum Modulsuchpfad hinzu (wird über import gelöst)
const workspaceScripts = '/workspace/scripts';
const clawhubGitSyncAgentScripts = '/workspace/skills/clawhub-git-sync-agent/scripts';

// Importiere sync_agent mit angepasstem Pfad
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const syncAgentPath = join(clawhubGitSyncAgentScripts, 'sync_agent.js');
const sync_agent = require(syncAgentPath);

// Setze globale Variablen
const WS = '/workspace';
sync_agent.CLAWHUB_DIR = join(WS, 'skills');
sync_agent.GIT_DIR = join(WS, 'git', 'skills');
sync_agent.STATE_FILE = join(WS, 'db', 'sync_state.json');

// Führe main Funktion aus
if (import.meta.url === `file://${process.argv[1]}`) {
    sync_agent.main();
}
