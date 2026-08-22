#!/usr/bin/env node
// pplx-status.sh — portiert nach javascript
// Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-status.sh
// Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

// Quick status of the codespace Perplexity daemon session.
'use strict';

const os = require('os');
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');

const CFG = process.env.PERPLEXITY_CONFIG_DIR || path.join(os.homedir(), '.perplexity-mcp');
const PROFILE = process.env.PERPLEXITY_PROFILE || 'codespace';
const STAT = path.join(CFG, 'profiles', PROFILE, 'daemon-status.json');

// Display daemon status file content
if (fs.existsSync(STAT)) {
  const content = fs.readFileSync(STAT, 'utf8');
  try {
    const parsed = JSON.parse(content);
    console.log(JSON.stringify(parsed, null, 2));
  } catch (err) {
    console.log(content);
  }
} else {
  console.log(`no daemon-status.json at ${STAT}`);
}

console.log('--- recent auth lines ---');

// Display recent authentication lines from daemon log
const logPath = path.join(CFG, 'daemon.log');
if (fs.existsSync(logPath)) {
  const logContent = fs.readFileSync(logPath, 'utf8');
  const lines = logContent.split('\n')
    .filter(line => 
      line.toLowerCase().includes('authenticated as user') ||
      line.toLowerCase().includes('account tier') ||
      line.toLowerCase().includes('injected') && line.toLowerCase().includes('cookies') ||
      line.toLowerCase().includes('reinit requested') ||
      line.toLowerCase().includes('not-logged-in')
    )
    .slice(-6);
  
  lines.forEach(line => console.log(line));
}
