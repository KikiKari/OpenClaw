#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "08530a44745035a850b4a14b443b4dd61996926eaf234fb08518a36f760fdcce", "source_sha256": "f85931ea8f1a58309ac3ba2c5899fd4b8f2c55777f90b132269efd74bb35362b", "target_language": "javascript"}
// setup-xvfb-node3.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node3.sh
// auch in: OpenClaw@gateway2:scripts/setup-xvfb-node3.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Hilfsfunktion zum Ausführen von Shell-Befehlen
function run(command, options = {}) {
  try {
    const result = execSync(command, {
      stdio: ['pipe', 'pipe', 'ignore'],
      ...options
    });
    return result.toString().trim();
  } catch (error) {
    if (!options.ignoreErrors) {
      throw error;
    }
    return '';
  }
}

console.log("=== Xvfb + Chromium Setup für Node 3 ===");
console.log("=== Entferne altes VNC-Setup ===");

// Altes VNC stoppen & entfernen (falls vorhanden)
try {
  run('sudo systemctl stop vncserver@*', { ignoreErrors: true });
  run('sudo systemctl disable vncserver@*', { ignoreErrors: true });
  run('sudo apt-get remove -y tightvncserver tigervnc-standalone-server', { ignoreErrors: true });
  
  // Entferne VNC-Dateien
  const homeVncDir = path.join(require('os').homedir(), '.vnc');
  if (fs.existsSync(homeVncDir)) {
    run(`sudo rm -rf ${homeVncDir}`);
  }
  
  // Entferne X11 Unix Sockets
  const x11SocketDir = '/tmp/.X11-unix';
  if (fs.existsSync(x11SocketDir)) {
    const files = fs.readdirSync(x11SocketDir);
    files.forEach(file => {
      if (file.startsWith('X')) {
        try {
          fs.unlinkSync(path.join(x11SocketDir, file));
        } catch (e) {
          // Ignoriere Fehler beim Löschen einzelner Dateien
        }
      }
    });
  }
} catch (e) {
  // Ignoriere Fehler beim Entfernen alter VNC-Komponenten
}

console.log("=== Installiere Xvfb + Chromium ===");

// Update & Install
run('sudo apt-get update');
run(`sudo apt-get install -y \
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
WantedBy=multi-user.target`;

const servicePath = '/etc/systemd/system/xvfb.service';
try {
  fs.writeFileSync(servicePath, serviceContent);
} catch (e) {
  console.error('Fehler beim Schreiben der Service-Datei:', e.message);
  process.exit(1);
}

// Service aktivieren
run('sudo systemctl daemon-reload');
run('sudo systemctl enable xvfb');
run('sudo systemctl start xvfb');

console.log("=== Xvfb läuft auf DISPLAY :99 ===");
console.log("Chromium Version:");

try {
  const versionOutput = run('chromium --version');
  console.log(versionOutput);
} catch (e) {
  console.log("Chromium nicht gefunden");
}

console.log("=== Setup abgeschlossen ===");
console.log("=== Altes VNC-Setup wurde entfernt ===");
