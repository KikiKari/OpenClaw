#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "1b4998b54facdc86cacf0f34dca2f72f895d2a6a5aaf334b10a376172f70c693", "source_sha256": "2a9ca592fdc915cfb281aa77dde9f07ffd3de83ce5abb8d87c77d46668d75dd6", "target_language": "javascript"}
// openclaw-maintenance.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/openclaw-maintenance.sh
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

import { execSync } from 'child_process';
import { exit } from 'process';

// === 1. Service-/Config-Drift ===
try {
  execSync('openclaw doctor', { stdio: 'inherit' });
} catch (error) {
  console.error('Error executing openclaw doctor');
  exit(1);
}

// === 2. Plugin-Stage (aktive Varianten, NICHT plugins doctor) ===
try {
  execSync('openclaw plugins registry --refresh', { stdio: 'inherit' });
  execSync('openclaw plugins update --all', { stdio: 'inherit' });
} catch (error) {
  console.error('Error updating plugins');
  exit(1);
}

// === 3. Tasks ===
try {
  execSync('openclaw tasks maintenance --apply', { stdio: 'inherit' });
} catch (error) {
  console.error('Error executing tasks maintenance');
  exit(1);
}

// === 4. Sessions – alle Agents auf einmal ===
try {
  execSync('openclaw sessions cleanup --enforce --all-agents', { stdio: 'inherit' });
} catch (error) {
  console.error('Error cleaning up sessions');
  exit(1);
}

// === 5. Memory – status/index decken alle Agents ab ===
try {
  execSync('openclaw memory status --deep --fix', { stdio: 'inherit' });
  execSync('openclaw memory index --force', { stdio: 'inherit' });
} catch (error) {
  console.error('Error executing memory operations');
  exit(1);
}

// === 6. Memory promote – MUSS pro Agent ===
const agents = ['main', 'knecht', 'docs', 'ops-hub', 'cron'];
for (const agent of agents) {
  try {
    execSync(`openclaw memory promote --apply --agent "${agent}"`, { stdio: 'inherit' });
  } catch (error) {
    console.error(`Error promoting memory for agent ${agent}`);
    exit(1);
  }
}

// === 7. Secrets ===
try {
  execSync('openclaw secrets reload', { stdio: 'inherit' });
} catch (error) {
  console.error('Error reloading secrets');
  exit(1);
}
