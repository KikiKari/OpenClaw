#!/usr/bin/env node
// gateway-styles.css — portiert nach javascript
// Quelle: css, OpenClaw@main:examples/gateway-styles.css
// Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');

function generateCSS() {
  const styles = {
    '*': {
      boxSizing: 'border-box',
      margin: '0',
      padding: '0'
    },
    ':root': {
      '--bg': '#0d1117',
      '--surface': '#161b22',
      '--border': '#30363d',
      '--text': '#e6edf3',
      '--muted': '#8b949e',
      '--green': '#3fb950',
      '--yellow': '#d29922',
      '--red': '#f85149',
      '--accent': '#58a6ff'
    },
    'body': {
      background: 'var(--bg)',
      color: 'var(--text)',
      fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      minHeight: '100vh'
    },
    'header': {
      display: 'flex',
      alignItems: 'center',
      gap: '1rem',
      padding: '1.25rem 2rem',
      borderBottom: '1px solid var(--border)',
      background: 'var(--surface)'
    },
    'header h1': {
      fontSize: '1.25rem',
      color: 'var(--accent)'
    },
    '.badge': {
      padding: '.25rem .75rem',
      borderRadius: '999px',
      fontSize: '.75rem',
      fontWeight: '600',
      background: 'var(--border)',
      color: 'var(--muted)'
    },
    '.badge.ok': {
      background: '#1a3a2a',
      color: 'var(--green)'
    },
    '.badge.warn': {
      background: '#3a2e0a',
      color: 'var(--yellow)'
    },
    '.badge.error': {
      background: '#3a1010',
      color: 'var(--red)'
    },
    'main': {
      padding: '2rem',
      maxWidth: '960px',
      margin: '0 auto'
    },
    '.grid': {
      display: 'grid',
      gridTemplateColumns: 'repeat(auto-fit, minmax(260px, 1fr))',
      gap: '1rem',
      marginBottom: '2rem'
    },
    '.card': {
      background: 'var(--surface)',
      border: '1px solid var(--border)',
      borderRadius: '8px',
      padding: '1.25rem',
      position: 'relative'
    },
    '.card h2': {
      fontSize: '1rem',
      marginBottom: '.25rem'
    },
    '.card .endpoint': {
      fontSize: '.8rem',
      color: 'var(--muted)'
    },
    '.status-dot': {
      position: 'absolute',
      top: '1.25rem',
      right: '1.25rem',
      width: '10px',
      height: '10px',
      borderRadius: '50%',
      background: 'var(--border)'
    },
    '.status-dot.green': {
      background: 'var(--green)',
      boxShadow: '0 0 6px var(--green)'
    },
    '.status-dot.red': {
      background: 'var(--red)',
      boxShadow: '0 0 6px var(--red)'
    },
    '.metrics h2': {
      fontSize: '1rem',
      marginBottom: '1rem'
    },
    'table': {
      width: '100%',
      borderCollapse: 'collapse',
      fontSize: '.875rem'
    },
    'th, td': {
      padding: '.625rem 1rem',
      textAlign: 'left',
      borderBottom: '1px solid var(--border)'
    },
    'th': {
      color: 'var(--muted)',
      fontWeight: '500'
    },
    'tr:last-child td': {
      borderBottom: 'none'
    }
  };

  let cssContent = '/* OpenClaw Gateway Dashboard */\n\n';
  
  for (const [selector, properties] of Object.entries(styles)) {
    cssContent += `${selector} {`;
    
    for (const [property, value] of Object.entries(properties)) {
      // Convert camelCase to kebab-case for CSS properties
      const cssProperty = property.replace(/([A-Z])/g, '-$1').toLowerCase();
      cssContent += ` ${cssProperty}: ${value};`;
    }
    
    cssContent += ' }\n';
  }
  
  return cssContent;
}

function writeCSSFile(filename) {
  const css = generateCSS();
  fs.writeFileSync(filename, css, 'utf8');
  console.log(`CSS file generated: ${filename}`);
}

// Check if filename argument is provided
if (process.argv.length < 3) {
  console.error('Usage: node script.js <output-file>');
  process.exit(1);
}

const outputFile = process.argv[2];
writeCSSFile(outputFile);
