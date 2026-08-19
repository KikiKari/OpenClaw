#!/usr/bin/env node
// App.css — portiert nach javascript
// Quelle: css, OpenClaw@main:src/App.css
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');

// Funktion zum Erstellen eines CSS-Regelobjekts
function createRule(selector, properties) {
  return { selector, properties };
}

// Funktion zum Konvertieren eines Regelobjekts in einen CSS-String
function ruleToString(rule) {
  const props = Object.entries(rule.properties)
    .map(([key, value]) => `  ${key}: ${value};`)
    .join('\n');
  
  return `${rule.selector} {\n${props}\n}`;
}

// Funktion zum Zusammenführen mehrerer Regeln zu einem CSS-String
function generateCSS(rules) {
  return rules.map(ruleToString).join('\n\n');
}

// Definition der CSS-Regeln
const cssRules = [
  createRule(':root', {
    'color-scheme': 'dark',
    'font-family': 'Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    'background': '#0b1020',
    'color': '#eef2ff'
  }),

  createRule('*', {
    'box-sizing': 'border-box'
  }),

  createRule('body', {
    'margin': '0',
    'min-width': '320px',
    'min-height': '100vh',
    'background': 'radial-gradient(circle at 20% 20%, rgba(56, 189, 248, 0.22), transparent 30rem), radial-gradient(circle at 80% 10%, rgba(168, 85, 247, 0.2), transparent 28rem), linear-gradient(135deg, #050816 0%, #111827 55%, #172033 100%)'
  }),

  createRule('.page-shell', {
    'min-height': '100vh',
    'display': 'grid',
    'place-items': 'center',
    'padding': '2rem'
  }),

  createRule('.hero-card', {
    'width': 'min(100%, 56rem)',
    'padding': 'clamp(2rem, 6vw, 4.5rem)',
    'border': '1px solid rgba(148, 163, 184, 0.28)',
    'border-radius': '2rem',
    'background': 'rgba(15, 23, 42, 0.72)',
    'box-shadow': '0 2rem 6rem rgba(0, 0, 0, 0.35)',
    'backdrop-filter': 'blur(18px)'
  }),

  createRule('.eyebrow', {
    'margin': '0 0 1rem',
    'color': '#67e8f9',
    'font-size': '0.8rem',
    'font-weight': '700',
    'letter-spacing': '0.18em',
    'text-transform': 'uppercase'
  }),

  createRule('h1', {
    'margin': '0',
    'max-width': '12ch',
    'font-size': 'clamp(2.75rem, 8vw, 6rem)',
    'line-height': '0.95',
    'letter-spacing': '-0.06em'
  }),

  createRule('.lead', {
    'margin': '1.5rem 0 0',
    'max-width': '42rem',
    'color': '#cbd5e1',
    'font-size': 'clamp(1.05rem, 2vw, 1.35rem)',
    'line-height': '1.65'
  }),

  createRule('.link-grid', {
    'display': 'grid',
    'gap': '0.85rem',
    'margin-top': '2rem'
  }),

  createRule('.link-grid a', {
    'display': 'flex',
    'align-items': 'center',
    'justify-content': 'space-between',
    'gap': '1rem',
    'padding': '1rem 1.15rem',
    'border': '1px solid rgba(148, 163, 184, 0.25)',
    'border-radius': '1rem',
    'color': '#f8fafc',
    'text-decoration': 'none',
    'background': 'rgba(255, 255, 255, 0.06)'
  }),

  createRule('.link-grid a:hover,\n.link-grid a:focus-visible', {
    'border-color': 'rgba(103, 232, 249, 0.75)',
    'outline': 'none',
    'background': 'rgba(103, 232, 249, 0.12)'
  })
];

// Generiere den CSS-Inhalt
const cssContent = generateCSS(cssRules);

// Hauptfunktion zum Schreiben der CSS-Datei
function writeCSSFile(outputPath) {
  try {
    // Stelle sicher, dass das Verzeichnis existiert
    const dir = path.dirname(outputPath);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    
    // Schreibe die CSS-Datei
    fs.writeFileSync(outputPath, cssContent, 'utf8');
    console.log(`CSS file successfully written to ${outputPath}`);
  } catch (error) {
    console.error('Error writing CSS file:', error.message);
    process.exit(1);
  }
}

// Überprüfe Kommandozeilenargumente
if (process.argv.length < 3) {
  console.error('Usage: node script.js <output-file-path>');
  process.exit(1);
}

// Hole den Ausgabepfad aus den Argumenten
const outputPath = process.argv[2];

// Führe die Hauptfunktion aus
writeCSSFile(outputPath);
