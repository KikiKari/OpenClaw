#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "23020a9ffd0cf3c1e746ad66d4932aa61e1d087c72365a70c230381983705e20", "source_sha256": "1a67bf0d8a66b56fba5df9f18c7370e48304461313b9611ab6f238f553332b50", "target_language": "javascript"}
// auth-monitor.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/auth-monitor.sh
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

// Auth Expiry Monitor
// Run via cron or systemd timer to get proactive notifications
// before Claude Code auth expires.
//
// Suggested cron: */30 * * * * /home/admin/openclaw/scripts/auth-monitor.js
//
// Environment variables:
//   NOTIFY_PHONE - Phone number to send OpenClaw notification (e.g., +1234567890)
//   NOTIFY_NTFY  - ntfy.sh topic for push notifications (e.g., openclaw-alerts)
//   WARN_HOURS   - Hours before expiry to warn (default: 2)

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { spawnSync } from 'child_process';
import https from 'https';

const __filename = fileURLToPath(import.meta.url);
const SCRIPT_DIR = path.dirname(__filename);
const CLAUDE_CREDS = path.join(process.env.HOME, '.claude', '.credentials.json');
const STATE_FILE = path.join(process.env.HOME, '.openclaw', 'auth-monitor-state');

// Configuration
const WARN_HOURS = process.env.WARN_HOURS ? parseInt(process.env.WARN_HOURS) : 2;
const NOTIFY_PHONE = process.env.NOTIFY_PHONE || '';
const NOTIFY_NTFY = process.env.NOTIFY_NTFY || '';

// State tracking to avoid spam
const stateDir = path.dirname(STATE_FILE);
if (!fs.existsSync(stateDir)) {
  fs.mkdirSync(stateDir, { recursive: true });
}

let LAST_NOTIFIED = 0;
if (fs.existsSync(STATE_FILE)) {
  LAST_NOTIFIED = parseInt(fs.readFileSync(STATE_FILE, 'utf8').trim()) || 0;
}
const NOW = Math.floor(Date.now() / 1000);

// Only notify once per hour max
const MIN_INTERVAL = 3600;

function sendNotification(message, priority = 'default') {
  console.log(`${new Date().toISOString().slice(0, 19).replace('T', ' ')} - ${message}`);

  // Check if we notified recently
  if ((NOW - LAST_NOTIFIED) < MIN_INTERVAL) {
    console.log("Skipping notification (sent recently)");
    return;
  }

  // Send via OpenClaw if phone configured and auth still valid
  if (NOTIFY_PHONE) {
    // Check if we can still use openclaw
    try {
      const result = spawnSync(path.join(SCRIPT_DIR, 'claude-auth-status.sh'), ['simple'], { 
        stdio: 'pipe',
        cwd: SCRIPT_DIR
      });
      
      if (result.status === 0) {
        const output = result.stdout.toString();
        if (output.includes('OK') || output.includes('EXPIRING')) {
          console.log(`Sending via OpenClaw to ${NOTIFY_PHONE}...`);
          
          spawnSync('openclaw', ['send', '--to', NOTIFY_PHONE, '--message', message], {
            stdio: 'ignore'
          });
        }
      }
    } catch (error) {
      // Ignore errors
    }
  }

  // Send via ntfy.sh if configured
  if (NOTIFY_NTFY) {
    console.log(`Sending via ntfy.sh to ${NOTIFY_NTFY}...`);
    
    const postData = message;
    const options = {
      hostname: 'ntfy.sh',
      port: 443,
      path: `/${NOTIFY_NTFY}`,
      method: 'POST',
      headers: {
        'Title': 'OpenClaw Auth Alert',
        'Priority': priority,
        'Tags': 'warning,key',
        'Content-Length': Buffer.byteLength(postData)
      }
    };

    const req = https.request(options, (res) => {
      // Ignore response
    });

    req.on('error', (e) => {
      // Ignore errors
    });

    req.write(postData);
    req.end();
  }

  // Update state
  fs.writeFileSync(STATE_FILE, NOW.toString());
}

// Check auth status
if (!fs.existsSync(CLAUDE_CREDS)) {
  sendNotification("Claude Code credentials missing! Run: claude setup-token", "high");
  process.exit(1);
}

try {
  const credsData = JSON.parse(fs.readFileSync(CLAUDE_CREDS, 'utf8'));
  const EXPIRES_AT = credsData.claudeAiOauth?.expiresAt || 0;
  const NOW_MS = NOW * 1000;
  const DIFF_MS = EXPIRES_AT - NOW_MS;
  const HOURS_LEFT = Math.floor(DIFF_MS / 3600000);
  const MINS_LEFT = Math.floor((DIFF_MS % 3600000) / 60000);

  if (DIFF_MS < 0) {
    sendNotification("Claude Code auth EXPIRED! OpenClaw is down. Run: ssh l36 '~/openclaw/scripts/mobile-reauth.sh'", "urgent");
    process.exit(1);
  } else if (HOURS_LEFT < WARN_HOURS) {
    sendNotification(`Claude Code auth expires in ${HOURS_LEFT}h ${MINS_LEFT}m. Consider re-auth soon.`, "high");
    process.exit(0);
  } else {
    console.log(`${new Date().toISOString().slice(0, 19).replace('T', ' ')} - Auth OK: ${HOURS_LEFT}h ${MINS_LEFT}m remaining`);
    process.exit(0);
  }
} catch (error) {
  sendNotification("Error reading Claude Code credentials!", "high");
  process.exit(1);
}
