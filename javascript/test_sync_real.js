#!/usr/bin/env node
// test_sync_real.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:scripts/test_sync_real.py
// auch in: OpenClaw@gateway2:scripts/test_sync_real.py
// Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

/** Test echte Synchronisation */

import { execSync } from 'child_process';
import { existsSync, readdirSync } from 'fs';
import { join, basename, sep } from 'path';

// Füge das Verzeichnis zum Modulsuchpfad hinzu
const modulePath = '/home/openclaw/.openclaw/workspace/scripts';

// Importiere die benötigten Funktionen
// Da ESModules in Node.js keine direkte Manipulation von module.paths erlauben,
// verwenden wir einen workaround über dynamic imports oder relative Pfade
// Für dieses Beispiel nehmen wir an, dass sync_clawhub_git.js im gleichen Verzeichnis liegt
// oder im modulePath verfügbar ist

async function importSyncModule() {
  try {
    // Versuche es als ES Module zu importieren
    return await import(`file://${modulePath}/sync_clawhub_git.js`);
  } catch (error) {
    console.error('Fehler beim Importieren des Moduls:', error);
    process.exit(1);
  }
}

// Hilfsfunktion zur Rekursiven Verzeichnisauflistung (ähnlich wie os.walk)
function walkDir(dir, callback, level = 0) {
  const indent = ' '.repeat(2 * level);
  const subindent = ' '.repeat(2 * (level + 1));
  
  try {
    const items = readdirSync(dir, { withFileTypes: true });
    
    for (const item of items) {
      if (item.isDirectory()) {
        console.log(`${indent}${item.name}/`);
        walkDir(join(dir, item.name), callback, level + 1);
      } else {
        console.log(`${subindent}${item.name}`);
      }
    }
  } catch (err) {
    console.error(`Fehler beim Lesen des Verzeichnisses ${dir}:`, err.message);
  }
}

// Hauptprogramm
async function main() {
  const syncModule = await importSyncModule();
  const { sync_to_git, log } = syncModule;

  // Test: db-maintainer ClawHub → Git (ECHT)
  console.log("=== TEST: db-maintainer sync (REAL) ===");
  const skill = "db-maintainer";
  const result = sync_to_git(skill, false); // dry_run = false
  console.log(`Result: ${result ? 'SUCCESS' : 'FAILED'}`);

  // Prüfe Ergebnis
  const target = "/home/openclaw/.openclaw/workspace/git/skills/db-maintainer";
  if (existsSync(target)) {
    console.log(`\n✅ Git-Repo erstellt: ${target}`);
    console.log(`${basename(target)}/`);
    walkDir(target, undefined, 1);
  }
}

main().catch(console.error);
