#!/usr/bin/env node
// websearch-monitor.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/websearch-monitor.sh
// auch in: OpenClaw@gateway2:scripts/websearch-monitor.sh
// Erzeugt: 2026-10-24 durch ABSTRACTIONS_MANAGER.py

// Web Search Script: Server-Monitoring mit Tavily
// Verwendung: ./websearch-monitor.js [TOPIC]

const { execSync, spawn } = require('child_process');
const https = require('https');

// Hilfsfunktion für HTTP-Anfragen
function httpRequest(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve(data));
    }).on('error', reject);
  });
}

// Hauptlogik
async function main() {
  const topic = process.argv[2] || "Linux kernel security updates";
  
  // Security-News prüfen
  console.log(`Prüfe: ${topic}`);
  
  try {
    // Prüfe ob tvly Kommando existiert
    execSync('which tvly', { stdio: 'ignore' });
    
    // Verwende Tavily CLI
    const child = spawn('tvly', [
      'search',
      topic,
      '--topic', 'news',
      '--time-range', 'week',
      '--max-results', '5',
      '--include-answer', 'advanced'
    ]);
    
    let output = '';
    child.stdout.on('data', data => output += data);
    child.stderr.on('data', data => output += data);
    
    child.on('close', code => {
      if (code === 0) {
        try {
          const result = JSON.parse(output);
          console.log(result.answer || "Keine Zusammenfassung verfügbar");
        } catch (e) {
          console.log("Keine Zusammenfassung verfügbar");
        }
      }
    });
    
  } catch (error) {
    // Fallback zu einfacher Web-Suche
    try {
      const encodedTopic = encodeURIComponent(topic);
      const response = await httpRequest(`http://localhost:8888/search?q=${encodedTopic}&format=json`);
      const data = JSON.parse(response);
      
      if (data.results && data.results.length > 0) {
        const results = data.results.slice(0, 3);
        results.forEach(item => {
          console.log(`${item.title}\n${item.url}`);
        });
      } else {
        console.log("SearXNG nicht verfügbar");
      }
    } catch (err) {
      console.log("SearXNG nicht verfügbar");
    }
  }
}

main();
