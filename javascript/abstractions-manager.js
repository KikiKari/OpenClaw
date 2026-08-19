#!/usr/bin/env node
// abstractions-manager.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway2:scripts/abstractions-manager.sh
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

const { spawnSync } = require('child_process');
const path = require('path');

const scriptPath = path.join('/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh');

const result = spawnSync(scriptPath, process.argv.slice(2), {
  stdio: 'inherit'
});

if (result.error) {
  console.error(result.error);
  process.exit(1);
}

process.exit(result.status ?? 0);
