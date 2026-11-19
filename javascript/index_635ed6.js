#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "fdf658d9d57467097c28ed10ee519d29ca793d77fa59887df6d4c63383648936", "source_sha256": "635ed6e934aa27ffc7ad156af00126e0797ae1d1c065daddb996e2bddc8cbeb3", "target_language": "javascript"}
// index.html — portiert nach javascript
// Quelle: html, workspace@local:skills/github-clones/openclaw/extensions/qa-lab/web/index.html
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

// Funktion zum Erstellen des HTML-Dokuments
function createHtmlDocument() {
  // Erstelle das grundlegende HTML-Gerüst
  const docType = '<!doctype html>';
  
  // HTML-Element mit Attributen
  const htmlAttrs = {
    lang: 'en'
  };
  
  // Head-Element mit allen Metadaten
  const headContent = [
    { tag: 'meta', attrs: { charset: 'utf-8' } },
    { tag: 'meta', attrs: { name: 'viewport', content: 'width=device-width, initial-scale=1' } },
    { tag: 'meta', attrs: { name: 'color-scheme', content: 'light dark' } },
    { tag: 'title', content: 'QA Lab' }
  ];
  
  // Body-Element mit Inhalt
  const bodyContent = [
    { tag: 'div', attrs: { id: 'app' } },
    { tag: 'script', attrs: { type: 'module', src: '/src/main.ts' } }
  ];
  
  // Hilfsfunktion zum Erstellen von HTML-Tags
  function createTag(tag, attrs = {}, content = '') {
    const attrString = Object.entries(attrs)
      .map(([key, value]) => `${key}="${value}"`)
      .join(' ');
    
    if (content) {
      return `<${tag}${attrString ? ' ' + attrString : ''}>${content}</${tag}>`;
    } else {
      return `<${tag}${attrString ? ' ' + attrString : ''}>`;
    }
  }
  
  // Erstelle die Head-Inhalte
  let headHtml = '';
  for (const item of headContent) {
    headHtml += `    ${createTag(item.tag, item.attrs, item.content || '')}\n`;
  }
  
  // Erstelle die Body-Inhalte
  let bodyHtml = '';
  for (const item of bodyContent) {
    bodyHtml += `    ${createTag(item.tag, item.attrs, item.content || '')}\n`;
  }
  
  // Baue das komplette HTML-Dokument zusammen
  const html = `${docType}
<html ${Object.entries(htmlAttrs).map(([k, v]) => `${k}="${v}"`).join(' ')}>
  <head>
${headHtml}  </head>
  <body>
${bodyHtml}  </body>
</html>`;
  
  return html;
}

// Hauptfunktion
function main() {
  // Prüfe Kommandozeilenargumente
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log(createHtmlDocument());
  } else {
    const outputFile = args[0];
    const htmlContent = createHtmlDocument();
    writeFileSync(outputFile, htmlContent);
    console.log(`HTML document written to ${outputFile}`);
  }
}

main();
