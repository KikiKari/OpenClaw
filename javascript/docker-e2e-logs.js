#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "a52975c76a9b9b37fd6d92b5d34eb1cf184f89a9965da3597f1bd34f45084b70", "source_sha256": "c5da3d5a6d1b96d5dbfcceb3eeaaf1082185c08fa2edcbc7b87c36871484ccf2", "target_language": "javascript"}
// docker-e2e-logs.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/lib/docker-e2e-logs.sh
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawnSync } = require('child_process');

function runLogged(label, command, ...args) {
  const tempDir = process.env.TMPDIR || os.tmpdir();
  const logFilePattern = `openclaw-${label}.XXXXXX.log`;
  const logFilePath = path.join(tempDir, logFilePattern);
  
  // Create temporary file
  const fd = fs.openSync(logFilePath, 'w');
  fs.closeSync(fd);
  
  try {
    // Execute command and redirect output to log file
    const result = spawnSync(command, args, {
      stdio: ['pipe', fs.openSync(logFilePath, 'w'), fs.openSync(logFilePath, 'w')]
    });
    
    // Read log content
    const logContent = fs.readFileSync(logFilePath, 'utf8');
    
    if (result.status !== 0) {
      process.stdout.write(logContent);
      return false;
    }
    
    return true;
  } finally {
    // Clean up log file
    try {
      fs.unlinkSync(logFilePath);
    } catch (e) {
      // Ignore cleanup errors
    }
  }
}
