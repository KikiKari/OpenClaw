#!/usr/bin/env node
// index.html — portiert nach javascript
// Quelle: html, Projects@TikTok-Live-Companion:site/index.html
// Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

import fs from 'fs';
import path from 'path';

function createHtmlDocument() {
  // Create document
  const docType = '<!DOCTYPE html>';
  const html = {
    tagName: 'html',
    attributes: { lang: 'de' },
    children: []
  };

  // Create head
  const head = {
    tagName: 'head',
    children: [
      {
        tagName: 'meta',
        attributes: { charset: 'UTF-8' }
      },
      {
        tagName: 'meta',
        attributes: { 
          name: 'viewport', 
          content: 'width=device-width, initial-scale=1.0' 
        }
      },
      {
        tagName: 'meta',
        attributes: { 
          name: 'description', 
          content: 'Dokumentation für TikTok LIVE Companion 0.8.2 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser.' 
        }
      },
      {
        tagName: 'meta',
        attributes: { 
          name: 'theme-color', 
          content: '#ffffff' 
        }
      },
      {
        tagName: 'link',
        attributes: { 
          rel: 'icon', 
          type: 'image/png', 
          href: '/branding/staenderglobus-ios.png' 
        }
      },
      {
        tagName: 'link',
        attributes: { 
          rel: 'apple-touch-icon', 
          href: '/branding/staenderglobus-ios.png' 
        }
      },
      {
        tagName: 'title',
        children: ['TikTok LIVE Companion – Dokumentation']
      }
    ]
  };

  // Create body
  const body = {
    tagName: 'body',
    children: [
      {
        tagName: 'div',
        attributes: { id: 'root' },
        children: []
      },
      {
        tagName: 'script',
        attributes: { 
          type: 'module', 
          src: '/src/main.tsx' 
        },
        children: []
      }
    ]
  };

  html.children.push(head);
  html.children.push(body);

  return { docType, html };
}

function renderElement(element) {
  if (typeof element === 'string') {
    return element;
  }

  const tag = element.tagName;
  const attrs = element.attributes || {};
  
  let attrString = '';
  for (const [key, value] of Object.entries(attrs)) {
    attrString += ` ${key}="${value}"`;
  }

  if (element.children && element.children.length > 0) {
    const childrenContent = element.children.map(child => renderElement(child)).join('');
    return `<${tag}${attrString}>${childrenContent}</${tag}>`;
  } else {
    return `<${tag}${attrString}></${tag}>`;
  }
}

function generateHtmlString(doc) {
  const htmlContent = renderElement(doc.html);
  return `${doc.docType}\n${htmlContent}`;
}

// Main execution
function main() {
  const outputFile = process.argv[2];
  
  if (!outputFile) {
    console.error('Usage: node script.js <output-file>');
    process.exit(1);
  }

  const doc = createHtmlDocument();
  const htmlString = generateHtmlString(doc);
  
  const outputPath = path.resolve(outputFile);
  fs.writeFileSync(outputPath, htmlString, 'utf8');
  
  console.log(`HTML file generated successfully at: ${outputPath}`);
}

main();
