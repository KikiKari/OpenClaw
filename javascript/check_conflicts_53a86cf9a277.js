#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "34f9b751c93c6241cf655668b471d369fb5f006e767103169a548216f8e419cd", "source_sha256": "5d90ebcd250a3cb80a0de664d94397af7ec03343d9d9fa64a28a9a11ad880754", "target_language": "javascript"}
// check_conflicts.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/check_conflicts.py
// auch in: OpenClaw@gateway2:skills/sync-utils/scripts/check_conflicts.py
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

/**
 * Check Conflicts - Erkennt Sync-Konflikte
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Import sync functions
const SYNC_UTILS_PATH = '/home/openclaw/.openclaw/workspace/scripts';
const syncModulePath = path.join(SYNC_UTILS_PATH, 'sync_clawhub_git.js');

// Dynamically import the module
let getFileHash;
try {
  const syncModule = require(syncModulePath);
  getFileHash = syncModule.getFileHash;
} catch (error) {
  console.error(`Fehler beim Laden des Moduls ${syncModulePath}:`, error.message);
  process.exit(1);
}

const CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills";
const GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills";

function getAllFiles(dirPath, arrayOfFiles = []) {
  const files = fs.readdirSync(dirPath);

  files.forEach(file => {
    if (file === '.git') return; // Skip .git directories
    
    const filePath = path.join(dirPath, file);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory()) {
      arrayOfFiles = getAllFiles(filePath, arrayOfFiles);
    } else {
      arrayOfFiles.push(filePath);
    }
  });

  return arrayOfFiles;
}

function checkConflicts() {
  /** Prüft auf Konflikte zwischen ClawHub und Git */
  let conflicts = [];
  
  // Alle Skills die in beiden Orten existieren
  let commonSkills = [];
  
  if (fs.existsSync(CLAWHUB_DIR) && fs.existsSync(GIT_DIR)) {
    const clawhubSkills = fs.readdirSync(CLAWHUB_DIR)
      .filter(item => fs.statSync(path.join(CLAWHUB_DIR, item)).isDirectory());
    const gitSkills = fs.readdirSync(GIT_DIR)
      .filter(item => fs.statSync(path.join(GIT_DIR, item)).isDirectory());
    
    commonSkills = clawhubSkills.filter(skill => gitSkills.includes(skill));
  }
  
  console.log(`Prüfe ${commonSkills.length} Skills auf Konflikte...\n`);
  
  for (const skill of commonSkills.sort()) {
    const clawhubPath = path.join(CLAWHUB_DIR, skill);
    const gitPath = path.join(GIT_DIR, skill);
    
    // Alle Dateien vergleichen
    let skillConflicts = [];
    
    // ClawHub Dateien
    const clawhubFiles = {};
    if (fs.existsSync(clawhubPath)) {
      const clawhubFileList = getAllFiles(clawhubPath);
      for (const file of clawhubFileList) {
        const relPath = path.relative(clawhubPath, file);
        clawhubFiles[relPath] = file;
      }
    }
    
    // Git Dateien
    const gitFiles = {};
    if (fs.existsSync(gitPath)) {
      const gitFileList = getAllFiles(gitPath);
      for (const file of gitFileList) {
        const relPath = path.relative(gitPath, file);
        gitFiles[relPath] = file;
      }
    }
    
    // Vergleiche gemeinsame Dateien
    const commonFiles = Object.keys(clawhubFiles).filter(file => Object.hasOwn(gitFiles, file));
    
    for (const relPath of commonFiles) {
      const clawhubFile = clawhubFiles[relPath];
      const gitFile = gitFiles[relPath];
      
      if (getFileHash(clawhubFile) !== getFileHash(gitFile)) {
        const clawhubStat = fs.statSync(clawhubFile);
        const gitStat = fs.statSync(gitFile);
        
        const clawhubMtime = new Date(clawhubStat.mtimeMs);
        const gitMtime = new Date(gitStat.mtimeMs);
        
        skillConflicts.push({
          "file": relPath,
          "clawhub_modified": clawhubMtime.toISOString().slice(0, 19).replace('T', ' '),
          "git_modified": gitMtime.toISOString().slice(0, 19).replace('T', ' '),
          "newer": clawhubMtime > gitMtime ? "clawhub" : "git"
        });
      }
    }
    
    if (skillConflicts.length > 0) {
      conflicts.push({
        "skill": skill,
        "conflicts": skillConflicts
      });
    }
  }
  
  // Ausgabe
  if (conflicts.length > 0) {
    console.log("⚠️  KONFLIKTE GEFUNDEN:");
    console.log("=".repeat(80));
    
    for (const conflict of conflicts) {
      console.log(`\n📦 Skill: ${conflict.skill}`);
      console.log("-".repeat(40));
      
      for (const fileConflict of conflict.conflicts) {
        console.log(`  📄 ${fileConflict.file}`);
        console.log(`     ClawHub: ${fileConflict.clawhub_modified}`);
        console.log(`     Git:     ${fileConflict.git_modified}`);
        console.log(`     Neuer:   ${fileConflict.newer.toUpperCase()}`);
        console.log();
      }
    }
    
    console.log("=".repeat(80));
    console.log(`Gesamt: ${conflicts.length} Skills mit Konflikten`);
    console.log("\nNutze 'sync_utils/scripts/resolve_conflict.py' zum Auflösen.");
  } else {
    console.log("✅ Keine Konflikte gefunden!");
    console.log("Alle gemeinsamen Skills sind synchron.");
  }
}

function main() {
  /** Hauptfunktion */
  checkConflicts();
}

main();
