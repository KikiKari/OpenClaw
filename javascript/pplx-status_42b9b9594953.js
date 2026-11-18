#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "5f10339272ea2d0ac4c32226adff9fe23e05ef0ef46c3227b8ff4ff39116e51b", "source_sha256": "0d861748edb257fc44db6425a576fa977cd0d18c0ffb8eefa390f0b87a3116c8", "target_language": "javascript"}
// pplx-status.sh — portiert nach javascript
// Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-status.sh
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

// Quick status of the codespace Perplexity daemon session.
'use strict';

const os = require('os');
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');

const CFG = process.env.PERPLEXITY_CONFIG_DIR || path.join(os.homedir(), '.perplexity-mcp');
const PROFILE = process.env.PERPLEXITY_PROFILE || 'codespace';
const STAT = path.join(CFG, 'profiles', PROFILE, 'daemon-status.json');

if (fs.existsSync(STAT)) {
  const content = fs.readFileSync(STAT, 'utf8');
  try {
    const parsed = JSON.parse(content);
    console.log(JSON.stringify(parsed, null, 2));
  } catch (err) {
    console.error('Invalid JSON in daemon-status.json');
    process.exit(1);
  }
} else {
  console.log(`no daemon-status.json at ${STAT}`);
}

console.log('--- recent auth lines ---');

const logPath = path.join(CFG, 'daemon.log');
if (fs.existsSync(logPath)) {
  const tail = spawn('tail', ['-6'], { stdio: ['pipe', 'inherit', 'inherit'] });
  const grep = spawn('grep', ['-iE', 'Authenticated as user|Account tier|Injected .* cookies|Reinit requested|not-logged-in'], {
    stdio: ['pipe', 'pipe', 'inherit']
  });

  grep.stdout.pipe(tail.stdin);
  tail.on('close', () => {
    // Exit successfully even if grep finds nothing
    process.exit(0);
  });

  const logStream = fs.createReadStream(logPath);
  logStream.pipe(grep.stdin);
  logStream.on('error', () => {
    // Ignore errors, just exit successfully like the original script
    process.exit(0);
  });
} else {
  // No log file, exit successfully
  process.exit(0);
}
