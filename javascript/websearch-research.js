#!/usr/bin/env node
// websearch-research.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/websearch-research.sh
// Erzeugt: 2026-10-24 durch ABSTRACTIONS_MANAGER.py

// Web Search Script: Deep Research für Incidents
// Verwendung: node websearch-research.js "Beschreibung des Problems"

const fs = require('fs');
const https = require('https');
const path = require('path');

const QUERY = process.argv[2];
const OUTPUT_DIR = process.argv[3] || './research';

if (!QUERY) {
  console.log('Verwendung: node websearch-research.js "Problem Beschreibung" [OUTPUT_DIR]');
  process.exit(1);
}

// Funktion zum Erstellen des Ausgabeverzeichnisses
fs.mkdirSync(OUTPUT_DIR, { recursive: true });

// Erstelle einen Dateinamen mit Zeitstempel
const timestamp = new Date().toISOString().replace(/[:.]/g, '-').replace('T', '_').slice(0, 19);
const OUTPUT_FILE = path.join(OUTPUT_DIR, `incident_${timestamp}.md`);

// Schreibe den Header in die Markdown-Datei
let content = '# Incident Research\n';
content += `Datum: ${new Date().toLocaleString()}\n`;
content += `Query: ${QUERY}\n\n`;

// Funktion zum Senden einer HTTPS-Anfrage
function sendRequest(options, postData) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve(data));
    });
    req.on('error', reject);
    if (postData) {
      req.write(postData);
    }
    req.end();
  });
}

// 1. EXA für schnelle Recherche
async function exaResearch() {
  content += '## 1. Schnelle Recherche (EXA)\n';
  
  const postData = JSON.stringify({
    model: 'openai/gpt-5.6-terra',
    messages: [{ role: 'user', content: QUERY }],
    plugins: [{ id: 'web', engine: 'exa', max_results: 5 }]
  });

  const options = {
    hostname: 'openrouter.ai',
    port: 443,
    path: '/api/v1/chat/completions',
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.OPENROUTER_API_KEY}`,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData)
    }
  };

  try {
    const response = await sendRequest(options, postData);
    const jsonResponse = JSON.parse(response);
    const result = jsonResponse.choices && jsonResponse.choices[0] && jsonResponse.choices[0].message 
                   ? jsonResponse.choices[0].message.content 
                   : 'Keine Ergebnisse';
    content += `${result}\n\n---\n\n`;
  } catch (error) {
    content += `Fehler bei der EXA-Recherche: ${error.message}\n\n---\n\n`;
  }
}

// 2. Verifizierte Quellen (Perplexity)
async function perplexityResearch() {
  content += '## 2. Verifizierte Fakten (Perplexity)\n';
  
  const postData = JSON.stringify({
    model: 'perplexity/sonar:online',
    messages: [{ role: 'user', content: `${QUERY} troubleshooting` }]
  });

  const options = {
    hostname: 'openrouter.ai',
    port: 443,
    path: '/api/v1/chat/completions',
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.OPENROUTER_API_KEY}`,
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(postData)
    }
  };

  try {
    const response = await sendRequest(options, postData);
    const jsonResponse = JSON.parse(response);
    const result = jsonResponse.choices && jsonResponse.choices[0] && jsonResponse.choices[0].message 
                   ? jsonResponse.choices[0].message.content 
                   : 'Keine Ergebnisse';
    content += `${result}\n\n`;
    content += `Gespeichert in: ${OUTPUT_FILE}\n`;
    
    fs.writeFileSync(OUTPUT_FILE, content);
    console.log(`Gespeichert in: ${OUTPUT_FILE}`);
  } catch (error) {
    content += `Fehler bei der Perplexity-Recherche: ${error.message}\n\n`;
    content += `Gespeichert in: ${OUTPUT_FILE}\n`;
    
    fs.writeFileSync(OUTPUT_FILE, content);
    console.log(`Gespeichert in: ${OUTPUT_FILE}`);
  }
}

// Hauptfunktion zur Ausführung beider Suchanfragen
async function main() {
  await exaResearch();
  await perplexityResearch();
}

main();
