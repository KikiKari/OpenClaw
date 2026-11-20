#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "a304b903e11919a1be20ea01726e1a714b608c5a60dcb606027be47ae20aa16c", "source_sha256": "994170e8e95ae7e8bd7564512b31b67821e81c5b77b3b9fd41bad3d0fc2ee46c", "target_language": "javascript"}
// ios-pull-gateway-log.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/dev/ios-pull-gateway-log.sh
// Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

import { execSync } from 'child_process';
import { readFileSync } from 'fs';
import process from 'process';

const DEVICE_UDID = process.argv[2] || '00008130-000630CE0146001C';
const BUNDLE_ID = process.argv[3] || 'ai.openclaw.ios.dev.mariano.test';
const DEST = process.argv[4] || '/tmp/openclaw-gateway.log';

// Copy log file from iOS device
execSync(
  `xcrun devicectl device copy from \
  --device "${DEVICE_UDID}" \
  --domain-type appDataContainer \
  --domain-identifier "${BUNDLE_ID}" \
  --source Documents/openclaw-gateway.log \
  --destination "${DEST}"`,
  { stdio: 'pipe' }
);

console.log(`Pulled to: ${DEST}`);

// Read and display last 200 lines
const content = readFileSync(DEST, 'utf8');
const lines = content.split('\n');
const lastLines = lines.slice(-200);
console.log(lastLines.join('\n'));
