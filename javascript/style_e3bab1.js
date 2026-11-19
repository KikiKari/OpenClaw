#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "321f8dfd79444b789cf6cac0623cb391aca4b9e296343dc229941708c8590572", "source_sha256": "e3bab1624f203b949716145357872ec8001a11d44b45121002215386ca7164b3", "target_language": "javascript"}
// style.css — portiert nach javascript
// Quelle: css, workspace@local:skills/github-clones/openclaw/docs/style.css
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');

function generateCSS() {
  // Create the CSS structure programmatically
  const rules = [];
  
  // Rule 1: #content > h1:first-of-type
  rules.push({
    selector: '#content > h1:first-of-type',
    declarations: [
      { property: 'display', value: 'none !important' }
    ]
  });
  
  // Rule 2: .nav-tabs
  rules.push({
    selector: '.nav-tabs',
    declarations: [
      { property: 'position', value: 'relative' }
    ]
  });
  
  // Rule 3: .nav-tabs-item > div
  rules.push({
    selector: '.nav-tabs-item > div',
    declarations: [
      { property: 'opacity', value: '0' }
    ]
  });
  
  // Rule 4: .nav-tabs-underline
  rules.push({
    selector: '.nav-tabs-underline',
    declarations: [
      { property: 'position', value: 'absolute' },
      { property: 'left', value: '0' },
      { property: 'bottom', value: '0' },
      { property: 'height', value: '1.5px' },
      { property: 'width', value: 'var(--nav-tab-underline-width, 0)' },
      { property: 'transform', value: 'translateX(var(--nav-tab-underline-x, 0))' },
      { property: 'background-color', value: 'rgb(var(--primary))' },
      { property: 'border-radius', value: '999px' },
      { property: 'pointer-events', value: 'none' },
      { property: 'opacity', value: '0' },
      { 
        property: 'transition',
        value: 'transform 260ms ease-in-out,\n    width 260ms ease-in-out,\n    opacity 160ms ease-in-out'
      },
      { property: 'will-change', value: 'transform, width' }
    ]
  });
  
  // Rule 5: html.dark .nav-tabs-underline
  rules.push({
    selector: 'html.dark .nav-tabs-underline',
    declarations: [
      { property: 'background-color', value: 'rgb(var(--primary-light))' }
    ]
  });
  
  // Rule 6: .nav-tabs-underline-ready .nav-tabs-underline
  rules.push({
    selector: '.nav-tabs-underline-ready .nav-tabs-underline',
    declarations: [
      { property: 'opacity', value: '1' }
    ]
  });
  
  // Generate CSS output
  let cssOutput = '';
  rules.forEach(rule => {
    cssOutput += `${rule.selector} {\n`;
    rule.declarations.forEach(decl => {
      cssOutput += `  ${decl.property}: ${decl.value};\n`;
    });
    cssOutput += '}\n\n';
  });
  
  return cssOutput.trim();
}

function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.error('Error: Please provide an output file path as argument');
    process.exit(1);
  }
  
  const outputPath = path.resolve(args[0]);
  const cssContent = generateCSS();
  
  try {
    fs.writeFileSync(outputPath, cssContent, 'utf8');
    console.log(`CSS file successfully written to: ${outputPath}`);
  } catch (error) {
    console.error(`Error writing file: ${error.message}`);
    process.exit(1);
  }
}

main();
