#!/usr/bin/env node
// status-overview.html — portiert nach javascript
// Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/status-overview.html
// Erzeugt: 2026-11-01 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');

function createStatusOverview() {
  // Create the document structure
  const docType = '<!doctype html>';
  
  // Build HTML elements
  const html = {
    open: '<html lang="de">',
    close: '</html>'
  };
  
  const head = {
    open: '<head>',
    close: '</head>'
  };
  
  const body = {
    open: '<body>',
    close: '</body>'
  };
  
  const main = `<main id="grid" aria-label="LIVE-Übersicht"></main>`;
  
  // Build head content
  const metaCharset = '<meta charset="utf-8">';
  const metaViewport = '<meta name="viewport" content="width=device-width,initial-scale=1">';
  const title = '<title>STATUS-Overview</title>';
  const stylesheet = '<link rel="stylesheet" href="status-overview.css">';
  
  // Build script tags
  const scriptMpegts = '<script src="vendor-mpegts.js"></script>';
  const scriptPlayer = '<script src="status-overview-player.js"></script>';
  
  // Assemble the complete HTML document
  const documentContent = [
    docType,
    html.open,
    head.open,
    metaCharset,
    metaViewport,
    title,
    stylesheet,
    head.close,
    body.open,
    main,
    scriptMpegts,
    scriptPlayer,
    body.close,
    html.close
  ].join('');
  
  return documentContent;
}

// Handle file output
function writeToFile(content, filename) {
  const outputPath = path.resolve(filename);
  fs.writeFileSync(outputPath, content, 'utf8');
  console.log(`Status overview written to: ${outputPath}`);
}

// Main execution
function main() {
  const htmlContent = createStatusOverview();
  
  // Check if output file parameter is provided
  const outputFile = process.argv[2];
  
  if (outputFile) {
    writeToFile(htmlContent, outputFile);
  } else {
    // Output to stdout if no file specified
    console.log(htmlContent);
  }
}

// Run the application
if (require.main === module) {
  main();
}

module.exports = { createStatusOverview };
