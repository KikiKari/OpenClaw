#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "989c78d4d3f79a27aa6bc144f24fb7eea4abdee92cfb235ee6a2eb2719fc4a24", "source_sha256": "1b01ca0f5943b16d3905faf557953600ee54f15ecf1dc18c1461585eba94d376", "target_language": "javascript"}
// abstractions-manager-cron.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/abstractions-manager-cron.sh
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

// Set environment variables
process.env.PATH = "/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin";

// Load environment variables from file
const envFilePath = '/home/openclaw/.openclaw/.env';
if (fs.existsSync(envFilePath)) {
  const envContent = fs.readFileSync(envFilePath, 'utf8');
  const envLines = envContent.split('\n');
  
  envLines.forEach(line => {
    if (line.trim() && !line.startsWith('#')) {
      const [key, value] = line.split('=', 2);
      if (key && value !== undefined) {
        process.env[key.trim()] = value.trim().replace(/^['"]|['"]$/g, '');
      }
    }
  });
}

// Check required environment variable
if (!process.env.OPENROUTER_API_KEY) {
  console.error('OPENROUTER_API_KEY fehlt');
  process.exit(1);
}

// Set GITHUB_TOKEN with fallback chain
process.env.GITHUB_TOKEN = process.env.GITHUB_TOKEN || 
                          process.env.GH_TOKEN || 
                          process.env.GH_ACCESS_TOKEN || '';

// File paths
const lockFilePath = '/home/openclaw/.openclaw/locks/abstractions-manager.lock';
const pythonScriptPath = '/home/openclaw/.openclaw/workspace/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py';

// Try to acquire lock and run Python script
const lockDir = path.dirname(lockFilePath);
if (!fs.existsSync(lockDir)) {
  fs.mkdirSync(lockDir, { recursive: true });
}

const flock = spawn('flock', ['--nonblock', lockFilePath, 'python3', pythonScriptPath, ...process.argv.slice(2)]);

flock.stdout.pipe(process.stdout);
flock.stderr.pipe(process.stderr);

flock.on('close', (code) => {
  process.exit(code);
});
