#!/usr/bin/env node
// websearch-crawl.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/websearch-crawl.sh
// auch in: OpenClaw@gateway2:scripts/websearch-crawl.sh
// Erzeugt: 2026-10-24 durch ABSTRACTIONS_MANAGER.py

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { execSync } from 'child_process';

// Web Search Script: Website Crawling mit Firecrawl
// Verwendung: node websearch-crawl.js <URL> [OUTPUT_DIR]

const args = process.argv.slice(2);
const WEBSITE_URL = args[0];
const OUTPUT_DIR = args[1] || './crawled';

// API-Key aus Umgebungsvariable oder aus Datei lesen
let FIRECRAWL_API_KEY = process.env.FIRECRAWL_API_KEY;
if (!FIRECRAWL_API_KEY) {
  try {
    const envPath = path.join(process.env.HOME, '.openclaw', 'openclaw.env');
    const envContent = fs.readFileSync(envPath, 'utf-8');
    const match = envContent.match(/OPENROUTER\s*=\s*"([^"]+)"/);
    if (match) {
      FIRECRAWL_API_KEY = match[1];
    }
  } catch (err) {
    // Datei nicht gefunden oder anderer Fehler
  }
}

if (!WEBSITE_URL) {
  console.error(`Verwendung: ${process.argv[1]} <URL> [OUTPUT_DIR]`);
  process.exit(1);
}

// Ausgabeverzeichnis erstellen
fs.mkdirSync(OUTPUT_DIR, { recursive: true });
console.log(`Crawling ${WEBSITE_URL}...`);

// Crawl starten
const crawlData = {
  url: WEBSITE_URL,
  limit: 100,
  scrapeOptions: { formats: ['markdown'] }
};

const crawlResponse = await fetch('https://api.firecrawl.dev/v1/crawl', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${FIRECRAWL_API_KEY}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify(crawlData)
});

const crawlResult = await crawlResponse.json();
const CRAWL_ID = crawlResult.id;

if (!CRAWL_ID) {
  console.error('Fehler: Crawl konnte nicht gestartet werden');
  console.error(JSON.stringify(crawlResult, null, 2));
  process.exit(1);
}

console.log(`Crawl ID: ${CRAWL_ID}`);

// Status prüfen
while (true) {
  const statusResponse = await fetch(`https://api.firecrawl.dev/v1/crawl/${CRAWL_ID}`, {
    headers: {
      'Authorization': `Bearer ${FIRECRAWL_API_KEY}`
    }
  });

  const statusResult = await statusResponse.json();
  const STATUS = statusResult.status || 'unknown';
  console.log(`Status: ${STATUS}`);

  if (STATUS === 'completed') {
    const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const outputFile = path.join(OUTPUT_DIR, `${dateStr}_crawl.json`);
    fs.writeFileSync(outputFile, JSON.stringify(statusResult, null, 2));
    console.log(`Gespeichert in ${OUTPUT_DIR}`);
    break;
  } else if (STATUS === 'failed') {
    console.error('Crawl fehlgeschlagen');
    process.exit(1);
  }

  // Warte 5 Sekunden vor dem nächsten Check
  await new Promise(resolve => setTimeout(resolve, 5000));
}
