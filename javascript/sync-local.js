#!/usr/bin/env node
// sync-local.ps1 — portiert nach javascript
// Quelle: powershell, Onboarding@main:scripts/sync-local.ps1
// Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

'use strict';

const fs = require('fs');
const path = require('path');
const { spawn, execSync } = require('child_process');

// Parameter mit Standardwerten
const args = process.argv.slice(2);
let branch = "claude/onboarding-persistent-sandbox-vjfmcx";
let intervalSeconds = 20;
let composeFile = "docker-compose.dev.yml";
let once = false;

// Argumente parsen
for (let i = 0; i < args.length; i++) {
  switch (args[i]) {
    case '-Branch':
      branch = args[++i];
      break;
    case '-IntervalSeconds':
      intervalSeconds = parseInt(args[++i]);
      break;
    case '-ComposeFile':
      composeFile = args[++i];
      break;
    case '-Once':
      once = true;
      break;
  }
}

const repoRoot = path.resolve(__dirname, '..');
process.chdir(repoRoot);

function log(msg) {
  const now = new Date().toLocaleTimeString('de-DE', { hour12: false });
  console.log(`[${now}] ${msg}`);
}

function invokeCompose(composeArgs) {
  const cmd = spawn('docker', ['compose', '-f', composeFile, ...composeArgs], { stdio: 'inherit' });
  
  cmd.on('close', (code) => {
    if (code !== 0) {
      log(`WARNUNG: docker compose ${composeArgs.join(' ')} fehlgeschlagen (Exit ${code})`);
    }
  });
  
  return cmd;
}

function executeCommand(command, options = {}) {
  try {
    const result = execSync(command, {
      cwd: repoRoot,
      encoding: 'utf8',
      stdio: options.quiet ? 'pipe' : 'inherit',
      ...options
    });
    return { success: true, output: result?.trim() };
  } catch (error) {
    return { success: false, error: error.message, code: error.status };
  }
}

// Sicherstellen, dass der Ziel-Branch ausgecheckt ist
const currentResult = executeCommand('git rev-parse --abbrev-ref HEAD');
const current = currentResult.output;

if (current !== branch) {
  log(`Wechsle von '${current}' auf '${branch}' …`);
  executeCommand(`git fetch origin ${branch}`);
  let switchResult = executeCommand(`git switch ${branch}`, { quiet: true });
  
  if (!switchResult.success) {
    switchResult = executeCommand(`git switch -c ${branch} --track origin/${branch}`);
  }
  
  if (!switchResult.success) {
    throw new Error(`Branch '${branch}' konnte nicht ausgecheckt werden.`);
  }
}

log(`Sync aktiv: origin/${branch} -> ${repoRoot} (Intervall ${intervalSeconds}s, Compose: ${composeFile})`);

async function syncLoop() {
  while (true) {
    const fetchResult = executeCommand(`git fetch origin ${branch} --quiet`);
    
    if (!fetchResult.success) {
      log(`Fetch fehlgeschlagen (Netzwerk?) — nächster Versuch in ${intervalSeconds}s`);
    } else {
      const localResult = executeCommand('git rev-parse HEAD');
      const remoteResult = executeCommand(`git rev-parse origin/${branch}`);
      
      const local = localResult.output;
      const remote = remoteResult.output;
      
      if (local !== remote) {
        const ancestorResult = executeCommand(`git merge-base --is-ancestor ${local} ${remote}`);
        
        if (!ancestorResult.success) {
          log(`ACHTUNG: Lokaler Stand ist von origin/${branch} abgewichen (lokale Commits?). Kein automatischer Merge — bitte manuell auflösen.`);
        } else {
          const diffResult = executeCommand(`git diff --name-only "${local}..${remote}"`);
          const changed = diffResult.output ? diffResult.output.split('\n').filter(line => line.trim()) : [];
          
          executeCommand(`git merge --ff-only ${remote} --quiet`);
          log(`Aktualisiert ${local.substring(0, 7)} -> ${remote.substring(0, 7)} (${changed.length} Datei(en))`);
          
          const frontendDeps = changed.filter(file => 
            file === "package.json" || file === "package-lock.json"
          );
          
          const backendImage = changed.filter(file => 
            /^backend\/(Dockerfile|requirements.*\.txt)$/.test(file)
          );
          
          const composeChanged = changed.includes(composeFile);
          
          if (composeChanged) {
            log("Compose-Datei geändert — erzeuge Dev-Stack neu …");
            await new Promise(resolve => {
              const proc = invokeCompose(["up", "-d"]);
              proc.on('close', resolve);
            });
          }
          
          if (backendImage.length > 0) {
            log("Backend-Dependencies/Dockerfile geändert — baue nur das Backend neu …");
            await new Promise(resolve => {
              const proc = invokeCompose(["up", "-d", "--build", "backend"]);
              proc.on('close', resolve);
            });
          }
          
          if (frontendDeps.length > 0) {
            log("Frontend-Dependencies geändert — starte Frontend neu (npm install läuft im Container) …");
            await new Promise(resolve => {
              const proc = invokeCompose(["restart", "frontend"]);
              proc.on('close', resolve);
            });
          }
          
          if (!(composeChanged || backendImage.length > 0 || frontendDeps.length > 0)) {
            log("Nur Quellcode/Assets — Hot-Reload übernimmt, kein Build nötig.");
          }
        }
      }
    }
    
    if (once) break;
    
    await new Promise(resolve => setTimeout(resolve, intervalSeconds * 1000));
  }
}

syncLoop().catch(error => {
  console.error(error.message);
  process.exit(1);
});
