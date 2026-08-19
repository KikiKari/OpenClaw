#!/usr/bin/env node
// openclaw-node-autostart-termux.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/openclaw-node-autostart-termux.sh
// auch in: OpenClaw@gateway2:scripts/openclaw-node-autostart-termux.sh
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

// OpenClaw Node Mode Autostart für Termux (Node 5 - Redmi Note 11)
// Installiert nach: ~/.termux/boot/openclaw-node.js
// Getestet mit: Termux + Android + OpenClaw

const SESSION = "openclaw-node";
const LOGFILE = `${process.env.HOME}/.openclaw/node.log`;
const GATEWAY = "10.10.0.1";
const PORT = "18789";

const fs = require('fs');
const { spawn, execSync } = require('child_process');

// Log-Verzeichnis erstellen
try {
  fs.mkdirSync(`${process.env.HOME}/.openclaw`, { recursive: true });
} catch (err) {
  // Verzeichnis existiert bereits oder Fehler beim Erstellen
}

// Hilfsfunktion zum Schreiben ins Log
function log(message) {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] ${message}\n`;
  fs.appendFileSync(LOGFILE, logMessage);
  if (process.stdin.isTTY) {
    console.log(`${message}`);
  }
}

// Prüfen ob tmux Session bereits läuft
function isTmuxSessionRunning(sessionName) {
  try {
    execSync(`tmux has-session -t "${sessionName}"`, { stdio: 'ignore' });
    return true;
  } catch (error) {
    return false;
  }
}

if (isTmuxSessionRunning(SESSION)) {
  log(`OpenClaw Node läuft bereits in tmux Session '${SESSION}'`);
  process.exit(0);
}

// Neue tmux Session erstellen und OpenClaw starten
const scriptContent = `
while true; do
    echo "[$(date)] Starting OpenClaw Node Mode..." | tee -a '${LOGFILE}'
    
    # Prüfe WireGuard Verbindung
    if ! ping -c 1 -W 3 ${GATEWAY} >/dev/null 2>&1; then
        echo "[$(date)] FEHLER: WireGuard Gateway ${GATEWAY} nicht erreichbar!" | tee -a '${LOGFILE}'
        echo "[$(date)] Warte 10 Sekunden..." | tee -a '${LOGFILE}'
        sleep 10
        continue
    fi
    
    # OpenClaw Node Mode starten
    openclaw node run --host ${GATEWAY} --port ${PORT} 2>&1 | tee -a '${LOGFILE}'
    
    # Wenn der Prozess endet, warte und neustarten
    echo "[$(date)] OpenClaw beendet. Neustart in 5 Sekunden..." | tee -a '${LOGFILE}'
    sleep 5
done
`;

const tmuxProcess = spawn('tmux', [
  'new-session', '-d', '-s', SESSION, '-n', 'node', scriptContent
]);

tmuxProcess.on('close', (code) => {
  log(`OpenClaw Node Autostart aktiviert (tmux Session: ${SESSION})`);
  
  // Optional: tmux attach Hinweis falls interaktiv gestartet
  if (process.stdin.isTTY) {
    console.log(`OpenClaw Node Mode gestartet in tmux Session '${SESSION}'`);
    console.log(`Zum Anschauen: tmux attach -t ${SESSION}`);
    console.log(`Log-Datei: ${LOGFILE}`);
  }
});
