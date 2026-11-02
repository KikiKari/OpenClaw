#!/usr/bin/env node
// run_sync_agent.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway2:scripts/run_sync_agent.py
// Erzeugt: 2026-11-02 durch ABSTRACTIONS_MANAGER.py

/* Sandbox-Wrapper für sync_agent.js: mappt hartcodierte Host-Pfade auf /workspace. */
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import { createRequire } from 'module';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Füge Pfade zum Modul-Suchpfad hinzu
const require = createRequire(import.meta.url);
const modulePaths = [
  '/workspace/scripts',
  '/workspace/skills/clawhub-git-sync-agent/scripts'
];

// Modifiziere den Modul-Suchpfad
const originalResolveFilename = require('module')._resolveFilename;
require('module')._resolveFilename = function(request, parent, isMain) {
  // Versuche zuerst die zusätzlichen Pfade
  for (const modulePath of modulePaths) {
    try {
      const resolvedPath = require('path').resolve(modulePath, request);
      return originalResolveFilename.call(this, resolvedPath, parent, isMain);
    } catch (e) {
      // Ignoriere Fehler und versuche nächsten Pfad
    }
  }
  // Fallback auf Standardverhalten
  return originalResolveFilename.call(this, request, parent, isMain);
};

// Importiere sync_agent
let syncAgent;
try {
  syncAgent = await import('/workspace/skills/clawhub-git-sync-agent/scripts/sync_agent.js');
} catch (e) {
  try {
    syncAgent = await import('/workspace/scripts/sync_agent.js');
  } catch (e2) {
    console.error('Konnte sync_agent nicht finden in beiden Pfaden');
    process.exit(1);
  }
}

// Setze Konstanten
const path = require('path');
const WS = '/workspace';
syncAgent.CLAWHUB_DIR = path.join(WS, 'skills');
syncAgent.GIT_DIR = path.join(WS, 'git', 'skills');
syncAgent.STATE_FILE = path.join(WS, 'db', 'sync_state.json');

// Hauptfunktion aufrufen
if (typeof syncAgent.main === 'function') {
  syncAgent.main();
} else {
  console.error('sync_agent.main ist keine Funktion');
  process.exit(1);
}
