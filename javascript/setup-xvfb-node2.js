#!/usr/bin/env node
// setup-xvfb-node2.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node2.sh
// auch in: OpenClaw@gateway2:scripts/setup-xvfb-node2.sh
// Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Farbkonstanten für die Ausgabe
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  yellow: '\x1b[33m'
};

function log(message, color = colors.reset) {
  console.log(color + message + colors.reset);
}

function runCommand(command, options = {}) {
  try {
    const result = execSync(command, { 
      stdio: 'inherit', 
      ...options,
      shell: '/bin/bash'
    });
    return result;
  } catch (error) {
    if (!options.ignoreError) {
      process.exit(1);
    }
  }
}

function main() {
  log("=== Xvfb + Chromium Setup für Node 2 ===", colors.bright);

  // Update & Install
  runCommand('sudo apt-get update');
  
  const packages = [
    'xvfb',
    'chromium-browser',
    'chromium-chromedriver',
    'fonts-liberation',
    'libappindicator3-1',
    'libasound2',
    'libatk-bridge2.0-0',
    'libatk1.0-0',
    'libcups2',
    'libgtk-3-0',
    'libnspr4',
    'libnss3',
    'libxss1',
    'xdg-utils'
  ];
  
  runCommand(`sudo apt-get install -y ${packages.join(' \\\n    ')}`);

  // Xvfb Systemd Service erstellen
  const serviceContent = `[Unit]
Description=X Virtual Framebuffer
After=network.target

[Service]
Type=simple
User=openclaw
ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target`;

  const servicePath = '/etc/systemd/system/xvfb.service';
  
  try {
    // Schreibe die Service-Datei mit Root-Rechten
    fs.writeFileSync('/tmp/xvfb.service', serviceContent);
    runCommand(`sudo mv /tmp/xvfb.service ${servicePath}`);
    runCommand('sudo chown root:root ' + servicePath);
  } catch (error) {
    log('Fehler beim Erstellen der Service-Datei', colors.yellow);
    process.exit(1);
  }

  // Service aktivieren
  runCommand('sudo systemctl daemon-reload');
  runCommand('sudo systemctl enable xvfb');
  runCommand('sudo systemctl start xvfb');

  log("=== Xvfb läuft auf DISPLAY :99 ===", colors.green);
  
  log("Chromium Version:");
  runCommand('chromium-browser --version', { ignoreError: true }) || 
    log("Chromium nicht gefunden");

  log("=== Setup abgeschlossen ===", colors.bright);
}

if (require.main === module) {
  main();
}
