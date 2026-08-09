#!/usr/bin/env node
// check_conflicts.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/check_conflicts.py
// auch in: OpenClaw@gateway2:skills/sync-utils/scripts/check_conflicts.py
// Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

/**
 * Check Conflicts - Erkennt Sync-Konflikte
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Import sync functions
const { getFileHash } = require('/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.js');

const CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills";
const GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills";

function getFilesRecursively(dir, baseDir) {
    let files = {};
    const items = fs.readdirSync(dir);
    
    for (const item of items) {
        const fullPath = path.join(dir, item);
        const relativePath = path.relative(baseDir, fullPath);
        
        // Skip .git directories
        if (item === '.git') continue;
        
        const stat = fs.statSync(fullPath);
        if (stat.isDirectory()) {
            const subFiles = getFilesRecursively(fullPath, baseDir);
            Object.assign(files, subFiles);
        } else {
            files[relativePath] = fullPath;
        }
    }
    
    return files;
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
        const clawhubFiles = getFilesRecursively(clawhubPath, clawhubPath);
        
        // Git Dateien
        const gitFiles = getFilesRecursively(gitPath, gitPath);
        
        // Vergleiche gemeinsame Dateien
        const commonFiles = Object.keys(clawhubFiles).filter(file => Object.keys(gitFiles).includes(file));
        
        for (const relPath of commonFiles) {
            const clawhubFile = clawhubFiles[relPath];
            const gitFile = gitFiles[relPath];
            
            if (getFileHash(clawhubFile) !== getFileHash(gitFile)) {
                const clawhubStat = fs.statSync(clawhubFile);
                const gitStat = fs.statSync(gitFile);
                
                const clawhubMtime = new Date(clawhubStat.mtime);
                const gitMtime = new Date(gitStat.mtime);
                
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
            console.log(`\n📦 Skill: ${conflict['skill']}`);
            console.log("-".repeat(40));
            
            for (const fileConflict of conflict['conflicts']) {
                console.log(`  📄 ${fileConflict['file']}`);
                console.log(`     ClawHub: ${fileConflict['clawhub_modified']}`);
                console.log(`     Git:     ${fileConflict['git_modified']}`);
                console.log(`     Neuer:   ${fileConflict['newer'].toUpperCase()}`);
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
