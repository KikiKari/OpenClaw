#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "19e3a8dfb85f5dbb2e0036080e6e5d479233e74e1abcfc481e32e911c39d39b5", "source_sha256": "580708ba8136a21db9caeff52911141c9a4f2ed6daed6f9b9dacaaf4beae3f0b", "target_language": "javascript"}
// setup-xvfb-node2.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node2.sh
// auch in: OpenClaw@gateway2:scripts/setup-xvfb-node2.sh
// Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Farbkonstanten für die Ausgabe
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  cyan: '\x1b[36m'
};

function log(message) {
  console.log(`${colors.cyan}=== ${message} ===${colors.reset}`);
}

function runCommand(command, options = {}) {
  try {
    return execSync(command, { 
      stdio: 'inherit', 
      ...options 
    });
  } catch (error) {
    if (!options.ignoreErrors) {
      throw error;
    }
  }
}

function main() {
  console.log(`${colors.bright}Xvfb Setup für Node 2 (Netcup VPS)${colors.reset}`);
  console.log(`${colors.bright}Erstellt: 2026-04-09${colors.reset}\n`);

  log('Xvfb + Chromium Setup für Node 2');

  // Update & Install
  runCommand('sudo apt-get update');
  runCommand(`sudo apt-get install -y \
    xvfb \
    chromium-browser \
    chromium-chromedriver \
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
User=openclaw
ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target`;

  const servicePath = '/etc/systemd/system/xvfb.service';
  
  try {
    fs.writeFileSync(servicePath, serviceContent);
  } catch (error) {
    console.error('Fehler beim Schreiben der Service-Datei:', error.message);
    process.exit(1);
  }

  // Service aktivieren
  runCommand('sudo systemctl daemon-reload');
  runCommand('sudo systemctl enable xvfb');
  runCommand('sudo systemctl start xvfb');

  log('Xvfb läuft auf DISPLAY :99');
  
  console.log('Chromium Version:');
  runCommand('chromium-browser --version', { ignoreErrors: true });

  log('Setup abgeschlossen');
}

if (require.main === module) {
  main();
}
