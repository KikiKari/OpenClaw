#!/usr/bin/env node
// sync_bulk.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/sync_bulk.py
// auch in: OpenClaw@gateway2:skills/sync-utils/scripts/sync_bulk.py
// Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

/**
 * Bulk Sync - Synchronisiert alle Skills
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Pfade definieren
const CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills";
const GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills";

// Hilfsfunktionen aus sync_clawhub_git.js laden
const syncModulePath = '/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.js';
let syncFunctions = {};

try {
  syncFunctions = require(syncModulePath);
} catch (error) {
  console.error(`Fehler beim Laden der Sync-Funktionen: ${error.message}`);
  process.exit(1);
}

const { syncToGit, syncToClawhub, log, validateSkill } = syncFunctions;

function getAllSkills() {
  const skills = new Set();
  
  // Skills aus ClawHub-Verzeichnis sammeln
  if (fs.existsSync(CLAWHUB_DIR)) {
    const clawhubSkills = fs.readdirSync(CLAWHUB_DIR)
      .filter(item => {
        const fullPath = path.join(CLAWHUB_DIR, item);
        return fs.statSync(fullPath).isDirectory() && !item.startsWith('.');
      });
    clawhubSkills.forEach(skill => skills.add(skill));
  }
  
  // Skills aus Git-Verzeichnis sammeln
  if (fs.existsSync(GIT_DIR)) {
    const gitSkills = fs.readdirSync(GIT_DIR)
      .filter(item => {
        const fullPath = path.join(GIT_DIR, item);
        return fs.statSync(fullPath).isDirectory() && !item.startsWith('.');
      });
    gitSkills.forEach(skill => skills.add(skill));
  }
  
  return skills;
}

function getMaxMtime(dirPath) {
  let maxTime = 0;
  
  function walk(currentPath) {
    const items = fs.readdirSync(currentPath);
    for (const item of items) {
      const fullPath = path.join(currentPath, item);
      const stat = fs.statSync(fullPath);
      
      if (stat.isDirectory()) {
        // Ignoriere .git Verzeichnisse
        if (!fullPath.includes('.git')) {
          walk(fullPath);
        }
      } else {
        maxTime = Math.max(maxTime, stat.mtime.getTime());
      }
    }
  }
  
  if (fs.existsSync(dirPath)) {
    walk(dirPath);
  }
  
  return maxTime;
}

async function syncAllSkills(dryRun = true) {
  const allSkills = getAllSkills();
  log(`Bulk Sync: ${allSkills.size} Skills gefunden`);
  
  const results = {
    synced: [],
    skipped: [],
    failed: []
  };
  
  for (const skill of Array.from(allSkills).sort()) {
    const clawhubPath = path.join(CLAWHUB_DIR, skill);
    const gitPath = path.join(GIT_DIR, skill);
    
    try {
      const clawhubExists = fs.existsSync(clawhubPath);
      const gitExists = fs.existsSync(gitPath);
      
      // Nur in ClawHub → zu Git
      if (clawhubExists && !gitExists) {
        if (validateSkill(clawhubPath)) {
          log(`Syncing ${skill} to Git...`);
          if (await syncToGit(skill, dryRun)) {
            results.synced.push(`${skill} → Git`);
          } else {
            results.failed.push(skill);
          }
        } else {
          results.skipped.push(`${skill} (validation failed)`);
        }
      }
      
      // Nur in Git → zu ClawHub
      else if (gitExists && !clawhubExists) {
        if (validateSkill(gitPath)) {
          log(`Syncing ${skill} to ClawHub...`);
          if (await syncToClawhub(skill, dryRun)) {
            results.synced.push(`${skill} → ClawHub`);
          } else {
            results.failed.push(skill);
          }
        } else {
          results.skipped.push(`${skill} (validation failed)`);
        }
      }
      
      // In beiden - prüfe ob Update nötig
      else if (clawhubExists && gitExists) {
        const clawhubMtime = getMaxMtime(clawhubPath);
        const gitMtime = getMaxMtime(gitPath);
        
        if (Math.abs(clawhubMtime - gitMtime) > 60000) { // 60 Sekunden in ms
          if (clawhubMtime > gitMtime) {
            log(`Updating ${skill} in Git...`);
            if (await syncToGit(skill, dryRun)) {
              results.synced.push(`${skill} → Git (update)`);
            } else {
              results.failed.push(skill);
            }
          } else {
            log(`Updating ${skill} in ClawHub...`);
            if (await syncToClawhub(skill, dryRun)) {
              results.synced.push(`${skill} → ClawHub (update)`);
            } else {
              results.failed.push(skill);
            }
          }
        } else {
          results.skipped.push(`${skill} (already synced)`);
        }
      }
    } catch (e) {
      log(`Error processing ${skill}: ${e.message}`, "ERROR");
      results.failed.push(skill);
    }
  }
  
  // Zusammenfassung
  console.log("\n" + "=".repeat(60));
  console.log(`Bulk Sync ${dryRun ? 'DRY-RUN' : 'EXECUTED'} - Zusammenfassung`);
  console.log("=".repeat(60));
  console.log(`✅ Synchronisiert: ${results.synced.length}`);
  for (const item of results.synced) {
    console.log(`   - ${item}`);
  }
  console.log(`\n⏭️  Übersprungen: ${results.skipped.length}`);
  if (results.skipped.length <= 10) {
    for (const item of results.skipped) {
      console.log(`   - ${item}`);
    }
  } else {
    console.log(`   - ${results.skipped.length} Skills (bereits synchron oder Validierung fehlgeschlagen)`);
  }
  console.log(`\n❌ Fehlgeschlagen: ${results.failed.length}`);
  for (const item of results.failed) {
    console.log(`   - ${item}`);
  }
  console.log("=".repeat(60));
}

function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const execute = args.includes('--execute');
  
  if (!dryRun && !execute) {
    console.log("Bitte --dry-run oder --execute angeben");
    process.exit(1);
  }
  
  syncAllSkills(dryRun);
}

main();
