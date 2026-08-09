#!/usr/bin/env node
// index.html — portiert nach javascript
// Quelle: html, Projects@TikTok-Live-Companion:site/index.html
// auch in: Projects@TikTok-Live-Companion-Android:site/index.html
// auch in: Projects@TikTok-Live-Companion-iOS:site/index.html
// Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

import { writeFileSync } from 'fs';
import { createRequire } from 'module';

// Create HTML document structure
function createHtmlDocument() {
  // Create doctype
  const doctype = '<!doctype html>';
  
  // Create html element
  const html = {
    tag: 'html',
    attributes: { lang: 'de' },
    children: [
      // Head section
      {
        tag: 'head',
        children: [
          {
            tag: 'meta',
            attributes: { charset: 'UTF-8' }
          },
          {
            tag: 'meta',
            attributes: { 
              name: 'viewport', 
              content: 'width=device-width, initial-scale=1.0' 
            }
          },
          {
            tag: 'meta',
            attributes: { 
              name: 'description', 
              content: 'Dokumentation für TikTok LIVE Companion 0.7.0 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser.' 
            }
          },
          {
            tag: 'meta',
            attributes: { 
              name: 'theme-color', 
              content: '#ffffff' 
            }
          },
          {
            tag: 'title',
            children: ['TikTok LIVE Companion – Dokumentation']
          }
        ]
      },
      // Body section
      {
        tag: 'body',
        children: [
          {
            tag: 'div',
            attributes: { id: 'root' }
          },
          {
            tag: 'script',
            attributes: { 
              type: 'module', 
              src: '/src/main.tsx' 
            }
          }
        ]
      }
    ]
  };

  // Render HTML structure to string
  function renderElement(element) {
    if (typeof element === 'string') {
      return element;
    }
    
    const tag = element.tag;
    const attributes = element.attributes || {};
    const children = element.children || [];
    
    let attrString = '';
    for (const [key, value] of Object.entries(attributes)) {
      attrString += ` ${key}="${value}"`;
    }
    
    if (children.length === 0) {
      return `<${tag}${attrString} />`;
    }
    
    const childrenContent = children.map(renderElement).join('');
    return `<${tag}${attrString}>${childrenContent}</${tag}>`;
  }

  return doctype + renderElement(html);
}

// Main execution
function main() {
  const args = process.argv.slice(2);
  
  if (args.length !== 1) {
    console.error('Usage: node script.js <output-file>');
    process.exit(1);
  }
  
  const outputFile = args[0];
  const htmlContent = createHtmlDocument();
  
  try {
    writeFileSync(outputFile, htmlContent);
    console.log(`HTML file created successfully: ${outputFile}`);
  } catch (error) {
    console.error('Error writing file:', error.message);
    process.exit(1);
  }
}

main();
