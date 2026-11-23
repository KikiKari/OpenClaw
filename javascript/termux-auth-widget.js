#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "1eac1ab7fc4515e483932b99951ef9173c8a8998da017e2abfef692d114f9ed8", "source_sha256": "5633c73683c9a3e413c1958a2736550b913651537faccecaa22df360eec1c69e", "target_language": "javascript"}
// termux-auth-widget.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-auth-widget.sh
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

const { execSync, spawn } = require('child_process');
const fs = require('fs');

// OpenClaw Auth Widget for Termux
// Place in ~/.shortcuts/ for Termux:Widget
//
// This widget checks auth status and helps with re-auth if needed.
// It's designed for quick one-tap checking from phone home screen.

// Server hostname (via Tailscale or SSH config)
const SERVER = process.env.OPENCLAW_SERVER || 'l36';

function termuxToast(message) {
    try {
        execSync(`termux-toast "${message}"`, { stdio: 'ignore' });
    } catch (e) {
        console.log(`TOAST: ${message}`);
    }
}

function termuxVibrate(duration) {
    try {
        execSync(`termux-vibrate -d ${duration}`, { stdio: 'ignore' });
    } catch (e) {
        // Ignore vibration errors
    }
}

function termuxDialog(type, options = {}) {
    return new Promise((resolve) => {
        const args = [];
        
        if (type === 'radio') {
            args.push('radio');
            if (options.title) args.push('-t', options.title);
            if (options.values) args.push('-v', options.values.join(','));
        } else if (type === 'confirm') {
            args.push('confirm');
            if (options.title) args.push('-t', options.title);
            if (options.text) args.push('-i', options.text);
        }
        
        const proc = spawn('termux-dialog', args);
        let output = '';
        
        proc.stdout.on('data', (data) => {
            output += data.toString();
        });
        
        proc.on('close', () => {
            try {
                const result = JSON.parse(output.trim() || '{}');
                resolve(result);
            } catch (e) {
                resolve({});
            }
        });
    });
}

function termuxOpenUrl(url) {
    try {
        execSync(`termux-open-url "${url}"`, { stdio: 'ignore' });
    } catch (e) {
        console.log(`OPEN URL: ${url}`);
    }
}

function startTermuxActivity() {
    try {
        execSync(`am start -n com.termux/com.termux.app.TermuxActivity -a android.intent.action.MAIN`, { stdio: 'ignore' });
    } catch (e) {
        console.log('START TERMUX ACTIVITY');
    }
}

function sshExec(server, command) {
    try {
        const result = execSync(`ssh "${server}" '${command}'`, { 
            encoding: 'utf8',
            stdio: ['pipe', 'pipe', 'pipe']
        });
        return { stdout: result, exitCode: 0 };
    } catch (error) {
        return { stdout: error.stdout || '', stderr: error.stderr || '', exitCode: error.status };
    }
}

function extractHours(details) {
    try {
        const parsed = JSON.parse(details);
        const status = parsed.claude_code?.status || '';
        const match = status.match(/(\d+)h/);
        return match ? match[1] : '?';
    } catch (e) {
        return '?';
    }
}

async function main() {
    // Check auth status
    termuxToast("Checking OpenClaw auth...");
    
    const statusResult = sshExec(SERVER, '$HOME/openclaw/scripts/claude-auth-status.sh simple');
    const STATUS = statusResult.stdout.trim();
    const EXIT_CODE = statusResult.exitCode;
    
    switch (STATUS) {
        case 'OK':
            // Get remaining time
            const detailsResult = sshExec(SERVER, '$HOME/openclaw/scripts/claude-auth-status.sh json');
            const HOURS = extractHours(detailsResult.stdout);
            
            termuxVibrate(50);
            termuxToast(`Auth OK (${HOURS}h left)`);
            break;
            
        case 'CLAUDE_EXPIRING':
        case 'OPENCLAW_EXPIRING':
            termuxVibrate(100);
            
            // Ask if user wants to re-auth now
            const choice1 = await termuxDialog('radio', {
                title: "Auth Expiring Soon",
                values: ["Re-auth now", "Check later", "Dismiss"]
            });
            
            const SELECTED1 = choice1.text || "Dismiss";
            
            switch (SELECTED1) {
                case "Re-auth now":
                    termuxToast("Opening auth page...");
                    termuxOpenUrl("https://console.anthropic.com/settings/api-keys");
                    
                    // Show instructions
                    await termuxDialog('confirm', {
                        title: "Re-auth Instructions",
                        text: "1. Create/copy API key from browser\n2. Return here and tap OK\n3. SSH to server and paste key"
                    });
                    
                    // Open terminal to server
                    startTermuxActivity();
                    termuxToast(`Run: ssh ${SERVER} '$HOME/openclaw/scripts/mobile-reauth.sh'`);
                    break;
                default:
                    termuxToast("Reminder: Auth expires soon");
                    break;
            }
            break;
            
        case 'CLAUDE_EXPIRED':
        case 'OPENCLAW_EXPIRED':
            termuxVibrate(300);
            
            const choice2 = await termuxDialog('radio', {
                title: "Auth Expired!",
                values: ["Re-auth now", "Dismiss"]
            });
            
            const SELECTED2 = choice2.text || "Dismiss";
            
            switch (SELECTED2) {
                case "Re-auth now":
                    termuxToast("Opening auth page...");
                    termuxOpenUrl("https://console.anthropic.com/settings/api-keys");
                    
                    await termuxDialog('confirm', {
                        title: "Re-auth Steps",
                        text: "1. Create/copy API key from browser\n2. Return here and tap OK to SSH"
                    });
                    
                    startTermuxActivity();
                    termuxToast(`Run: ssh ${SERVER} '$HOME/openclaw/scripts/mobile-reauth.sh'`);
                    break;
                default:
                    termuxToast("Warning: OpenClaw won't work until re-auth");
                    break;
            }
            break;
            
        default:
            termuxVibrate(200);
            termuxToast(`Error: ${STATUS}`);
            break;
    }
}

main().catch(error => {
    console.error('Error:', error.message);
    process.exit(1);
});
