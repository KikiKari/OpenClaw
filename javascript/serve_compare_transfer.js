#!/usr/bin/env node
// serve_compare_transfer.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/serve_compare_transfer.sh
// Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const http = require('http');
const os = require('os');

const COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare";
const TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer";
const HOST_IP = "152.53.145.65";
const PORT = 80;
const SELF_PATH = __filename;

// Funktion zum sicheren Lesen eines Verzeichnisses
function readDirSafe(dirPath) {
  try {
    return fs.readdirSync(dirPath);
  } catch (err) {
    if (err.code === 'ENOENT') {
      console.error(`Verzeichnis ${dirPath} existiert nicht.`);
      process.exit(1);
    }
    throw err;
  }
}

// Filtert Dateien und entfernt das Skript selbst
function getFiles(dirPath, selfPath) {
  const entries = readDirSafe(dirPath);
  return entries
    .map(entry => path.join(dirPath, entry))
    .filter(entry => {
      try {
        const stat = fs.statSync(entry);
        return stat.isFile() && entry !== selfPath;
      } catch (err) {
        return false;
      }
    })
    .sort();
}

const files = getFiles(COMPARE_DIR, SELF_PATH);

if (files.length === 0) {
  console.log(`Keine Dateien in ${COMPARE_DIR} gefunden.`);
  process.exit(1);
}

console.log('');
console.log(`Bereitgestellte Dateien aus ${COMPARE_DIR}:`);
files.forEach(src => {
  console.log(`- ${path.basename(src)}`);
});

console.log('');
console.log('Copy/Paste auf anderem Gateway (Download nach ${TRANSFER_DIR}):');
files.forEach(src => {
  const file = path.basename(src);
  console.log(`curl -fL --retry 3 --connect-timeout 10 -o ${TRANSFER_DIR}/${file} http://${HOST_IP}:${PORT}/${file}`);
});

console.log('');
console.log(`Server auf Port ${PORT} aktiv. Beenden mit STRG+C.`);
console.log('');

// HTTP-Server erstellen
const server = http.createServer((req, res) => {
  const filePath = path.join(COMPARE_DIR, req.url === '/' ? 'index.html' : req.url);
  
  // Sicherstellen, dass der Pfad innerhalb des COMPARE_DIR bleibt
  const resolvedPath = path.resolve(filePath);
  if (!resolvedPath.startsWith(path.resolve(COMPARE_DIR))) {
    res.writeHead(403, { 'Content-Type': 'text/plain' });
    res.end('Forbidden');
    return;
  }

  fs.readFile(resolvedPath, (err, data) => {
    if (err) {
      if (err.code === 'ENOENT') {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('File not found');
      } else {
        res.writeHead(500, { 'Content-Type': 'text/plain' });
        res.end('Internal Server Error');
      }
      return;
    }

    // Einfache MIME-Typ-Bestimmung
    const ext = path.extname(resolvedPath).toLowerCase();
    let contentType = 'application/octet-stream';
    if (ext === '.html') contentType = 'text/html';
    else if (ext === '.css') contentType = 'text/css';
    else if (ext === '.js') contentType = 'text/javascript';
    else if (ext === '.json') contentType = 'application/json';
    else if (ext === '.png') contentType = 'image/png';
    else if (ext === '.jpg' || ext === '.jpeg') contentType = 'image/jpeg';
    else if (ext === '.gif') contentType = 'image/gif';
    else if (ext === '.txt') contentType = 'text/plain';

    res.writeHead(200, { 'Content-Type': contentType });
    res.end(data);
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`HTTP-Server lÃ¤uft auf http://0.0.0.0:${PORT}/`);
});
