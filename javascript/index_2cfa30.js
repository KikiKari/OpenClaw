#!/usr/bin/env node
// index.html — portiert nach javascript
// Quelle: html, Projects@TikTok-Live-Companion:site/index.html
// auch in: Projects@TikTok-Live-Companion-Android:site/index.html
// auch in: Projects@TikTok-Live-Companion-iOS:site/index.html
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import fs from 'fs';
import path from 'path';

function createHtmlDocument() {
  const doc = {
    doctype: '<!doctype html>',
    html: {
      attributes: { lang: 'de' },
      head: {
        meta: [
          { charset: 'UTF-8' },
          { name: 'viewport', content: 'width=device-width, initial-scale=1.0' },
          { name: 'description', content: 'Dokumentation für TikTok LIVE Companion 0.8.0 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser.' },
          { name: 'theme-color', content: '#ffffff' }
        ],
        link: [
          { rel: 'icon', type: 'image/png', href: '/branding/staenderglobus-ios.png' },
          { rel: 'apple-touch-icon', href: '/branding/staenderglobus-ios.png' }
        ],
        title: 'TikTok LIVE Companion – Dokumentation'
      },
      body: {
        div: { attributes: { id: 'root' } },
        script: { 
          attributes: { type: 'module', src: '/src/main.tsx' }
        }
      }
    }
  };

  return doc;
}

function renderMetaTag(meta) {
  const attrs = Object.entries(meta)
    .map(([key, value]) => `${key}="${value}"`)
    .join(' ');
  return `<meta ${attrs} />`;
}

function renderLinkTag(link) {
  const attrs = Object.entries(link)
    .map(([key, value]) => `${key}="${value}"`)
    .join(' ');
  return `<link ${attrs} />`;
}

function renderElement(tag, element) {
  if (!element) return '';
  
  const attributes = element.attributes 
    ? ' ' + Object.entries(element.attributes)
        .map(([key, value]) => `${key}="${value}"`)
        .join(' ')
    : '';
  
  return `<${tag}${attributes}></${tag}>`;
}

function generateHtml(doc) {
  const { doctype, html } = doc;
  
  const metaTags = html.head.meta.map(renderMetaTag).join('\n    ');
  const linkTags = html.head.link.map(renderLinkTag).join('\n    ');
  
  const head = `  <head>
    ${metaTags}
    ${linkTags}
    <title>${html.head.title}</title>
  </head>`;
  
  const body = `  <body>
    ${renderElement('div', html.body.div)}
    ${renderElement('script', html.body.script)}
  </body>`;
  
  const htmlTag = `<html${html.attributes ? ' ' + Object.entries(html.attributes).map(([key, value]) => `${key}="${value}"`).join(' ') : ''}>
${head}
${body}
</html>`;

  return `${doctype}
${htmlTag}`;
}

function main() {
  const outputFile = process.argv[2];
  
  if (!outputFile) {
    console.error('Bitte geben Sie eine Ausgabedatei als Parameter an.');
    process.exit(1);
  }
  
  const doc = createHtmlDocument();
  const htmlContent = generateHtml(doc);
  
  const outputPath = path.resolve(outputFile);
  fs.writeFileSync(outputPath, htmlContent);
  
  console.log(`HTML-Dokument wurde erfolgreich erstellt: ${outputPath}`);
}

main();
