#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "f08642e61aa05a9c2cdeb3c394b362f24826297dba30c3b2ae1bb4f4d4289c10", "source_sha256": "76a9327ec4d8b7b9abcabfcbbbf89350cb4a3a4fdc0c949a0b343fe059dc87a8", "target_language": "javascript"}
// abstractions-manager.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway2:scripts/abstractions-manager.sh
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

const { spawn } = require('child_process');
const path = require('path');

const scriptPath = path.join('/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh');

const child = spawn(scriptPath, process.argv.slice(2), {
  stdio: 'inherit'
});

child.on('error', (err) => {
  console.error(`Fehler beim Ausführen des Scripts: ${err.message}`);
  process.exit(1);
});

child.on('close', (code) => {
  process.exit(code);
});
