#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "0ae0bb818234f27f2f2c2be8f66d1d4b135a7a8ba87e37c747a24908b774b9f9", "source_sha256": "fe4cfd779f66ea7706f9bdfe3744e5d0a5b102609de3aca3ad086e40c76e8a2f", "target_language": "javascript"}
// build-and-run-mac.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/build-and-run-mac.sh
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

const { execSync, spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const __dirname = path.dirname(process.argv[1]);
process.chdir(path.join(__dirname, '../apps/macos'));

const BUILD_PATH = '.build-local';
const PRODUCT = 'OpenClaw';
const BIN = path.join(BUILD_PATH, 'debug', PRODUCT);

console.log(`\n▶️  Building ${PRODUCT} (debug, build path: ${BUILD_PATH})`);
execSync(`swift build -c debug --product "${PRODUCT}" --build-path "${BUILD_PATH}"`, { stdio: 'inherit' });

console.log(`\n⏹  Stopping existing ${PRODUCT}...`);
try {
  execSync(`killall -q "${PRODUCT}"`, { stdio: 'ignore' });
} catch (error) {
  // Ignore error if process doesn't exist
}

console.log(`\n🚀 Launching ${BIN} ...`);
const child = spawn(BIN, [], {
  detached: true,
  stdio: ['ignore', fs.openSync('/tmp/openclaw.log', 'w'), fs.openSync('/tmp/openclaw.log', 'w')]
});

child.unref();
console.log(`Started ${PRODUCT} (PID ${child.pid}). Logs: /tmp/openclaw.log`);
