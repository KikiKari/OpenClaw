#!/usr/bin/env node
// serve_compare_transfer.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway2:scripts/serve_compare_transfer.sh
// Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const http = require('http');

const COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare";
const TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer";
const HOST_IP = "89.58.15.220";
const PORT = "80";

// Funktion zum rekursiven Auflisten von Dateien im Verzeichnis (ohne Unterverzeichnisse)
function getFilesSync(dir) {
  let files = [];
  const items = fs.readdirSync(dir);
  
  for (const item of items) {
    const fullPath = path.join(dir, item);
    const stat = fs.statSync(fullPath);
    
    // Nur Dateien auf oberster Ebene berücksichtigen, keine Pfade mit '/'
    if (stat.isFile() && path.dirname(fullPath) === dir) {
      files.push(fullPath);
    }
  }
  
  return files.sort();
}

try {
  const files = getFilesSync(COMPARE_DIR);
  
  // Entferne das Skript selbst aus der Liste
  const selfPath = path.resolve(__filename);
  const filteredFiles = files.filter(file => file !== selfPath);
  
  if (filteredFiles.length === 0) {
    console.log(`Keine Dateien in ${COMPARE_DIR} gefunden.`);
    process.exit(1);
  }
  
  console.log();
  console.log(`Bereitgestellte Dateien aus ${COMPARE_DIR}:`);
  for (const src of filteredFiles) {
    console.log(`- ${path.basename(src)}`);
  }
  
  console.log();
  console.log(`Copy/Paste auf anderem Gateway (Download nach ${TRANSFER_DIR}):`);
  for (const src of filteredFiles) {
    const file = path.basename(src);
    console.log(`curl -fL --retry 3 --connect-timeout 10 -o ${TRANSFER_DIR}/${file} http://${HOST_IP}:${PORT}/${file}`);
  }
  
  console.log();
  console.log(`Server auf Port ${PORT} aktiv. Beenden mit STRG+C.`);
  console.log();
  
  // HTTP-Server erstellen
  const server = http.createServer((req, res) => {
    // Sicherstellen, dass nur Dateien aus COMPARE_DIR bereitgestellt werden
    let filePath = path.join(COMPARE_DIR, path.normalize(req.url));
    
    // Verhindern von Directory Traversal
    if (!filePath.startsWith(COMPARE_DIR + path.sep)) {
      res.writeHead(403, { 'Content-Type': 'text/plain' });
      res.end('Forbidden');
      return;
    }
    
    // Datei senden
    const stream = fs.createReadStream(filePath);
    stream.on('error', () => {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('File not found');
    });
    stream.pipe(res);
  });
  
  server.listen(PORT, '0.0.0.0', () => {
    console.log(`HTTP Server läuft auf 0.0.0.0:${PORT}`);
  });

} catch (err) {
  console.error("Fehler beim Lesen des Verzeichnisses:", err.message);
  process.exit(1);
}
