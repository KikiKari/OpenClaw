#!/usr/bin/env node
// setup-xvfb-node3.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node3.sh
// auch in: OpenClaw@gateway2:scripts/setup-xvfb-node3.sh
// Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Farben für die Ausgabe
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  blue: '\x1b[34m',
  green: '\x1b[32m',
  red: '\x1b[31m'
};

function log(message, color = colors.reset) {
  console.log(`${color}${message}${colors.reset}`);
}

function runCommand(command, options = {}) {
  try {
    const result = execSync(command, { 
      stdio: 'inherit',
      ...options
    });
    return result;
  } catch (error) {
    if (!options.ignoreErrors) {
      process.exit(1);
    }
  }
}

log("=== Xvfb + Chromium Setup für Node 3 ===", colors.bright);
log("=== Entferne altes VNC-Setup ===", colors.bright);

// Altes VNC stoppen & entfernen (falls vorhanden)
try {
  runCommand('sudo systemctl stop vncserver@* 2>/dev/null', { ignoreErrors: true });
} catch (e) {}

try {
  runCommand('sudo systemctl disable vncserver@* 2>/dev/null', { ignoreErrors: true });
} catch (e) {}

try {
  runCommand('sudo apt-get remove -y tightvncserver tigervnc-standalone-server 2>/dev/null', { ignoreErrors: true });
} catch (e) {}

try {
  runCommand('sudo rm -rf ~/.vnc /tmp/.X11-unix/X*', { ignoreErrors: true });
} catch (e) {}

log("=== Installiere Xvfb + Chromium ===", colors.bright);

// Update & Install
runCommand('sudo apt-get update');
runCommand(`sudo apt-get install -y \
    xvfb \
    chromium \
    chromium-driver \
    fonts-liberation \
    libappindicator3-1 \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libxss1 \
    xdg-utils`);

// Xvfb Systemd Service erstellen
const serviceContent = `[Unit]
Description=X Virtual Framebuffer
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
`;

const servicePath = '/etc/systemd/system/xvfb.service';
try {
  fs.writeFileSync(servicePath, serviceContent);
} catch (error) {
  log(`Fehler beim Schreiben der Service-Datei: ${error.message}`, colors.red);
  process.exit(1);
}

// Service aktivieren
runCommand('sudo systemctl daemon-reload');
runCommand('sudo systemctl enable xvfb');
runCommand('sudo systemctl start xvfb');

log("=== Xvfb läuft auf DISPLAY :99 ===", colors.green);
log("Chromium Version:", colors.bright);

try {
  runCommand('chromium --version');
} catch (e) {
  log("Chromium nicht gefunden", colors.red);
}

log("=== Setup abgeschlossen ===", colors.green);
log("=== Altes VNC-Setup wurde entfernt ===", colors.green);
