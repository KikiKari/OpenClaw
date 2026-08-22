#!/usr/bin/env node
// sync_agent_run.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:scripts/sync_agent_run.py
// auch in: OpenClaw@gateway2:scripts/sync_agent_run.py
// Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

/**
 * ClawHub ↔ Git Sync Agent - Produktionslauf
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Add custom module paths
const MODULE_PATH = '/home/openclaw/.openclaw/workspace/scripts';
const CUSTOM_MODULES_PATH = path.join(MODULE_PATH, 'node_modules');

// Mock the Python imports with local implementations
function log(message, level = "INFO") {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${level}: ${message}`);
}

function validate_skill(skillPath) {
  // Simple validation - check if directory exists and has files
  try {
    return fs.existsSync(skillPath) && fs.readdirSync(skillPath).length > 0;
  } catch {
    return false;
  }
}

function sync_to_git(skill, dry_run = false) {
  if (dry_run) return true;
  try {
    const source = path.join(CLAWHUB_DIR, skill);
    const dest = path.join(GIT_DIR, skill);
    
    // Create destination directory if it doesn't exist
    if (!fs.existsSync(dest)) {
      fs.mkdirSync(dest, { recursive: true });
    }
    
    // Copy all files from source to destination
    copyDirectory(source, dest);
    return true;
  } catch (error) {
    log(`Sync to git failed for ${skill}: ${error.message}`, "ERROR");
    return false;
  }
}

function sync_to_clawhub(skill, dry_run = false) {
  if (dry_run) return true;
  try {
    const source = path.join(GIT_DIR, skill);
    const dest = path.join(CLAWHUB_DIR, skill);
    
    // Create destination directory if it doesn't exist
    if (!fs.existsSync(dest)) {
      fs.mkdirSync(dest, { recursive: true });
    }
    
    // Copy all files from source to destination
    copyDirectory(source, dest);
    return true;
  } catch (error) {
    log(`Sync to clawhub failed for ${skill}: ${error.message}`, "ERROR");
    return false;
  }
}

function copyDirectory(src, dest) {
  if (!fs.existsSync(dest)) {
    fs.mkdirSync(dest, { recursive: true });
  }
  
  const entries = fs.readdirSync(src, { withFileTypes: true });
  
  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    
    if (entry.isDirectory()) {
      copyDirectory(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

function file_mtime(dirPath) {
  try {
    const getAllFiles = (dir) => {
      let results = [];
      const list = fs.readdirSync(dir, { withFileTypes: true });
      
      list.forEach((file) => {
        const filePath = path.join(dir, file.name);
        if (file.name.includes('.git')) return;
        
        if (file.isDirectory()) {
          results = results.concat(getAllFiles(filePath));
        } else {
          results.push(filePath);
        }
      });
      
      return results;
    };
    
    const files = getAllFiles(dirPath);
    if (files.length === 0) return 0;
    
    const mtimes = files.map(file => fs.statSync(file).mtime.getTime());
    return Math.max(...mtimes) / 1000; // Convert to seconds to match Python behavior
  } catch {
    return 0;
  }
}

const CLAWHUB_DIR = '/home/openclaw/.openclaw/workspace/skills';
const GIT_DIR = '/home/openclaw/.openclaw/workspace/git/skills';

log("=".repeat(70));
log("CLAWHUB ↔ GIT SYNC AGENT - PRODUKTIONS-LAUF");
log(`Zeitstempel: ${new Date().toISOString()}`);
log("=".repeat(70));

// Get directories excluding hidden ones
function getSkillDirs(dirPath) {
  try {
    return fs.readdirSync(dirPath, { withFileTypes: true })
      .filter(dirent => dirent.isDirectory() && !dirent.name.startsWith('.'))
      .map(dirent => dirent.name);
  } catch {
    return [];
  }
}

const clawhub_skills = new Set(getSkillDirs(CLAWHUB_DIR));
const git_skills = new Set(getSkillDirs(GIT_DIR));

const results = {
  synced_to_git: [],
  synced_to_clawhub: [],
  up_to_date: [],
  errors: []
};

// 1. NEU in ClawHub → zu Git syncen
log("\n[PHASE 1] ClawHub → Git Synchronisation");
log("-".repeat(40));

const new_in_clawhub = [...clawhub_skills].filter(skill => !git_skills.has(skill)).sort();
for (const skill of new_in_clawhub) {
  try {
    if (validate_skill(path.join(CLAWHUB_DIR, skill))) {
      log(`→ Synchronisiere ${skill} zu Git...`);
      if (sync_to_git(skill, false)) {
        // Git init
        const git_path = path.join(GIT_DIR, skill);
        process.chdir(git_path);
        try {
          execSync('git init -q 2>/dev/null', { stdio: 'ignore' });
          execSync('git add . -f 2>/dev/null', { stdio: 'ignore' });
          const dt = new Date().toLocaleString('sv-SE').slice(0, 16); // Format like Python's strftime
          execSync(`git commit -m "Initial: ${skill}" -q 2>/dev/null`, { stdio: 'ignore' });
        } catch (gitError) {
          // Ignore git errors
        }
        results.synced_to_git.push(skill);
        log(`  ✓ ${skill} synchronisiert & Git initialisiert`);
      } else {
        results.errors.push(`${skill} (sync failed)`);
      }
    } else {
      results.errors.push(`${skill} (invalid)`);
    }
  } catch (e) {
    log(`  ✗ ERROR: ${skill} - ${e.message}`, "ERROR");
    results.errors.push(`${skill} (exception)`);
  }
}

// 2. In beiden - prüfe Änderungen
log("\n[PHASE 2] Prüfe existierende Skills auf Änderungen");
log("-".repeat(40));

const in_both = [...clawhub_skills].filter(skill => git_skills.has(skill)).sort();
for (const skill of in_both) {
  try {
    const c_mtime = file_mtime(path.join(CLAWHUB_DIR, skill));
    const g_mtime = file_mtime(path.join(GIT_DIR, skill));
    const diff = c_mtime - g_mtime;

    if (Math.abs(diff) > 60) {
      if (diff > 0) {
        log(`→ ${skill}: ClawHub neuer (+${Math.round(diff)}s) → sync zu Git`);
        if (sync_to_git(skill, false)) {
          const git_path = path.join(GIT_DIR, skill);
          process.chdir(git_path);
          try {
            execSync('git add . -f 2>/dev/null', { stdio: 'ignore' });
            const dt = new Date().toLocaleString('sv-SE').slice(0, 16);
            execSync(`git commit -m "Sync from ClawHub: ${dt}" -q 2>/dev/null`, { stdio: 'ignore' });
          } catch (gitError) {
            // Ignore git errors
          }
          results.synced_to_git.push(skill);
        } else {
          results.errors.push(`${skill} (update failed)`);
        }
      } else {
        log(`→ ${skill}: Git neuer (+${Math.round(Math.abs(diff))}s) → sync zu ClawHub`);
        if (sync_to_clawhub(skill, false)) {
          results.synced_to_clawhub.push(skill);
        } else {
          results.errors.push(`${skill} (update failed)`);
        }
      }
    } else {
      results.up_to_date.push(skill);
    }
  } catch (e) {
    log(`  ✗ ERROR: ${skill} - ${e.message}`, "ERROR");
    results.errors.push(`${skill} (exception)`);
  }
}

// ZUSAMMENFASSUNG
log("\n" + "=".repeat(70));
log("SYNCHRONISATION ABGESCHLOSSEN");
log("=".repeat(70));
log(`Zu Git synchronisiert:     ${results.synced_to_git.length}`);
if (results.synced_to_git.length > 0) {
  log(`  ${results.synced_to_git.join(', ')}`);
}
log(`Zu ClawHub synchronisiert: ${results.synced_to_clawhub.length}`);
if (results.synced_to_clawhub.length > 0) {
  log(`  ${results.synced_to_clawhub.join(', ')}`);
}
log(`Bereits aktuell:           ${results.up_to_date.length}`);
log(`Fehler:                    ${results.errors.length}`);
if (results.errors.length > 0) {
  log(`  ${results.errors.join(', ')}`);
}
log("=".repeat(70));

// Speichere State
const STATE_FILE = '/home/openclaw/.openclaw/workspace/db/sync_state.json';
const stateDir = path.dirname(STATE_FILE);
fs.mkdirSync(stateDir, { recursive: true });
const state = { last_run: new Date().toISOString(), results: results };
fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
log(`State gespeichert: ${STATE_FILE}`);
