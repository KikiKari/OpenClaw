#!/usr/bin/env node
// sync_agent_cron.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:scripts/sync_agent_cron.py
// auch in: OpenClaw@gateway2:scripts/sync_agent_cron.py
// Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

/**
 * ClawHub ↔ Git Sync Agent - Cron Version mit Dry-Run + Auto-Sync
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const CLAWHUB_DIR = '/home/openclaw/.openclaw/workspace/skills';
const GIT_DIR = '/home/openclaw/.openclaw/workspace/git/skills';
const LOG_FILE = '/home/openclaw/.openclaw/workspace/logs/sync-agent.log';

// Dynamically import the sync module
let syncModule;
try {
  syncModule = require('/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.js');
} catch (e) {
  console.error('Cannot load sync module:', e.message);
  process.exit(1);
}

const { syncToGit, syncToClawhub, validateSkill } = syncModule;

function fileMtime(dirPath) {
  try {
    const getAllFiles = (dir) => {
      let results = [];
      const list = fs.readdirSync(dir);
      list.forEach((file) => {
        file = path.resolve(dir, file);
        const stat = fs.statSync(file);
        if (stat && stat.isDirectory()) {
          if (!file.includes('.git')) {
            results = results.concat(getAllFiles(file));
          }
        } else {
          if (!file.includes('.git')) {
            results.push(file);
          }
        }
      });
      return results;
    };

    const files = getAllFiles(dirPath);
    if (files.length === 0) return 0;
    
    const mtimes = files.map(file => fs.statSync(file).mtime.getTime());
    return Math.max(...mtimes) / 1000; // Convert to seconds
  } catch {
    return 0;
  }
}

function writeToLog(message, level = "INFO") {
  const timestamp = new Date().toISOString().replace('T', ' ').substring(0, 19);
  const entry = `[${timestamp}] [${level}] ${message}`;
  console.log(entry);
  fs.appendFileSync(LOG_FILE, entry + '\n');
}

// Override log function in sync module
syncModule.log = writeToLog;

writeToLog("=".repeat(70));
writeToLog("CLAWHUB ↔ GIT SYNC AGENT - CRON LAUF");
writeToLog(`Zeitstempel: ${new Date().toISOString()}`);
writeToLog("=".repeat(70));

const getDirectories = (source) =>
  fs.readdirSync(source, { withFileTypes: true })
    .filter(dirent => dirent.isDirectory() && !dirent.name.startsWith('.'))
    .map(dirent => dirent.name);

const clawhubSkills = new Set(getDirectories(CLAWHUB_DIR));
const gitSkills = new Set(getDirectories(GIT_DIR));

// DRY-RUN: Erkenne Änderungen
writeToLog("\n[DRY-RUN] Analysiere Änderungen...");

const changesDetected = {
  new_in_clawhub: [],
  new_in_git: [],
  clawhub_newer: [],
  git_newer: [],
  synced: []
};

// 1. Neue Skills
const newInClawhub = [...clawhubSkills].filter(x => !gitSkills.has(x)).sort();
const newInGit = [...gitSkills].filter(x => !clawhubSkills.has(x)).sort();
changesDetected.new_in_clawhub = newInClawhub;
changesDetected.new_in_git = newInGit;

// 2. Existierende prüfen
const inBoth = [...clawhubSkills].filter(x => gitSkills.has(x)).sort();
for (const skill of inBoth) {
  const cMtime = fileMtime(path.join(CLAWHUB_DIR, skill));
  const gMtime = fileMtime(path.join(GIT_DIR, skill));
  const diff = cMtime - gMtime;

  if (Math.abs(diff) > 60) {
    if (diff > 0) {
      changesDetected.clawhub_newer.push([skill, diff]);
    } else {
      changesDetected.git_newer.push([skill, Math.abs(diff)]);
    }
  } else {
    changesDetected.synced.push(skill);
  }
}

// Report
const totalChanges = newInClawhub.length + newInGit.length + 
                     changesDetected.clawhub_newer.length + changesDetected.git_newer.length;

writeToLog(`Neu in ClawHub: ${newInClawhub.length}`);
writeToLog(`Neu in Git: ${newInGit.length}`);
writeToLog(`ClawHub neuer: ${changesDetected.clawhub_newer.length}`);
writeToLog(`Git neuer: ${changesDetected.git_newer.length}`);
writeToLog(`Synchron: ${changesDetected.synced.length}`);

if (totalChanges === 0) {
  writeToLog("\n✅ Keine Änderungen erkannt. Sync nicht nötig.");
  writeToLog("=".repeat(70));
  process.exit(0);
}

writeToLog(`\n🔄 ${totalChanges} Änderungen erkannt - starte Synchronisation...`);

// ECHTE SYNCHRONISATION
const results = {
  synced_to_git: [],
  synced_to_clawhub: [],
  up_to_date: [],
  errors: []
};

// 1. NEU in ClawHub → zu Git
for (const skill of newInClawhub) {
  try {
    if (validateSkill(path.join(CLAWHUB_DIR, skill))) {
      writeToLog(`→ Synchronisiere ${skill} zu Git...`);
      if (syncToGit(skill, false)) {
        const gitPath = path.join(GIT_DIR, skill);
        process.chdir(gitPath);
        try { execSync('git init -q 2>/dev/null'); } catch {}
        try { execSync('git add . -f 2>/dev/null'); } catch {}
        const dt = new Date().toISOString().replace('T', ' ').substring(0, 16);
        try { execSync(`git commit -m "Initial: ${skill}" -q 2>/dev/null`); } catch {}
        results.synced_to_git.push(skill);
        writeToLog(`  ✓ ${skill} synchronisiert`);
      }
    } else {
      results.errors.push(`${skill} (invalid)`);
    }
  } catch (e) {
    writeToLog(`  ✗ ERROR: ${skill} - ${e.message}`, "ERROR");
    results.errors.push(`${skill}`);
  }
}

// 2. NEU in Git → zu ClawHub
for (const skill of newInGit) {
  try {
    if (validateSkill(path.join(GIT_DIR, skill))) {
      writeToLog(`→ Synchronisiere ${skill} zu ClawHub...`);
      if (syncToClawhub(skill, false)) {
        results.synced_to_clawhub.push(skill);
        writeToLog(`  ✓ ${skill} synchronisiert`);
      }
    } else {
      results.errors.push(`${skill} (invalid)`);
    }
  } catch (e) {
    writeToLog(`  ✗ ERROR: ${skill} - ${e.message}`, "ERROR");
    results.errors.push(`${skill}`);
  }
}

// 3. Updates
for (const [skill, diff] of changesDetected.clawhub_newer) {
  try {
    writeToLog(`→ Update ${skill} (ClawHub +${Math.round(diff)}s neuer)...`);
    if (syncToGit(skill, false)) {
      const gitPath = path.join(GIT_DIR, skill);
      process.chdir(gitPath);
      try { execSync('git add . -f 2>/dev/null'); } catch {}
      const dt = new Date().toISOString().replace('T', ' ').substring(0, 16);
      try { execSync(`git commit -m "Sync from ClawHub: ${dt}" -q 2>/dev/null`); } catch {}
      results.synced_to_git.push(skill);
      writeToLog(`  ✓ ${skill} aktualisiert`);
    }
  } catch (e) {
    writeToLog(`  ✗ ERROR: ${skill} - ${e.message}`, "ERROR");
    results.errors.push(`${skill}`);
  }
}

for (const [skill, diff] of changesDetected.git_newer) {
  try {
    writeToLog(`→ Update ${skill} (Git +${Math.round(diff)}s neuer)...`);
    if (syncToClawhub(skill, false)) {
      results.synced_to_clawhub.push(skill);
      writeToLog(`  ✓ ${skill} aktualisiert`);
    }
  } catch (e) {
    writeToLog(`  ✗ ERROR: ${skill} - ${e.message}`, "ERROR");
    results.errors.push(`${skill}`);
  }
}

results.up_to_date = changesDetected.synced;

// ZUSAMMENFASSUNG
writeToLog("\n" + "=".repeat(70));
writeToLog("SYNCHRONISATION ABGESCHLOSSEN");
writeToLog("=".repeat(70));
writeToLog(`Zu Git synchronisiert:     ${results.synced_to_git.length}`);
writeToLog(`Zu ClawHub synchronisiert: ${results.synced_to_clawhub.length}`);
writeToLog(`Bereits aktuell:           ${results.up_to_date.length}`);
writeToLog(`Fehler:                    ${results.errors.length}`);
if (results.errors.length > 0) {
  writeToLog(`  Fehlerhafte: ${results.errors.join(', ')}`);
}
writeToLog("=".repeat(70));

// State speichern
const STATE_FILE = "/home/openclaw/.openclaw/workspace/db/sync_state.json";
const stateDir = path.dirname(STATE_FILE);
fs.mkdirSync(stateDir, { recursive: true });

const state = {
  last_run: new Date().toISOString(),
  results: results,
  changes_detected: Object.fromEntries(
    Object.entries(changesDetected).map(([k, v]) => [
      k,
      Array.isArray(v) ? v.length : v
    ])
  )
};

fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
writeToLog(`State gespeichert: ${STATE_FILE}`);
