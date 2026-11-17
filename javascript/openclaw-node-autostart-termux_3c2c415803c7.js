#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "fbf919dbe034a5e218684870c2402783cd5c297dbbea442764749453752c3282", "source_sha256": "dd115a5287b5db772bd4af098a6620a66b294c0e327633048101753a48a3976b", "target_language": "javascript"}
// openclaw-node-autostart-termux.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/openclaw-node-autostart-termux.sh
// auch in: OpenClaw@gateway2:scripts/openclaw-node-autostart-termux.sh
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const { spawn, execSync } = require('child_process');
const path = require('path');

const SESSION = 'openclaw-node';
const LOGFILE = path.join(process.env.HOME, '.openclaw', 'node.log');
const GATEWAY = '10.10.0.1';
const PORT = '18789';

// Log-Verzeichnis erstellen
const logDir = path.dirname(LOGFILE);
if (!fs.existsSync(logDir)) {
    fs.mkdirSync(logDir, { recursive: true });
}

function logMessage(message) {
    const timestamp = new Date().toISOString().replace(/T/, ' ').replace(/\..+/, '');
    const logEntry = `[${timestamp}] ${message}\n`;
    fs.appendFileSync(LOGFILE, logEntry);
    return logEntry.trim();
}

function checkTmuxSession() {
    try {
        execSync(`tmux has-session -t ${SESSION}`, { stdio: 'ignore' });
        return true;
    } catch (error) {
        return false;
    }
}

function pingGateway(gateway) {
    return new Promise((resolve) => {
        const ping = spawn('ping', ['-c', '1', '-W', '3', gateway], { stdio: 'ignore' });
        
        ping.on('close', (code) => {
            resolve(code === 0);
        });
        
        // Timeout nach 5 Sekunden
        setTimeout(() => {
            ping.kill();
            resolve(false);
        }, 5000);
    });
}

async function startOpenClaw() {
    logMessage('Starting OpenClaw Node Mode...');
    
    // Prüfe WireGuard Verbindung
    const isReachable = await pingGateway(GATEWAY);
    if (!isReachable) {
        logMessage(`FEHLER: WireGuard Gateway ${GATEWAY} nicht erreichbar!`);
        logMessage('Warte 10 Sekunden...');
        await new Promise(resolve => setTimeout(resolve, 10000));
        return false;
    }
    
    return new Promise((resolve) => {
        const openclaw = spawn('openclaw', ['node', 'run', '--host', GATEWAY, '--port', PORT], {
            stdio: ['pipe', 'pipe', 'pipe']
        });
        
        openclaw.stdout.on('data', (data) => {
            process.stdout.write(data);
            fs.appendFileSync(LOGFILE, data);
        });
        
        openclaw.stderr.on('data', (data) => {
            process.stderr.write(data);
            fs.appendFileSync(LOGFILE, data);
        });
        
        openclaw.on('close', (code) => {
            logMessage(`OpenClaw beendet mit Code ${code}. Neustart in 5 Sekunden...`);
            resolve(true);
        });
        
        openclaw.on('error', (error) => {
            logMessage(`FEHLER beim Starten von OpenClaw: ${error.message}`);
            resolve(true);
        });
    });
}

async function mainLoop() {
    while (true) {
        await startOpenClaw();
        await new Promise(resolve => setTimeout(resolve, 5000));
    }
}

// Prüfen ob tmux Session bereits läuft
if (checkTmuxSession()) {
    logMessage(`OpenClaw Node läuft bereits in tmux Session '${SESSION}'`);
    process.exit(0);
}

logMessage(`OpenClaw Node Autostart aktiviert (tmux Session: ${SESSION})`);

// Optional: tmux attach Hinweis falls interaktiv gestartet
if (process.stdin.isTTY) {
    console.log(`OpenClaw Node Mode gestartet in tmux Session '${SESSION}'`);
    console.log(`Zum Anschauen: tmux attach -t ${SESSION}`);
    console.log(`Log-Datei: ${LOGFILE}`);
}

// Neue tmux Session erstellen und OpenClaw starten
const tmuxCommand = `tmux new-session -d -s ${SESSION} -n node node ${__filename}`;
execSync(tmuxCommand, { stdio: 'inherit' });
