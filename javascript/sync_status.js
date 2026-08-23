#!/usr/bin/env node
// sync_status.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/sync_status.py
// auch in: OpenClaw@gateway2:skills/sync-utils/scripts/sync_status.py
// Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

/**
 * Sync Status - Zeigt Status aller Skills
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// Konstanten
const CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills";
const GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills";
const STATE_FILE = "/home/openclaw/.openclaw/workspace/db/sync_state.json";

/**
 * Berechnet Hash einer Datei
 */
function getFileHash(filePath) {
    const hash = crypto.createHash('sha256');
    const fileBuffer = fs.readFileSync(filePath);
    hash.update(fileBuffer);
    return hash.digest('hex');
}

/**
 * Prüft Status eines Skills
 */
function checkSkillStatus(skillName) {
    const clawhubPath = path.join(CLAWHUB_DIR, skillName);
    const gitPath = path.join(GIT_DIR, skillName);
    
    const status = {
        name: skillName,
        in_clawhub: fs.existsSync(clawhubPath),
        in_git: fs.existsSync(gitPath),
        has_git_repo: fs.existsSync(path.join(gitPath, ".git")),
        status: "unknown",
        last_modified: {}
    };
    
    // Wenn nicht in Git, dann has_git_repo auf false setzen
    if (!status.in_git) {
        status.has_git_repo = false;
    }
    
    // Status bestimmen
    if (status.in_clawhub && !status.in_git) {
        status.status = "only_clawhub";
    } else if (status.in_git && !status.in_clawhub) {
        status.status = "only_git";
    } else if (status.in_clawhub && status.in_git) {
        // Timestamps vergleichen
        try {
            // Finde alle Dateien und deren mtime in clawhub
            let clawhubFiles = [];
            function walkClawhub(dir) {
                const files = fs.readdirSync(dir);
                for (const file of files) {
                    const filePath = path.join(dir, file);
                    const stat = fs.statSync(filePath);
                    if (stat.isDirectory()) {
                        walkClawhub(filePath);
                    } else {
                        clawhubFiles.push({path: filePath, mtime: stat.mtimeMs});
                    }
                }
            }
            
            walkClawhub(clawhubPath);
            const clawhubMtimes = clawhubFiles.map(f => f.mtime);
            const clawhubMtime = Math.max(...clawhubMtimes);
            
            // Finde alle Dateien und deren mtime in git (ohne .git)
            let gitFiles = [];
            function walkGit(dir) {
                const files = fs.readdirSync(dir);
                for (const file of files) {
                    const filePath = path.join(dir, file);
                    if (filePath.includes('.git')) continue;
                    const stat = fs.statSync(filePath);
                    if (stat.isDirectory()) {
                        walkGit(filePath);
                    } else {
                        gitFiles.push({path: filePath, mtime: stat.mtimeMs});
                    }
                }
            }
            
            walkGit(gitPath);
            const gitMtimes = gitFiles.map(f => f.mtime);
            const gitMtime = Math.max(...gitMtimes);
            
            status.last_modified.clawhub = new Date(clawhubMtime).toISOString().slice(0, 19).replace('T', ' ');
            status.last_modified.git = new Date(gitMtime).toISOString().slice(0, 19).replace('T', ' ');
            
            if (Math.abs(clawhubMtime - gitMtime) < 60000) { // 60 Sekunden in ms
                status.status = "synced";
            } else if (clawhubMtime > gitMtime) {
                status.status = "clawhub_newer";
            } else {
                status.status = "git_newer";
            }
        } catch (error) {
            status.status = "error";
        }
    }
    
    return status;
}

/**
 * Hauptfunktion
 */
function main() {
    console.log("=" .repeat(80));
    console.log("ClawHub ↔ Git Sync Status");
    console.log("=" .repeat(80));
    console.log(`Zeitpunkt: ${new Date().toISOString().slice(0, 19).replace('T', ' ')}`);
    console.log();
    
    // Alle Skills finden
    let allSkills = new Set();
    
    if (fs.existsSync(CLAWHUB_DIR)) {
        const clawhubDirs = fs.readdirSync(CLAWHUB_DIR)
            .filter(d => fs.statSync(path.join(CLAWHUB_DIR, d)).isDirectory() && !d.startsWith('.'));
        clawhubDirs.forEach(d => allSkills.add(d));
    }
    
    if (fs.existsSync(GIT_DIR)) {
        const gitDirs = fs.readdirSync(GIT_DIR)
            .filter(d => fs.statSync(path.join(GIT_DIR, d)).isDirectory() && !d.startsWith('.'));
        gitDirs.forEach(d => allSkills.add(d));
    }
    
    allSkills = Array.from(allSkills);
    
    // Status-Kategorien
    const categories = {
        "synced": [],
        "clawhub_newer": [],
        "git_newer": [],
        "only_clawhub": [],
        "only_git": [],
        "error": []
    };
    
    // Status für jeden Skill prüfen
    for (const skill of allSkills.sort()) {
        const status = checkSkillStatus(skill);
        categories[status.status].push(status);
    }
    
    // Ausgabe
    console.log(`📊 Gesamt: ${allSkills.length} Skills\n`);
    
    // Synchronisiert
    if (categories.synced.length > 0) {
        console.log(`✅ Synchronisiert (${categories.synced.length})`);
        for (const s of categories.synced) {
            console.log(`   - ${s.name}`);
        }
        console.log();
    }
    
    // ClawHub neuer
    if (categories.clawhub_newer.length > 0) {
        console.log(`🔄 ClawHub neuer (${categories.clawhub_newer.length})`);
        for (const s of categories.clawhub_newer) {
            console.log(`   - ${s.name} (ClawHub: ${s.last_modified.clawhub})`);
        }
        console.log();
    }
    
    // Git neuer
    if (categories.git_newer.length > 0) {
        console.log(`🔄 Git neuer (${categories.git_newer.length})`);
        for (const s of categories.git_newer) {
            console.log(`   - ${s.name} (Git: ${s.last_modified.git})`);
        }
        console.log();
    }
    
    // Nur in ClawHub
    if (categories.only_clawhub.length > 0) {
        console.log(`📦 Nur in ClawHub (${categories.only_clawhub.length})`);
        for (const s of categories.only_clawhub) {
            console.log(`   - ${s.name}`);
        }
        console.log();
    }
    
    // Nur in Git
    if (categories.only_git.length > 0) {
        console.log(`📁 Nur in Git (${categories.only_git.length})`);
        for (const s of categories.only_git) {
            console.log(`   - ${s.name}`);
        }
        console.log();
    }
    
    // Fehler
    if (categories.error.length > 0) {
        console.log(`❌ Fehler (${categories.error.length})`);
        for (const s of categories.error) {
            console.log(`   - ${s.name}`);
        }
        console.log();
    }
    
    // State-File Info
    if (fs.existsSync(STATE_FILE)) {
        const stateContent = fs.readFileSync(STATE_FILE, 'utf8');
        const state = JSON.parse(stateContent);
        const lastRuns = Object.keys(state.last_sync || {});
        if (lastRuns.length > 0) {
            console.log(`📅 Letzter automatischer Sync: ${lastRuns[lastRuns.length - 1]}`);
        }
    }
    
    console.log("=" .repeat(80));
}

main();
