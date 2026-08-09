#!/usr/bin/env node
// index.html — portiert nach javascript
// Quelle: html, Onboarding@main:development/preview-renders/hover-mock/index.html
// Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

function generateHTML() {
  const html = {
    head: {
      title: 'Hover-Preview Varianten · Vergleich',
      meta: [
        { charset: 'UTF-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1.0' }
      ],
      links: [
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' },
        { 
          href: 'https://fonts.googleapis.com/css2?family=Newsreader:wght@400;500&family=Hanken+Grotesk:wght@400;500&family=JetBrains+Mono:wght@400;500&display=swap',
          rel: 'stylesheet'
        }
      ],
      style: `
  :root {
    --bg: #FAF8F4;
    --ink: #1B1A17;
    --accent: #A8542F;
    --accent-2: #2E7D7B;
    --font-display: 'Newsreader', Georgia, serif;
    --font-body: 'Hanken Grotesk', -apple-system, sans-serif;
    --font-mono: 'JetBrains Mono', monospace;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: var(--font-body);
    background: var(--bg);
    color: var(--ink);
    padding: 32px 16px 80px;
  }
  h1 {
    font-family: var(--font-display);
    font-weight: 500;
    font-size: 28px;
    max-width: 1400px;
    margin: 0 auto 12px;
  }
  .intro {
    max-width: 1400px;
    margin: 0 auto 32px;
    color: #666;
    font-size: 14px;
    line-height: 1.5;
  }
  .grid {
    display: grid;
    gap: 32px;
    max-width: 1400px;
    margin: 0 auto;
  }
  .variant {
    background: #000;
    border-radius: 16px;
    overflow: hidden;
    box-shadow: 0 12px 40px rgba(0,0,0,0.15);
  }
  .variant-header {
    background: #fff;
    padding: 16px 24px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 16px;
    border-bottom: 1px solid #eee;
  }
  .variant-label {
    font-family: var(--font-mono);
    font-size: 11px;
    letter-spacing: 0.2em;
    text-transform: uppercase;
    color: var(--accent);
    font-weight: 600;
  }
  .variant-title {
    font-family: var(--font-display);
    font-size: 20px;
    font-weight: 500;
  }
  .variant-desc {
    font-size: 13px;
    color: #666;
    flex: 1;
    text-align: right;
  }
  .scene {
    position: relative;
    aspect-ratio: 16 / 9;
    background: url('bg.png') center/cover no-repeat;
    overflow: hidden;
  }
  .orb {
    position: absolute;
    width: 12%;
    aspect-ratio: 1;
    left: 42%;
    top: 55%;
    transform: translate(-50%, -50%);
    cursor: pointer;
  }
  .orb img { width: 100%; height: 100%; object-fit: contain; }

  /* Variante 1: Karte daneben */
  .card-preview {
    position: absolute;
    left: 55%;
    top: 45%;
    background: rgba(255,255,255,0.98);
    padding: 16px 20px;
    border-radius: 12px;
    box-shadow: 0 8px 24px rgba(0,0,0,0.25);
    width: 240px;
    animation: slideIn 0.3s ease-out;
  }
  .card-preview .badge {
    display: inline-block;
    background: var(--accent-2);
    color: white;
    font-family: var(--font-mono);
    font-size: 9px;
    letter-spacing: 0.15em;
    text-transform: uppercase;
    padding: 3px 8px;
    border-radius: 3px;
    margin-bottom: 8px;
  }
  .card-preview h3 {
    font-family: var(--font-display);
    font-size: 18px;
    font-weight: 500;
    margin-bottom: 6px;
    color: var(--ink);
  }
  .card-preview p {
    font-size: 12px;
    color: #555;
    line-height: 1.4;
  }
  @keyframes slideIn {
    from { opacity: 0; transform: translateX(-8px); }
    to { opacity: 1; transform: translateX(0); }
  }

  /* Variante 2: Minimaler Tooltip */
  .tooltip {
    position: absolute;
    left: 42%;
    top: 46%;
    transform: translate(-50%, -100%);
    color: white;
    text-shadow: 0 2px 12px rgba(0,0,0,0.8);
    font-family: var(--font-display);
    font-size: 20px;
    font-weight: 500;
    white-space: nowrap;
    animation: fadeUp 0.3s ease-out;
  }
  @keyframes fadeUp {
    from { opacity: 0; transform: translate(-50%, -80%); }
    to { opacity: 1; transform: translate(-50%, -100%); }
  }

  /* Variante 3: Vollflächiges Overlay */
  .full-overlay {
    position: absolute;
    inset: 0;
    background: rgba(0,0,0,0.5);
    backdrop-filter: blur(6px);
    display: flex;
    align-items: center;
    justify-content: center;
    animation: fadeIn 0.35s ease-out;
  }
  .full-overlay .panel {
    background: rgba(255,255,255,0.98);
    padding: 32px 40px;
    border-radius: 20px;
    max-width: 420px;
    box-shadow: 0 20px 60px rgba(0,0,0,0.4);
    text-align: center;
  }
  .full-overlay .badge {
    display: inline-block;
    background: var(--accent);
    color: white;
    font-family: var(--font-mono);
    font-size: 10px;
    letter-spacing: 0.2em;
    text-transform: uppercase;
    padding: 4px 10px;
    border-radius: 4px;
    margin-bottom: 14px;
  }
  .full-overlay h3 {
    font-family: var(--font-display);
    font-size: 28px;
    font-weight: 500;
    margin-bottom: 10px;
    color: var(--ink);
  }
  .full-overlay p {
    font-size: 14px;
    color: #555;
    line-height: 1.5;
    margin-bottom: 20px;
  }
  .full-overlay .preview-img {
    width: 100%;
    aspect-ratio: 16/10;
    background: linear-gradient(135deg, #A8542F, #2E7D7B);
    border-radius: 8px;
    margin-bottom: 16px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: white;
    font-family: var(--font-mono);
    font-size: 11px;
    letter-spacing: 0.15em;
    opacity: 0.9;
  }
  @keyframes fadeIn {
    from { opacity: 0; }
    to { opacity: 1; }
  }

  .instruction {
    text-align: center;
    color: #999;
    font-size: 12px;
    margin-top: 16px;
    font-family: var(--font-mono);
    letter-spacing: 0.15em;
    text-transform: uppercase;
  }

  @media (max-width: 900px) {
    .card-preview { width: 180px; padding: 12px 14px; }
    .card-preview h3 { font-size: 15px; }
    .card-preview p { font-size: 11px; }
    .tooltip { font-size: 15px; }
    .full-overlay .panel { padding: 20px 24px; max-width: 300px; }
    .full-overlay h3 { font-size: 20px; }
  }
`
    },
    body: {
      children: [
        {
          tag: 'h1',
          text: 'Hover-Preview · drei Varianten im Vergleich'
        },
        {
          tag: 'p',
          class: 'intro',
          children: [
            {
              tag: 'br'
            },
            {
              tag: 'br'
            }
          ],
          text: 'Gleiche Szene, gleiche Kugel-Position (Beispiel: Projekt-Kugel "Weather-Check").Alle drei Varianten zeigen den Zustand '
        },
        {
          tag: 'em',
          text: 'bei Maushover'
        },
        {
          tag: 'div',
          text: '. Welche soll ins Projekt?'
        },
        {
          tag: 'div',
          class: 'grid',
          children: [
            // Variante 1
            {
              tag: 'div',
              class: 'variant',
              children: [
                {
                  tag: 'div',
                  class: 'variant-header',
                  children: [
                    {
                      tag: 'div',
                      children: [
                        {
                          tag: 'div',
                          class: 'variant-label',
                          text: 'Variante 1'
                        },
                        {
                          tag: 'div',
                          class: 'variant-title',
                          text: 'Karte daneben'
                        }
                      ]
                    },
                    {
                      tag: 'div',
                      class: 'variant-desc',
                      text: 'Kompakte Card rechts der Kugel · Titel + Badge + kurze Beschreibung aus content.ts · dezent, nicht störend'
                    }
                  ]
                },
                {
                  tag: 'div',
                  class: 'scene',
                  children: [
                    {
                      tag: 'div',
                      class: 'orb',
                      children: [
                        {
                          tag: 'img',
                          src: 'orb-01-teal.png',
                          alt: ''
                        }
                      ]
                    },
                    {
                      tag: 'div',
                      class: 'card-preview',
                      children: [
                        {
                          tag: 'span',
                          class: 'badge',
                          text: 'GitHub · Public'
                        },
                        {
                          tag: 'h3',
                          text: 'Weather-Check'
                        },
                        {
                          tag: 'p',
                          text: 'Progressive Web App für lokale Wetterdaten mit Live-Radar und Push-Benachrichtigungen.'
                        }
                      ]
                    }
                  ]
                }
              ]
            },
            // Variante 2
            {
              tag: 'div',
              class: 'variant',
              children: [
                {
                  tag: 'div',
                  class: 'variant-header',
                  children: [
                    {
                      tag: 'div',
                      children: [
                        {
                          tag: 'div',
                          class: 'variant-label',
                          text: 'Variante 2'
                        },
                        {
                          tag: 'div',
                          class: 'variant-title',
                          text: 'Minimaler Tooltip'
                        }
                      ]
                    },
                    {
                      tag: 'div',
                      class: 'variant-desc',
                      text: 'Nur der Titel schwebt über der Kugel · maximal reduziert · schnell erfassbar · lässt die Bildwirkung ungestört'
                    }
                  ]
                },
                {
                  tag: 'div',
                  class: 'scene',
                  children: [
                    {
                      tag: 'div',
                      class: 'orb',
                      children: [
                        {
                          tag: 'img',
                          src: 'orb-01-teal.png',
                          alt: ''
                        }
                      ]
                    },
                    {
                      tag: 'div',
                      class: 'tooltip',
                      text: 'Weather-Check'
                    }
                  ]
                }
              ]
            },
            // Variante 3
            {
              tag: 'div',
              class: 'variant',
              children: [
                {
                  tag: 'div',
                  class: 'variant-header',
                  children: [
                    {
                      tag: 'div',
                      children: [
                        {
                          tag: 'div',
                          class: 'variant-label',
                          text: 'Variante 3'
                        },
                        {
                          tag: 'div',
                          class: 'variant-title',
                          text: 'Vollflächiges Overlay'
                        }
                      ]
                    },
                    {
                      tag: 'div',
                      class: 'variant-desc',
                      text: 'Zentrales Modal mit Preview-Bild + Titel + Beschreibung · prominent · lädt zum Klicken ein · verdeckt aber Szene'
                    }
                  ]
                },
                {
                  tag: 'div',
                  class: 'scene',
                  children: [
                    {
                      tag: 'div',
                      class: 'orb',
                      children: [
                        {
                          tag: 'img',
                          src: 'orb-01-teal.png',
                          alt: ''
                        }
                      ]
                    },
                    {
                      tag: 'div',
                      class: 'full-overlay',
                      children: [
                        {
                          tag: 'div',
                          class: 'panel',
                          children: [
                            {
                              tag: 'div',
                              class: 'preview-img',
                              text: 'PROJEKT-PREVIEW'
                            },
                            {
                              tag: 'span',
                              class: 'badge',
                              text: 'GitHub · Public'
                            },
                            {
                              tag: 'h3',
                              text: 'Weather-Check'
                            },
                            {
                              tag: 'p',
                              text: 'Progressive Web App für lokale Wetterdaten mit Live-Radar und Push-Benachrichtigungen.'
                            }
                          ]
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        },
        {
          tag: 'p',
          class: 'instruction',
          text: 'Sag mir welche Variante — dann baue ich sie ins Frontend ein.'
        }
      ]
    }
  };

  return buildHTML(html);
}

function buildHTML(structure) {
  let html = '<!DOCTYPE html>\n<html lang="de">\n<head>\n';
  
  // Add meta tags
  structure.head.meta.forEach(meta => {
    html += '  <meta';
    Object.entries(meta).forEach(([key, value]) => {
      html += ` ${key}="${value}"`;
    });
    html += '>\n';
  });
  
  // Add title
  html += `  <title>${structure.head.title}</title>\n`;
  
  // Add links
  structure.head.links.forEach(link => {
    html += '  <link';
    Object.entries(link).forEach(([key, value]) => {
      html += ` ${key}="${value}"`;
    });
    html += '>\n';
  });
  
  // Add style
  html += '  <style>\n';
  html += structure.head.style.split('\n').map(line => '    ' + line).join('\n');
  html += '\n  </style>\n';
  
  html += '</head>\n<body>\n\n';
  
  // Add body content
  html += buildElement(structure.body);
  
  html += '\n\n</body>\n</html>';
  
  return html;
}

function buildElement(element) {
  if (typeof element === 'string') {
    return element;
  }
  
  if (!element.tag) {
    if (element.text) return element.text;
    if (element.children) return element.children.map(buildElement).join('');
    return '';
  }
  
  let html = `<${element.tag}`;
  
  // Add attributes
  if (element.class) {
    html += ` class="${element.class}"`;
  }
  if (element.src) {
    html += ` src="${element.src}"`;
  }
  if (element.alt !== undefined) {
    html += ` alt="${element.alt}"`;
  }
  if (element.href) {
    html += ` href="${element.href}"`;
  }
  if (element.rel) {
    html += ` rel="${element.rel}"`;
  }
  if (element.crossorigin !== undefined) {
    html += ` crossorigin="${element.crossorigin}"`;
  }
  if (element.name) {
    html += ` name="${element.name}"`;
  }
  if (element.content) {
    html += ` content="${element.content}"`;
  }
  
  html += '>';
  
  // Add text content
  if (element.text) {
    html += element.text;
  }
  
  // Add children
  if (element.children) {
    html += element.children.map(buildElement).join('');
  }
  
  html += `</${element.tag}>`;
  
  return html;
}

// Main execution
if (process.argv.length < 3) {
  console.error('Usage: node script.js <output-file>');
  process.exit(1);
}

const outputFile = process.argv[2];
const htmlContent = generateHTML();

try {
  writeFileSync(outputFile, htmlContent, 'utf8');
  console.log(`HTML file generated successfully: ${outputFile}`);
} catch (error) {
  console.error('Error writing file:', error.message);
  process.exit(1);
}
