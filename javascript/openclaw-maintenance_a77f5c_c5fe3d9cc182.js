#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "bcc46278536c36fda96c92651ca618e86f8dcd6a493c0f51fa6da8a9097f02e6", "source_sha256": "a77f5c2629fe7fafac268cfbf2f0b3e77a194322aee8f9c06967eb6c33db043e", "target_language": "javascript"}
// openclaw-maintenance.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway2:scripts/openclaw-maintenance.sh
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

const { execSync } = require('child_process');
const path = require('path');
const os = require('process');

const OPENCLAW_BIN = process.env.OPENCLAW_BIN || path.join(os.homedir(), '.local', 'bin', 'openclaw');

// Helper function to execute command and handle errors
function executeCommand(command) {
  try {
    const result = execSync(command, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore'] });
    return result.trim();
  } catch (error) {
    throw new Error(`Command failed: ${command}\n${error.stderr || error.message}`);
  }
}

// Check if OpenClaw binary exists and is executable
try {
  executeCommand(`test -x "${OPENCLAW_BIN}"`);
} catch (error) {
  console.error(`ERROR: OpenClaw binary not found: ${OPENCLAW_BIN}`);
  process.exit(1);
}

console.log(`Using OpenClaw: ${executeCommand(`${OPENCLAW_BIN} --version`)}`);

// === 1. Service-/Config-Drift ===
executeCommand(`${OPENCLAW_BIN} doctor`);

// === 2. Plugin-Stage (Registry refresh only; updates are explicit/manual) ===
executeCommand(`${OPENCLAW_BIN} plugins registry --refresh`);
if (process.env.RUN_PLUGIN_UPDATE === '1') {
  executeCommand(`${OPENCLAW_BIN} plugins update --all`);
} else {
  console.log('Skipping plugin update. Run with RUN_PLUGIN_UPDATE=1 to enable.');
}

// === 3. Tasks ===
executeCommand(`${OPENCLAW_BIN} tasks maintenance --apply`);

// === 4. Sessions – alle Agents auf einmal ===
executeCommand(`${OPENCLAW_BIN} sessions cleanup --enforce --all-agents`);

// === 5. Memory – status/index decken alle Agents ab ===
executeCommand(`${OPENCLAW_BIN} memory status --deep --fix`);
executeCommand(`${OPENCLAW_BIN} memory index --force`);

// === 6. Memory promote – MUSS pro Agent ===
const agents = ['main', 'knecht', 'docs', 'ops-hub', 'cron'];
agents.forEach(agent => {
  executeCommand(`${OPENCLAW_BIN} memory promote --apply --agent ${agent}`);
});

// === 7. Secrets ===
executeCommand(`${OPENCLAW_BIN} secrets reload`);
