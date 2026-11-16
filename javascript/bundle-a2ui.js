#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "c62fda9466cfbfdf4a46cc6a659809ae2f52a811bd7764d16799e85f56376339", "source_sha256": "25e94789e3af346018b091c7c4d6d65632394c19fcf9eaaeac876efbe534149a", "target_language": "javascript"}
// bundle-a2ui.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.sh
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

const { spawnSync } = require('child_process');
const path = require('path');

const rootDir = path.resolve(__dirname, '..');
const scriptPath = path.join(rootDir, 'scripts', 'bundle-a2ui.mjs');

const result = spawnSync('node', [scriptPath, ...process.argv.slice(2)], {
  stdio: 'inherit',
  cwd: process.cwd()
});

process.exit(result.status ?? 1);
