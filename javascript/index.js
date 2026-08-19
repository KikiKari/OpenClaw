#!/usr/bin/env node
// index.css — portiert nach javascript
// Quelle: css, OpenClaw@main:src/index.css
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');

// CSS-Inhalt als strukturiertes Objekt
const cssRules = {
  body: {
    margin: '0',
    'font-family': [
      '-apple-system',
      'BlinkMacSystemFont',
      "'Segoe UI'",
      "'Roboto'",
      "'Oxygen'",
      "'Ubuntu'",
      "'Cantarell'",
      "'Fira Sans'",
      "'Droid Sans'",
      "'Helvetica Neue'",
      'sans-serif'
    ].join(', '),
    '-webkit-font-smoothing': 'antialiased',
    '-moz-osx-font-smoothing': 'grayscale'
  },
  code: {
    'font-family': [
      'source-code-pro',
      'Menlo',
      'Monaco',
      'Consolas',
      "'Courier New'",
      'monospace'
    ].join(', ')
  }
};

// Funktion zum Erzeugen des CSS-Strings
function generateCSS(rules) {
  let cssString = '';
  
  for (const [selector, properties] of Object.entries(rules)) {
    cssString += `${selector} {\n`;
    
    for (const [property, value] of Object.entries(properties)) {
      cssString += `  ${property}: ${value};\n`;
    }
    
    cssString += '}\n\n';
  }
  
  return cssString.trim();
}

// Hauptfunktion
function main() {
  // Prüfe Kommandozeilenargumente
  if (process.argv.length < 3) {
    console.error('Verwendung: node index.js <ausgabedatei>');
    process.exit(1);
  }

  const outputFile = process.argv[2];
  const cssContent = generateCSS(cssRules);
  
  // Stelle sicher, dass das Ausgabeverzeichnis existiert
  const outputDir = path.dirname(outputFile);
  if (outputDir && !fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }
  
  // Schreibe CSS in Datei
  fs.writeFileSync(outputFile, cssContent, 'utf8');
  
  console.log(`CSS-Datei wurde erfolgreich erstellt: ${outputFile}`);
}

main();
