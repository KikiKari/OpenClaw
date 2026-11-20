#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "ca89c871b81567dcc76171853b8041633b4b2f29159a1f8255d92dde69a01d8e", "source_sha256": "17d9118c74c9951b6bd9c5e3475b496be57f796a591823384aa44dbdad5a115d", "target_language": "javascript"}
// styles.css — portiert nach javascript
// Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles.css
// Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

import { writeFileSync } from 'fs';
import { join } from 'path';

function generateCSS() {
  const imports = [
    './styles/base.css',
    './styles/layout.css',
    './styles/layout.mobile.css',
    './styles/components.css',
    './styles/chat.css',
    './styles/config.css',
    './styles/usage.css',
    './styles/dreams.css',
    '@create-markdown/preview/themes/system.css'
  ];

  let cssContent = '';

  // Add all import statements
  for (const importPath of imports) {
    cssContent += `@import "${importPath}";\n`;
  }

  // Add empty line for readability
  cssContent += '\n';

  // Add the cm-preview rule
  cssContent += `.cm-preview {\n`;
  cssContent += `  --cm-mono: var(--mono);\n`;
  cssContent += `  --cm-link: var(--accent);\n`;
  cssContent += `  --cm-info: var(--info);\n`;
  cssContent += `  --cm-warning: var(--warn);\n`;
  cssContent += `  --cm-success: var(--ok);\n`;
  cssContent += `  --cm-danger: var(--danger);\n`;
  cssContent += `}\n`;

  return cssContent;
}

// Get output file path from command line argument
const outputFile = process.argv[2];

if (!outputFile) {
  console.error('Please provide an output file path as an argument');
  process.exit(1);
}

try {
  const cssContent = generateCSS();
  writeFileSync(outputFile, cssContent);
  console.log(`CSS file generated successfully: ${outputFile}`);
} catch (error) {
  console.error('Error writing CSS file:', error.message);
  process.exit(1);
}
