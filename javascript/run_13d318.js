#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "16ac0f29a869ff06d4cacb24a5cf67c4cb5b4b00dc20f4c0ca0b684a1b61cc16", "source_sha256": "13d3188a43593fc462e34986e11913f715c38d3ec54128b71ba71024d5419be6", "target_language": "javascript"}
// run.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/cleanup-smoke/run.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

import { execSync } from 'child_process';
import { existsSync, mkdirSync, writeFileSync, readFileSync } from 'fs';
import { rmSync } from 'fs';

// Change to /repo directory
process.chdir('/repo');

const OPENCLAW_STATE_DIR = "/tmp/openclaw-test";
const OPENCLAW_CONFIG_PATH = `${OPENCLAW_STATE_DIR}/openclaw.json`;

console.log("==> Build");
try {
  execSync('pnpm build', { stdio: ['pipe', '/tmp/openclaw-cleanup-build.log', '/tmp/openclaw-cleanup-build.log'] });
} catch (error) {
  console.log(readFileSync('/tmp/openclaw-cleanup-build.log', 'utf8'));
  process.exit(1);
}

console.log("==> Seed state");
mkdirSync(`${OPENCLAW_STATE_DIR}/credentials`, { recursive: true });
mkdirSync(`${OPENCLAW_STATE_DIR}/agents/main/sessions`, { recursive: true });
writeFileSync(OPENCLAW_CONFIG_PATH, '{}');
writeFileSync(`${OPENCLAW_STATE_DIR}/credentials/marker.txt`, 'creds');
writeFileSync(`${OPENCLAW_STATE_DIR}/agents/main/sessions/sessions.json`, 'session');

console.log("==> Reset (config+creds+sessions)");
try {
  execSync('pnpm openclaw reset --scope config+creds+sessions --yes --non-interactive', { stdio: ['pipe', '/tmp/openclaw-cleanup-reset.log', '/tmp/openclaw-cleanup-reset.log'] });
} catch (error) {
  console.log(readFileSync('/tmp/openclaw-cleanup-reset.log', 'utf8'));
  process.exit(1);
}

if (existsSync(OPENCLAW_CONFIG_PATH)) {
  console.error(`File ${OPENCLAW_CONFIG_PATH} still exists`);
  process.exit(1);
}

if (existsSync(`${OPENCLAW_STATE_DIR}/credentials`)) {
  console.error(`Directory ${OPENCLAW_STATE_DIR}/credentials still exists`);
  process.exit(1);
}

if (existsSync(`${OPENCLAW_STATE_DIR}/agents/main/sessions`)) {
  console.error(`Directory ${OPENCLAW_STATE_DIR}/agents/main/sessions still exists`);
  process.exit(1);
}

console.log("==> Recreate minimal config");
mkdirSync(`${OPENCLAW_STATE_DIR}/credentials`, { recursive: true });
writeFileSync(OPENCLAW_CONFIG_PATH, '{}');

console.log("==> Uninstall (state only)");
try {
  execSync('pnpm openclaw uninstall --state --yes --non-interactive', { stdio: ['pipe', '/tmp/openclaw-cleanup-uninstall.log', '/tmp/openclaw-cleanup-uninstall.log'] });
} catch (error) {
  console.log(readFileSync('/tmp/openclaw-cleanup-uninstall.log', 'utf8'));
  process.exit(1);
}

if (existsSync(OPENCLAW_STATE_DIR)) {
  console.error(`Directory ${OPENCLAW_STATE_DIR} still exists`);
  process.exit(1);
}

console.log("OK");
