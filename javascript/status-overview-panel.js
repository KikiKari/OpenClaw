#!/usr/bin/env node
// status-overview-panel.css — portiert nach javascript
// Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/status-overview-panel.css
// Erzeugt: 2026-11-01 durch ABSTRACTIONS_MANAGER.py

import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// CSS-Regeln definieren
const cssRules = [
  {
    selector: '.overview-row',
    properties: {
      'display': 'grid',
      'grid-template-columns': '24px minmax(0,1fr) 11px 22px auto',
      'gap': '7px',
      'align-items': 'center',
      'margin': '6px 0'
    }
  },
  {
    selector: '.overview-row input',
    properties: {
      'min-width': '0',
      'width': '100%'
    }
  },
  {
    selector: '.overview-state',
    properties: {
      'width': '11px',
      'height': '11px',
      'border-radius': '50%',
      'background': '#888'
    }
  },
  {
    selector: '.overview-state.online',
    properties: {
      'background': 'var(--good)',
      'box-shadow': '0 0 0 3px color-mix(in srgb, var(--good) 15%, transparent)'
    }
  },
  {
    selector: '.overview-state.offline',
    properties: {
      'background': 'var(--bad)',
      'box-shadow': '0 0 0 3px color-mix(in srgb, var(--bad) 15%, transparent)'
    }
  },
  {
    selector: '.overview-state.checking, .overview-state.error',
    properties: {
      'background': 'var(--warn)'
    }
  },
  {
    selector: '.overview-count',
    properties: {
      'font-size': '11px',
      'text-align': 'center',
      'font-variant-numeric': 'tabular-nums'
    }
  },
  {
    selector: '.overview-actions',
    properties: {
      'display': 'grid',
      'grid-template-columns': '44px repeat(2,minmax(0,1fr))',
      'gap': '6px',
      'align-items': 'stretch'
    }
  },
  {
    selector: '.overview-actions button',
    properties: {
      'min-width': '0',
      'padding': '8px 2px',
      'font-size': '11px',
      'white-space': 'nowrap'
    }
  },
  {
    selector: '#overview-rows',
    properties: {
      'display': 'flex',
      'flex-direction': 'column'
    }
  },
  {
    selector: '.monitor-settings > label:not(.option-row)',
    properties: {
      'display': 'block',
      'margin': '12px 0'
    }
  },
  {
    selector: '.monitor-settings .option-row input',
    properties: {
      'appearance': 'auto',
      'width': '13px',
      'height': '13px',
      'min-width': '13px',
      'background': 'none'
    }
  },
  {
    selector: '.overview-link',
    properties: {
      'padding': '8px 0',
      'border-bottom': '1px solid #bbb',
      'overflow-wrap': 'anywhere'
    }
  },
  {
    selector: '.overview-link p',
    properties: {
      'margin': '4px 0'
    }
  },
  {
    selector: '.overview-row .overview-retry',
    properties: {
      'width': '24px',
      'min-width': '24px',
      'height': '26px',
      'min-height': '26px',
      'padding': '0',
      'background-image': 'var(--icon-reset)',
      'background-size': '20px',
      'background-position': 'center',
      'background-repeat': 'no-repeat'
    }
  },
  {
    selector: '.top-setting input',
    properties: {
      'appearance': 'auto',
      '-webkit-appearance': 'checkbox',
      'width': '13px',
      'height': '13px',
      'min-width': '13px',
      'background': 'none'
    }
  },
  {
    selector: '.overview-visually-hidden',
    properties: {
      'position': 'absolute',
      'width': '1px',
      'height': '1px',
      'padding': '0',
      'margin': '-1px',
      'overflow': 'hidden',
      'clip': 'rect(0,0,0,0)',
      'white-space': 'nowrap',
      'border': '0'
    }
  },
  {
    selector: '.overview-row[hidden]',
    properties: {
      'display': 'none'
    }
  }
];

// Funktion zum Konvertieren der CSS-Regeln in einen CSS-String
function generateCSS(rules) {
  return rules.map(rule => {
    const propertyString = Object.entries(rule.properties)
      .map(([prop, value]) => `  ${prop}: ${value};`)
      .join('\n');
    return `${rule.selector} {\n${propertyString}\n}`;
  }).join('\n\n');
}

// Hauptfunktion
function main() {
  // Standardmäßig in eine Datei schreiben, wenn kein Argument übergeben wurde
  const outputFile = process.argv[2] || join(__dirname, 'status-overview-panel.css');
  
  try {
    const cssContent = generateCSS(cssRules);
    writeFileSync(outputFile, cssContent);
    console.log(`CSS file successfully written to ${outputFile}`);
  } catch (error) {
    console.error('Error writing CSS file:', error.message);
    process.exit(1);
  }
}

main();
