#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "88196cba836efbd306f7c627257b5b908774092ca126aaf5e602281a6bbc551f", "source_sha256": "9caa03d9bb15f9d91f7e2672653c8c81852b35f9076edf8b7f839f4f06ac7dfd", "target_language": "javascript"}
// translation-worker-node.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

// Run on the selected node after transferring its native worker. JSON stdin is
// forwarded unchanged to the worker in run mode.
'use strict';

const fs = require('fs');
const crypto = require('crypto');
const { spawn } = require('child_process');

if (process.argv.length !== 4) {
  console.error('Usage: translation-worker-node.js node2|node3|node4|node6 prepare|health|run');
  process.exit(2);
}

const node = process.argv[2];
const action = process.argv[3];

let worker, expected;

switch (node) {
  case 'node2':
    worker = '/home/node/.openclaw/workers/translation-worker';
    expected = '565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286';
    break;
  case 'node3':
    worker = '/home/openclaw/.openclaw/workers/translation-worker';
    expected = '9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de';
    break;
  case 'node4':
    worker = '/root/.openclaw/workers/translation-worker';
    expected = '565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286';
    break;
  case 'node6':
    worker = '/home/node/.openclaw/workers/translation-worker';
    expected = '9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de';
    break;
  default:
    console.error('Unknown or non-POSIX node');
    process.exit(2);
}

if (!['prepare', 'health', 'run'].includes(action)) {
  console.error('Unknown action');
  process.exit(2);
}

if (!fs.existsSync(worker) || fs.lstatSync(worker).isSymbolicLink()) {
  console.error(`Missing worker or symlink rejected: ${worker}`);
  process.exit(1);
}

const fileBuffer = fs.readFileSync(worker);
const hashSum = crypto.createHash('sha256');
hashSum.update(fileBuffer);
const actual = hashSum.digest('hex');

if (actual !== expected) {
  console.error(`Worker checksum mismatch: ${worker}`);
  process.exit(1);
}

fs.chmodSync(worker, 0o755);

switch (action) {
  case 'prepare':
    console.log(`Worker verified and executable: ${worker}`);
    break;
  case 'health':
    spawn(worker, ['--health'], { stdio: 'inherit' }).on('error', () => process.exit(1));
    break;
  case 'run':
    spawn(worker, { stdio: 'inherit' }).on('error', () => process.exit(1));
    break;
}
