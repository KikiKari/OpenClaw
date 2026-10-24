#!/usr/bin/env node
// websearch-research.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway2:scripts/websearch-research.sh
// Erzeugt: 2026-10-24 durch ABSTRACTIONS_MANAGER.py

// Web Search Script: Deep Research für Incidents
// Verwendung: node websearch-research.js "Beschreibung des Problems"

const fs = require('fs');
const path = require('path');
const https = require('https');
const { execSync } = require('child_process');

const QUERY = process.argv[2];
const OUTPUT_DIR = process.argv[3] || './research';

if (!QUERY) {
  console.log('Verwendung: node websearch-research.js "Problem Beschreibung" [OUTPUT_DIR]');
  process.exit(1);
}

// Funktion zum sicheren Erstellen von Verzeichnissen
function ensureDir(dir) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

// Funktion zum Formatieren des Datums
function formatDate() {
  const now = new Date();
  return `${now.getFullYear()}${String(now.getMonth() + 1).padStart(2, '0')}${String(now.getDate()).padStart(2, '0')}_${String(now.getHours()).padStart(2, '0')}${String(now.getMinutes()).padStart(2, '0')}${String(now.getSeconds()).padStart(2, '0')}`;
}

// Funktion zum HTTP POST Request
function postRequest(url, headers, data) {
  return new Promise((resolve, reject) => {
    const options = {
      method: 'POST',
      headers: headers
    };

    const req = https.request(url, options, (res) => {
      let body = '';
      res.on('data', (chunk) => {
        body += chunk;
      });
      res.on('end', () => {
        try {
          const json = JSON.parse(body);
          resolve(json);
        } catch (err) {
          reject(err);
        }
      });
    });

    req.on('error', (err) => {
      reject(err);
    });

    req.write(JSON.stringify(data));
    req.end();
  });
}

// Hauptfunktion
async function main() {
  ensureDir(OUTPUT_DIR);
  const timestamp = formatDate();
  const OUTPUT_FILE = path.join(OUTPUT_DIR, `incident_${timestamp}.md`);

  let content = '# Incident Research\n';
  content += `Datum: ${new Date().toString()}\n`;
  content += `Query: ${QUERY}\n\n`;

  // 1. EXA für schnelle Recherche
  content += '## 1. Schnelle Recherche (EXA)\n';
  
  const exaData = {
    model: 'openai/gpt-5.4-mini',
    messages: [{ role: 'user', content: QUERY }],
    plugins: [{ id: 'web', engine: 'exa', max_results: 5 }]
  };

  try {
    const exaResponse = await postRequest(
      'https://openrouter.ai/api/v1/chat/completions',
      {
        'Authorization': `Bearer ${process.env.OPENROUTER_API_KEY}`,
        'Content-Type': 'application/json'
      },
      exaData
    );
    
    const exaContent = exaResponse.choices?.[0]?.message?.content || 'Keine Ergebnisse';
    content += exaContent + '\n\n';
  } catch (err) {
    content += 'Keine Ergebnisse\n\n';
  }

  content += '---\n\n';

  // 2. Verifizierte Quellen (Perplexity) falls verfügbar
  content += '## 2. Verifizierte Fakten (Perplexity)\n';
  
  const perplexityData = {
    model: 'perplexity/sonar:online',
    messages: [{ role: 'user', content: `${QUERY} troubleshooting` }]
  };

  try {
    const perplexityResponse = await postRequest(
      'https://openrouter.ai/api/v1/chat/completions',
      {
        'Authorization': `Bearer ${process.env.OPENROUTER_API_KEY}`,
        'Content-Type': 'application/json'
      },
      perplexityData
    );
    
    const perplexityContent = perplexityResponse.choices?.[0]?.message?.content || 'Keine Ergebnisse';
    content += perplexityContent + '\n\n';
  } catch (err) {
    content += 'Keine Ergebnisse\n\n';
  }

  fs.writeFileSync(OUTPUT_FILE, content);
  console.log(`Gespeichert in: ${OUTPUT_FILE}`);
}

main().catch(console.error);
