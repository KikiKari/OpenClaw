#!/usr/bin/env node
// offscreen.html — portiert nach javascript
// Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/offscreen.html
// auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/offscreen.html
// auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/offscreen.html
// auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/browser-extension/offscreen.html
// Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');

function createOffscreenHTML() {
    const html = `<!doctype html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <title>TikTok LIVE Companion Sprachausgabe</title>
</head>
<body>
  <script src="offscreen.js"></script>
</body>
</html>`;

    return html;
}

function main() {
    const outputFile = process.argv[2] || 'offscreen.html';
    
    const htmlContent = createOffscreenHTML();
    
    fs.writeFileSync(outputFile, htmlContent, 'utf8');
    
    console.log(`HTML file created: ${outputFile}`);
}

main();
