#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "1318e013d7afd8b3a277b00265aea41e357ce0b0a44b8090bfc5b557bc21a430", "source_sha256": "f1fb75db28e47070c42c0b401c9bdae5ac468bcd98550232038e409983691fad", "target_language": "javascript"}
// chat.css — portiert nach javascript
// Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat.css
// Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

import { writeFileSync } from 'fs';
import { resolve } from 'path';

// Funktion zum Erstellen der CSS-Imports
function createCSSImports() {
  const imports = [
    './chat/layout.css',
    './chat/text.css',
    './chat/grouped.css',
    './chat/tool-cards.css',
    './chat/sidebar.css'
  ];

  return imports.map(importPath => `@import "${importPath}";`).join('\n');
}

// Hauptfunktion zum Schreiben der CSS-Datei
function writeChatCSS(outputPath) {
  const cssContent = createCSSImports();
  writeFileSync(resolve(outputPath), cssContent + '\n');
}

// Überprüfe Kommandozeilenargumente
if (process.argv.length !== 3) {
  console.error('Verwendung: node chat-css-generator.js <ausgabedatei>');
  process.exit(1);
}

// Führe die Generierung aus
const outputFile = process.argv[2];
writeChatCSS(outputFile);

console.log(`CSS-Datei wurde erfolgreich erstellt: ${outputFile}`);
