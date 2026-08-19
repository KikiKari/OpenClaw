#!/usr/bin/env node
// fix_gateway_node_path.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/fix_gateway_node_path.sh
// auch in: OpenClaw@gateway2:scripts/fix_gateway_node_path.sh
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import { execSync } from 'child_process';
import { readFileSync, writeFileSync, copyFileSync } from 'fs';
import { join } from 'path';

// Backup der originalen Service-Datei
const servicePath = '/etc/systemd/system/openclaw-gateway.service';
const timestamp = new Date().toISOString().replace(/[-:]/g, '').replace('T', '_').slice(0, 15);
const backupPath = `/etc/systemd/system/openclaw-gateway.service.backup-${timestamp}`;

try {
  // Kopiere die Datei für das Backup
  copyFileSync(servicePath, backupPath);
  console.log(`Backup erstellt: ${backupPath}`);
} catch (error) {
  console.error('Fehler beim Erstellen des Backups:', error.message);
  process.exit(1);
}

try {
  // Lese den Inhalt der Service-Datei
  let serviceContent = readFileSync(servicePath, 'utf8');

  // Ersetze den alten Node.js-Pfad durch den neuen
  const oldPath = '/home/openclaw/.nvm/versions/node/v22.22.2/bin/node';
  const newPath = '/usr/bin/node';
  const updatedContent = serviceContent.replace(new RegExp(oldPath, 'g'), newPath);

  // Schreibe den aktualisierten Inhalt zurück in die Datei
  writeFileSync(servicePath, updatedContent);
  console.log('Service-Datei aktualisiert.');
} catch (error) {
  console.error('Fehler beim Aktualisieren der Service-Datei:', error.message);
  process.exit(1);
}

try {
  // Service neu laden und neu starten
  execSync('systemctl daemon-reload', { stdio: 'inherit' });
  execSync('systemctl restart openclaw-gateway', { stdio: 'inherit' });
  console.log('Service neu geladen und gestartet.');
} catch (error) {
  console.error('Fehler beim Neuladen oder Neustarten des Services:', error.message);
  process.exit(1);
}

try {
  // Status prüfen
  const statusOutput = execSync('systemctl status openclaw-gateway --no-pager', { stdio: 'pipe' });
  console.log('Service-Status:');
  console.log(statusOutput.toString());
} catch (error) {
  console.error('Fehler beim Abrufen des Service-Status:', error.message);
  process.exit(1);
}
