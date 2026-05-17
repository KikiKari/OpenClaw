"use strict";

const fs = require('fs');
const path = require('path');

// Pfade
const DASHBOARD_PATH = path.join(__dirname, '../dashboards/nodes-overview.md');
const REPORT_LOG = path.join(__dirname, '../logs/nodes-report.log');

// Farbcodes
const C = {
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  reset: '\x1b[0m'
};

function postReport() {
  let content;
  try {
    content = fs.readFileSync(DASHBOARD_PATH, 'utf-8');
  } catch (err) {
    console.error(`${C.red}❌ Fehler beim Lesen der Dashboard-Datei:${C.reset}`, err.message);
    return;
  }

  // Nachricht über OpenClaw message senden
  const messageCmd = `openclaw message send --target=main --message "$(echo ${JSON.stringify(content)} | sed 's/\\n/\\\\n/g')"`;

  try {
    require('child_process').execSync(messageCmd, { stdio: 'pipe' });
    console.log(`${C.green}✅ Report erfolgreich im 'main'-Channel gepostet.${C.reset}`);
    fs.appendFileSync(REPORT_LOG, `[${new Date().toISOString()}] Report posted.\n`);
  } catch (err) {
    console.error(`${C.red}❌ Fehler beim Senden der Nachricht:${C.reset}`, err.stderr?.toString() || err.message);
    fs.appendFileSync(REPORT_LOG, `[${new Date().toISOString()}] Failed to post: ${err.message}\n`);
  }
}

// Hauptausführung
console.log(`${C.yellow}📤 Sende Nodes-Übersicht in 'main'...${C.reset}`);
postReport();
