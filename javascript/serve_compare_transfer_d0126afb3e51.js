#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "4493050343ba162df4529fd66ce1a4f9319109f6481a3dab5e6a34a4648767b9", "source_sha256": "d5eb18db536b690023fd61c3dfa4d99f899ec602247f48fb044c53baebb78556", "target_language": "javascript"}
// serve_compare_transfer.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/serve_compare_transfer.sh
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const http = require('http');
const os = require('os');

const COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare";
const TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer";
const HOST_IP = "152.53.145.65";
const PORT = 80;
const SELF_PATH = __filename;

// Funktion zum rekursiven Durchsuchen von Dateien
function findFiles(dir) {
  let results = [];
  const list = fs.readdirSync(dir);
  
  list.forEach(file => {
    file = path.join(dir, file);
    const stat = fs.statSync(file);
    if (file !== SELF_PATH && stat.isFile()) {
      results.push(file);
    }
  });
  
  return results.sort();
}

const files = findFiles(COMPARE_DIR);

if (files.length === 0) {
  console.log(`Keine Dateien in ${COMPARE_DIR} gefunden.`);
  process.exit(1);
}

console.log();
console.log(`Bereitgestellte Dateien aus ${COMPARE_DIR}:`);
files.forEach(src => {
  console.log(`- ${path.basename(src)}`);
});

console.log();
console.log(`Copy/Paste auf anderem Gateway (Download nach ${TRANSFER_DIR}):`);
files.forEach(src => {
  const file = path.basename(src);
  console.log(`curl -fL --retry 3 --connect-timeout 10 -o ${TRANSFER_DIR}/${file} http://${HOST_IP}:${PORT}/${file}`);
});

console.log();
console.log(`Server auf Port ${PORT} aktiv. Beenden mit STRG+C.`);
console.log();

// HTTP-Server erstellen
const server = http.createServer((req, res) => {
  const filePath = path.join(COMPARE_DIR, path.basename(req.url));
  
  // Sicherheitscheck: Nur Dateien im Vergleichsverzeichnis erlauben
  if (!filePath.startsWith(COMPARE_DIR + path.sep) && filePath !== COMPARE_DIR) {
    res.writeHead(403, { 'Content-Type': 'text/plain' });
    res.end('Forbidden');
    return;
  }

  fs.access(filePath, fs.constants.F_OK, (err) => {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('File not found');
      return;
    }

    const stream = fs.createReadStream(filePath);
    res.writeHead(200);
    stream.pipe(res);
    
    stream.on('error', () => {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Internal Server Error');
    });
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server läuft auf http://0.0.0.0:${PORT}`);
});
