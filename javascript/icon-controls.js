#!/usr/bin/env node
// icon-controls.css — portiert nach javascript
// Quelle: css, Projects@TikTok-Live-Companion:plugin-source/browser-extension/icon-controls.css
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/icon-controls.css
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/icon-controls.css
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/browser-extension/icon-controls.css
// Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Define icon styles and their corresponding paths
const iconStyles = {
  plastisch: 'plastisch',
  glass: 'glass',
  linear: 'linear'
};

// Define all icons with their relative paths
const icons = [
  'auto-chat-refresh-counter',
  'browser',
  'captions',
  'chat-counter',
  'fullscreen',
  'mute',
  'off',
  'on',
  'pip',
  'play',
  'player',
  'protection-slider',
  'recommendation-counter',
  'report',
  'reset',
  'settings',
  'status',
  'stop',
  'unmute',
  'volume-slider'
];

// Generate CSS content
function generateCSS() {
  let css = '';
  
  // Generate style-specific variables
  for (const [styleName, styleValue] of Object.entries(iconStyles)) {
    css += `html[data-icon-style="${styleValue}"] {`;
    for (const icon of icons) {
      css += `--icon-${icon}:url("icons/${styleValue}/${icon}.png");`;
    }
    css += '}\n';
  }
  
  // Add generic control styles
  css += `
button[data-control-icon]::before,
.control-icon::before {
  content: "";
  display: inline-block;
  width: 32px;
  height: 32px;
  flex: 0 0 32px;
  background: var(--control-icon) center/contain no-repeat;
  vertical-align: middle;
  margin-inline-end: 0;
  pointer-events: none;
}

button[data-control-icon] {
  min-height: 44px;
  min-width: 44px;
  font-size: 0;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}

button[data-control-icon][hidden] {
  display: none;
}

input[type="checkbox"] {
  appearance: none;
  -webkit-appearance: none;
  width: 44px;
  height: 44px;
  min-width: 44px;
  border: 0;
  background: var(--icon-off) center/40px no-repeat;
  cursor: pointer;
  vertical-align: middle;
}

input[type="checkbox"]:checked {
  background-image: var(--icon-on);
}

input[type="checkbox"]:focus-visible,
button[data-control-icon]:focus-visible {
  outline: 2px solid #1769df;
  outline-offset: 2px;
}

input[type="checkbox"]:disabled {
  opacity: .45;
  cursor: default;
}

.control-icon {
  display: inline-flex;
  align-items: center;
}

input[type="range"] {
  min-height: 32px;
}

.icon-style-setting {
  display: flex;
  align-items: center;
  gap: 8px;
}
`;
  
  // Add icon-specific control variables
  for (const icon of icons) {
    css += `[data-control-icon="${icon}"] { --control-icon:var(--icon-${icon}); }\n`;
  }
  
  return css.trim();
}

// Main function to write CSS to file
function main() {
  const outputFile = process.argv[2] || 'icon-controls.css';
  const cssContent = generateCSS();
  
  writeFileSync(outputFile, cssContent);
  console.log(`CSS file generated: ${outputFile}`);
}

main();
