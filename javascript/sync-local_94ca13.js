#!/usr/bin/env node
// sync-local.sh — portiert nach javascript
// Quelle: shell, Onboarding@main:scripts/sync-local.sh
// Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

// JavaScript-Äquivalent zu sync-local.ps1 — inkrementeller Git-Sync für den Dev-Stack.
// Nutzung: scripts/sync-local.js [--branch <name>] [--interval <s>] [--once]

import { execSync, spawn } from 'child_process';
import { readFileSync, existsSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

let BRANCH = "claude/onboarding-persistent-sandbox-vjfmcx";
let INTERVAL = 20;
const COMPOSE_FILE = "docker-compose.dev.yml";
let ONCE = false;

const args = process.argv.slice(2);
for (let i = 0; i < args.length; i++) {
  switch (args[i]) {
    case "--branch":
      BRANCH = args[++i];
      break;
    case "--interval":
      INTERVAL = parseInt(args[++i]);
      break;
    case "--once":
      ONCE = true;
      break;
    default:
      console.error(`Unbekannte Option: ${args[i]}`);
      process.exit(1);
  }
}

process.chdir(join(__dirname, ".."));

function log(message) {
  const timestamp = new Date().toLocaleTimeString('de-DE', { hour12: false });
  console.log(`[${timestamp}] ${message}`);
}

function compose(...cmd) {
  try {
    const command = `docker compose -f "${COMPOSE_FILE}" ${cmd.join(' ')}`;
    execSync(command, { stdio: 'inherit' });
  } catch (error) {
    log(`WARNUNG: docker compose ${cmd.join(' ')} fehlgeschlagen`);
  }
}

function execGit(args, options = {}) {
  const cmd = `git ${args.join(' ')}`;
  return execSync(cmd, { encoding: 'utf8', ...options });
}

const current = execGit(['rev-parse', '--abbrev-ref', 'HEAD']).trim();
if (current !== BRANCH) {
  log(`Wechsle von '${current}' auf '${BRANCH}' …`);
  execGit(['fetch', 'origin', BRANCH]);
  try {
    execGit(['switch', BRANCH]);
  } catch (error) {
    execGit(['switch', '-c', BRANCH, '--track', `origin/${BRANCH}`]);
  }
}

log(`Sync aktiv: origin/${BRANCH} -> ${process.cwd()} (Intervall ${INTERVAL}s, Compose: ${COMPOSE_FILE})`);

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function mainLoop() {
  while (true) {
    try {
      execGit(['fetch', 'origin', BRANCH], { stdio: 'ignore' });
      
      const local_rev = execGit(['rev-parse', 'HEAD']).trim();
      const remote_rev = execGit(['rev-parse', `origin/${BRANCH}`]).trim();
      
      if (local_rev !== remote_rev) {
        const isAncestor = execGit(['merge-base', '--is-ancestor', local_rev, remote_rev], { stdio: 'ignore' })
          .catch(() => false);
        
        if (!await isAncestor) {
          log("ACHTUNG: Lokaler Stand von origin/" + BRANCH + " abgewichen — kein automatischer Merge, bitte manuell auflösen.");
        } else {
          const changedOutput = execGit(['diff', '--name-only', `${local_rev}..${remote_rev}`]);
          const changed = changedOutput.trim() ? changedOutput.trim().split('\n') : [];
          
          execGit(['merge', '--ff-only', remote_rev], { stdio: 'ignore' });
          log(`Aktualisiert ${local_rev.substring(0, 7)} -> ${remote_rev.substring(0, 7)} (${changed.length} Datei(en))`);

          let needs_none = true;
          
          if (changed.includes(COMPOSE_FILE)) {
            log("Compose-Datei geändert — erzeuge Dev-Stack neu …");
            compose('up', '-d');
            needs_none = false;
          }
          
          if (changed.some(file => /^backend\/(Dockerfile|requirements.*\.txt)$/.test(file))) {
            log("Backend-Dependencies/Dockerfile geändert — baue nur das Backend neu …");
            compose('up', '-d', '--build', 'backend');
            needs_none = false;
          }
          
          if (changed.some(file => /^(package\.json|package-lock\.json)$/.test(file))) {
            log("Frontend-Dependencies geändert — starte Frontend neu (npm install läuft im Container) …");
            compose('restart', 'frontend');
            needs_none = false;
          }
          
          if (needs_none) {
            log("Nur Quellcode/Assets — Hot-Reload übernimmt, kein Build nötig.");
          }
        }
      }
    } catch (error) {
      log(`Fetch fehlgeschlagen (Netzwerk?) — nächster Versuch in ${INTERVAL}s`);
    }
    
    if (ONCE) break;
    await sleep(INTERVAL * 1000);
  }
}

mainLoop().catch(console.error);
