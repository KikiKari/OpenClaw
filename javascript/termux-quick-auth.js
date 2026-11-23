#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "96eb23a46e1ab93c91a5ea4c1a7edb26fa0d8f5a7188be291dba901a799f1c23", "source_sha256": "32acbaa2d9f84dca0c2fd8f987ab23e0153c0e63d20e7ee9c3e279058ab681c6", "target_language": "javascript"}
// termux-quick-auth.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-quick-auth.sh
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

// Quick Auth Check - Minimal widget for Termux
// Place in ~/.shortcuts/ for Termux:Widget
//
// One-tap: shows status toast
// If expired: directly opens auth URL

const { execSync, spawn } = require('child_process');
const fs = require('fs');

const SERVER = process.env.OPENCLAW_SERVER || 'l36';

let status;
try {
    status = execSync(`ssh -o ConnectTimeout=5 "${SERVER}" '$HOME/openclaw/scripts/claude-auth-status.sh simple'`, {
        timeout: 6000,
        stdio: ['pipe', 'pipe', 'pipe'],
        encoding: 'utf8'
    }).trim();
} catch (error) {
    status = error.stderr ? error.stderr.toString().trim() : error.stdout ? error.stdout.toString().trim() : '';
}

if (status === 'OK') {
    spawn('termux-toast', ['-s', 'Auth OK']);
} else if (status.includes('EXPIRING')) {
    spawn('termux-vibrate', ['-d', '100']);
    spawn('termux-toast', ['Auth expiring soon - tap again if needed']);
} else if (status.includes('EXPIRED') || status.includes('MISSING')) {
    spawn('termux-vibrate', ['-d', '200']);
    spawn('termux-toast', ['Auth expired - opening console...']);
    
    setTimeout(() => {
        spawn('termux-open-url', ['https://console.anthropic.com/settings/api-keys']);
        
        setTimeout(() => {
            const notification = spawn('termux-notification', [
                '-t', 'OpenClaw Re-Auth',
                '-c', `After getting key, run: ssh ${SERVER} '~/openclaw/scripts/mobile-reauth.sh'`,
                '--id', 'openclaw-auth'
            ]);
        }, 2000);
    }, 100);
} else {
    spawn('termux-toast', ['Connection error']);
}
