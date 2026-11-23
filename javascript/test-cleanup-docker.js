#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "90e9353ebd402a8c8fed8d37f003541fc35affcaa07a2b69d4486a909347b1ff", "source_sha256": "df77fd3273a53bf6d33c1c4df50c24d9526e06de477779a9b7a58f5b8ce3ed1d", "target_language": "javascript"}
// test-cleanup-docker.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/test-cleanup-docker.sh
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

import { spawnSync } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { existsSync } from 'fs';

// Ermittle das Stammverzeichnis (entspricht ROOT_DIR in Bash)
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const ROOT_DIR = join(__dirname, '..');

// Lade die Logging-Funktion (vereinfachte Version von docker-e2e-logs.sh)
function run_logged(name, command, args) {
  console.log(`Running: ${command} ${args.join(' ')}`);
  const result = spawnSync(command, args, { 
    stdio: 'inherit',
    shell: true
  });
  
  if (result.status !== 0) {
    throw new Error(`${name} failed with exit code ${result.status}`);
  }
}

// Umgebungsvariablen mit Standardwerten (entspricht IMAGE_NAME und PLATFORM in Bash)
const IMAGE_NAME = process.env.OPENCLAW_CLEANUP_SMOKE_IMAGE || 'openclaw-cleanup-smoke:local';
const PLATFORM = process.env.OPENCLAW_CLEANUP_SMOKE_PLATFORM || 'linux/amd64';

console.log(`==> Build image: ${IMAGE_NAME}`);

// Führe den Build-Befehl aus (entspricht run_logged cleanup-build docker build ...)
run_logged('cleanup-build', 'docker', [
  'build',
  '-t', IMAGE_NAME,
  '-f', join(ROOT_DIR, 'scripts/docker/cleanup-smoke/Dockerfile'),
  ROOT_DIR
]);

console.log('==> Run cleanup smoke test');

// Führe den Docker-Run-Befehl aus
const runResult = spawnSync('docker', [
  'run', '--rm', '--platform', PLATFORM, '-t', IMAGE_NAME
], { 
  stdio: 'inherit',
  shell: true
});

if (runResult.status !== 0) {
  process.exit(runResult.status || 1);
}
