#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "a6f27011bbe00bddd96b8740a3a18e48382d4739176b6d80d565a257aa5db28e", "source_sha256": "04518825207cd6ef771c2d840daf0a025f3144f4e384f1d13b46e016570f59df", "target_language": "javascript"}
// fix_gateway_node_path.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/fix_gateway_node_path.sh
// auch in: OpenClaw@gateway2:scripts/fix_gateway_node_path.sh
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const { execSync } = require('child_process');
const path = require('path');

// Pfade definieren
const servicePath = '/etc/systemd/system/openclaw-gateway.service';
const backupSuffix = new Date().toISOString().replace(/[:]/g, '-').replace('T', '_').split('.')[0];
const backupPath = `/etc/systemd/system/openclaw-gateway.service.backup-${backupSuffix}`;

try {
  // Backup der originalen Service-Datei
  const serviceContent = fs.readFileSync(servicePath, 'utf8');
  fs.writeFileSync(backupPath, serviceContent);
  console.log(`Backup erstellt: ${backupPath}`);

  // Korrektur des Node.js Pfads in der Service-Datei
  // Annahme: Node.js ist unter /usr/bin/node verfügbar (wie von 'which node' gezeigt)
  const updatedContent = serviceContent.replace(
    /\/home\/openclaw\/\.nvm\/versions\/node\/v22\.22\.2\/bin\/node/g,
    '/usr/bin/node'
  );
  
  fs.writeFileSync(servicePath, updatedContent);
  console.log('Service-Datei aktualisiert');

  // Service neu laden und neu starten
  execSync('systemctl daemon-reload', { stdio: 'inherit' });
  execSync('systemctl restart openclaw-gateway', { stdio: 'inherit' });

  // Status prüfen
  const status = execSync('systemctl status openclaw-gateway --no-pager', { stdio: 'inherit' });
} catch (error) {
  console.error('Fehler beim Ausführen des Skripts:', error.message);
  process.exit(1);
}
