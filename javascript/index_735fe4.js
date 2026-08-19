#!/usr/bin/env node
// index.html — portiert nach javascript
// Quelle: html, OpenClaw@main:index.html
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

// Helper function to get __dirname in ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Create HTML document structure
function createHTMLDocument() {
  // Create document type
  const docType = '<!DOCTYPE html>';
  
  // Create root element
  const html = {
    tag: 'html',
    attributes: { lang: 'de' },
    children: []
  };
  
  // Create head section
  const head = {
    tag: 'head',
    children: [
      {
        tag: 'meta',
        attributes: { charset: 'utf-8' }
      },
      {
        tag: 'link',
        attributes: { rel: 'icon', href: '/favicon.ico' }
      },
      {
        tag: 'meta',
        attributes: { 
          name: 'viewport', 
          content: 'width=device-width, initial-scale=1' 
        }
      },
      {
        tag: 'meta',
        attributes: { 
          name: 'theme-color', 
          content: '#0b1020' 
        }
      },
      {
        tag: 'meta',
        attributes: { 
          name: 'description', 
          content: 'OpenClaw Startseite für Repository, Dokumentation und Frontend-Branch.' 
        }
      },
      {
        tag: 'link',
        attributes: { 
          rel: 'apple-touch-icon', 
          href: '/logo192.png' 
        }
      },
      {
        tag: 'link',
        attributes: { 
          rel: 'manifest', 
          href: '/manifest.json' 
        },
        commentBefore: '\n      manifest.json provides metadata used when your web app is installed on a\n      user\'s mobile device or desktop. See https://developers.google.com/web/fundamentals/web-app-manifest/\n    '
      },
      {
        tag: 'title',
        children: ['OpenClaw']
      }
    ]
  };
  
  // Create body section
  const body = {
    tag: 'body',
    children: [
      {
        tag: 'noscript',
        children: ['You need to enable JavaScript to run this app.']
      },
      {
        tag: 'div',
        attributes: { id: 'root' }
      },
      {
        tag: 'script',
        attributes: { 
          type: 'module', 
          src: '/src/index.jsx' 
        },
        commentBefore: '\n      This HTML file is a template.\n      If you open it directly in the browser, you will see an empty page.\n\n      You can add webfonts, meta tags, or analytics to this file.\n      The build step will place the bundled scripts into the <body> tag.\n\n      To begin the development, run `npm start` or `yarn start`.\n      To create a production bundle, use `npm run build` or `yarn build`.\n    '
      }
    ]
  };
  
  html.children.push(head, body);
  
  return { docType, html };
}

// Convert element tree to HTML string
function elementToString(element, indent = 0) {
  const spaces = '  '.repeat(indent);
  let result = '';
  
  if (element.commentBefore) {
    const commentLines = element.commentBefore.split('\n');
    commentLines.forEach(line => {
      if (line.trim()) {
        result += `${spaces}<!--${line}-->\n`;
      } else {
        result += '\n';
      }
    });
  }
  
  if (element.tag) {
    result += `${spaces}<${element.tag}`;
    
    if (element.attributes) {
      for (const [key, value] of Object.entries(element.attributes)) {
        result += ` ${key}="${value}"`;
      }
    }
    
    if (element.children && element.children.length > 0) {
      result += '>\n';
      
      for (const child of element.children) {
        if (typeof child === 'string') {
          result += `${spaces}  ${child}\n`;
        } else {
          result += elementToString(child, indent + 1);
        }
      }
      
      result += `${spaces}</${element.tag}>\n`;
    } else {
      result += ' />\n';
    }
  }
  
  return result;
}

// Generate complete HTML string
function generateHTML() {
  const { docType, html } = createHTMLDocument();
  const htmlString = elementToString(html);
  return `${docType}\n${htmlString}`;
}

// Main function
function main() {
  const args = process.argv.slice(2);
  
  if (args.length !== 1) {
    console.error('Usage: node script.js <output-file>');
    process.exit(1);
  }
  
  const outputFile = args[0];
  
  try {
    const htmlContent = generateHTML();
    fs.writeFileSync(outputFile, htmlContent);
    console.log(`HTML file generated successfully: ${outputFile}`);
  } catch (error) {
    console.error('Error generating HTML file:', error.message);
    process.exit(1);
  }
}

main();
