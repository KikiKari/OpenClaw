#!/usr/bin/env node
// openclaw-maintenance.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway2:scripts/openclaw-maintenance.sh
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

const { spawnSync } = require('child_process');
const path = require('path');

const OPENCLAW_BIN = process.env.OPENCLAW_BIN || path.join(process.env.HOME, '.local', 'bin', 'openclaw');

// Helper function to execute command and handle errors
function execCommand(command, args = []) {
  const result = spawnSync(command, args, { stdio: 'inherit' });
  if (result.error) {
    console.error(`ERROR: Failed to execute ${command}: ${result.error.message}`);
    process.exit(1);
  }
  if (result.status !== 0) {
    console.error(`ERROR: Command failed with exit code ${result.status}: ${command}`);
    process.exit(result.status);
  }
  return result;
}

// Check if OpenClaw binary exists and is executable
try {
  const fs = require('fs');
  fs.accessSync(OPENCLAW_BIN, fs.constants.X_OK);
} catch (err) {
  console.error(`ERROR: OpenClaw binary not found: ${OPENCLAW_BIN}`);
  process.exit(1);
}

console.log(`Using OpenClaw: ${execCommand(OPENCLAW_BIN, ['--version']).stdout}`);

// === 1. Service-/Config-Drift ===
execCommand(OPENCLAW_BIN, ['doctor']);

// === 2. Plugin-Stage (Registry refresh only; updates are explicit/manual) ===
execCommand(OPENCLAW_BIN, ['plugins', 'registry', '--refresh']);
if (process.env.RUN_PLUGIN_UPDATE === '1') {
  execCommand(OPENCLAW_BIN, ['plugins', 'update', '--all']);
} else {
  console.log('Skipping plugin update. Run with RUN_PLUGIN_UPDATE=1 to enable.');
}

// === 3. Tasks ===
execCommand(OPENCLAW_BIN, ['tasks', 'maintenance', '--apply']);

// === 4. Sessions – alle Agents auf einmal ===
execCommand(OPENCLAW_BIN, ['sessions', 'cleanup', '--enforce', '--all-agents']);

// === 5. Memory – status/index decken alle Agents ab ===
execCommand(OPENCLAW_BIN, ['memory', 'status', '--deep', '--fix']);
execCommand(OPENCLAW_BIN, ['memory', 'index', '--force']);

// === 6. Memory promote – MUSS pro Agent ===
const agents = ['main', 'knecht', 'docs', 'ops-hub', 'cron'];
for (const agent of agents) {
  execCommand(OPENCLAW_BIN, ['memory', 'promote', '--apply', '--agent', agent]);
}

// === 7. Secrets ===
execCommand(OPENCLAW_BIN, ['secrets', 'reload']);
