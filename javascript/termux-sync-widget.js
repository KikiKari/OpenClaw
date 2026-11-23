#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "eb1be9cd3816166cf355177ee0daae9b76cb6fc504c3de2e5be918f4446894e3", "source_sha256": "5a61490f9c6c3ae52acdce976cbcad0d09396f906ddb85d7ae357ab98e762893", "target_language": "javascript"}
// termux-sync-widget.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-sync-widget.sh
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

// OpenClaw OAuth Sync Widget
// Syncs Claude Code tokens to OpenClaw on l36 server
// Place in ~/.shortcuts/ on phone for Termux:Widget

import { execSync } from 'child_process';
import { exit } from 'process';

// Helper function to execute termux commands
function termuxToast(message) {
    try {
        execSync(`termux-toast "${message}"`, { stdio: 'ignore' });
    } catch (e) {
        // Ignore toast errors
    }
}

function termuxVibrate(duration) {
    try {
        execSync(`termux-vibrate -d ${duration}`, { stdio: 'ignore' });
    } catch (e) {
        // Ignore vibrate errors
    }
}

termuxToast("Syncing OpenClaw auth...");

// Run sync on l36 server
const server = process.env.OPENCLAW_SERVER || 'l36';
let result = '';
let exitCode = 0;

try {
    result = execSync(
        `ssh "${server}" '/home/admin/openclaw/scripts/sync-claude-code-auth.sh'`,
        { encoding: 'utf8' }
    );
} catch (error) {
    result = error.stdout ? error.stdout.toString() : error.toString();
    exitCode = error.status || 1;
}

if (exitCode === 0) {
    // Extract expiry time from output
    let expiry = "";
    const lines = result.split('\n');
    for (const line of lines) {
        if (line.includes("Token expires:")) {
            expiry = line.split(":").slice(1).join(":").trim();
            break;
        }
    }

    termuxVibrate(100);
    termuxToast(`OpenClaw synced! Expires:${expiry}`);

    // Optional: restart openclaw service
    try {
        execSync(`ssh "${server}" 'systemctl --user restart openclaw'`, {
            stdio: 'ignore'
        });
    } catch (e) {
        // Ignore restart errors
    }
} else {
    termuxVibrate(300);
    termuxToast(`Sync failed: ${result.trim()}`);
}

exit(exitCode);
