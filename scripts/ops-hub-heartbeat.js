"use strict";

const fs = require('fs');
const path = require('path');

// Aktualisiere den Statusbericht mit aktueller Zeit
const statusPath = path.join(__dirname, '../docs/ops-hub/status.md');

function updateHeartbeat() {
  let content;
  try {
    content = fs.readFileSync(statusPath, 'utf-8');
  } catch (err) {
    console.error('❌ Konnte status.md nicht lesen:', err.message);
    return;
  }

  const now = new Date().toLocaleString('de-DE', { timeZone: 'Europe/Berlin' });
  const updated = content.replace(/(Letzter Heartbeat:) [^\n]*/, `$1 ${now}`);

  try {
    fs.writeFileSync(statusPath, updated, 'utf-8');
    console.log(`✅ Heartbeat aktualisiert: ${now}`);
  } catch (err) {
    console.error('❌ Konnte status.md nicht schreiben:', err.message);
  }
}

updateHeartbeat();
