#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "688412598edc5c882a57dd608e3ebf312bf5ed92bc48f29aad66d6cb70eb3556", "source_sha256": "b0b2d14634c78d492d814989a9bf887ffef50ac058176565e0d55191bb8ac787", "target_language": "javascript"}
// serve_compare_transfer.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway2:scripts/serve_compare_transfer.sh
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const http = require('http');
const url = require('url');

const COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare";
const TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer";
const HOST_IP = "89.58.15.220";
const PORT = 80;
const SELF_PATH = process.argv[1];

// Helper function to get files synchronously
function getFiles(dir) {
  const files = fs.readdirSync(dir)
    .map(file => path.join(dir, file))
    .filter(file => {
      const stat = fs.statSync(file);
      return stat.isFile() && file !== SELF_PATH;
    });
  return files.sort();
}

const FILES = getFiles(COMPARE_DIR);

if (FILES.length === 0) {
  console.log(`Keine Dateien in ${COMPARE_DIR} gefunden.`);
  process.exit(1);
}

console.log();
console.log(`Bereitgestellte Dateien aus ${COMPARE_DIR}:`);
FILES.forEach(src => {
  console.log(`- ${path.basename(src)}`);
});

console.log();
console.log(`Copy/Paste auf anderem Gateway (Download nach ${TRANSFER_DIR}):`);
FILES.forEach(src => {
  const file = path.basename(src);
  console.log(`curl -fL --retry 3 --connect-timeout 10 -o ${TRANSFER_DIR}/${file} http://${HOST_IP}:${PORT}/${file}`);
});

console.log();
console.log(`Server auf Port ${PORT} aktiv. Beenden mit STRG+C.`);
console.log();

// Create HTTP server
const server = http.createServer((req, res) => {
  const pathname = url.parse(req.url).pathname;
  const filePath = path.join(COMPARE_DIR, pathname);

  // Check if file exists and is in our allowed list
  const isAllowedFile = FILES.includes(filePath);

  if (!isAllowedFile) {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('File not found');
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
  console.log(`Server running on http://0.0.0.0:${PORT}/`);
});
