#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "4452498fa468b4ac266f3e1964ec713b1d48d31ac2010454073414bf0f53ac5a", "source_sha256": "1bde9ce66616d24f21a9092c84abb4b447779e6077ec9035f2df678b92bb76f4", "target_language": "javascript"}
// sync_clawhub_git_local.py — portiert nach javascript
// Quelle: python, workspace@local:scripts/sync_clawhub_git_local.py
// auch in: workspace@local:scripts/sync_clawhub_git.py
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

/**
 * Bidirektionale ClawHub ↔ Git Synchronisation
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');

// Konfiguration
const __filename = process.argv[1];
const WORKSPACE_DIR = path.resolve(__filename, '..', '..');
const CLAWHUB_DIR = path.join(WORKSPACE_DIR, "skills");
const GIT_DIR = path.join(WORKSPACE_DIR, "git/skills");
const BACKUP_DIR = path.join(WORKSPACE_DIR, "backups/sync");
const LOG_FILE = path.join(WORKSPACE_DIR, "logs/sync-agent.log");

// Erstelle Verzeichnisse
function ensureDir(dirPath) {
    if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
    }
}

ensureDir(GIT_DIR);
ensureDir(BACKUP_DIR);
ensureDir(path.dirname(LOG_FILE));

// Logging
function log(message, level = "INFO") {
    const timestamp = new Date().toISOString().slice(0, 19).replace('T', ' ');
    const entry = `[${timestamp}] [${level}] ${message}`;
    console.log(entry);
    fs.appendFileSync(LOG_FILE, entry + '\n');
}

// Validierung
function validateSkill(skillDir) {
    /** Prüft Skill-Struktur - SKILL.md required, scripts/ optional */
    const skillMdPath = path.join(skillDir, "SKILL.md");
    if (!fs.existsSync(skillMdPath)) {
        log(`Validation failed: ${path.basename(skillDir)} missing SKILL.md`, "ERROR");
        return false;
    }
    return true;
}

// Backup
function createBackup(source, skillName) {
    /** Erstellt Backup eines Skills */
    const timestamp = new Date().toISOString().slice(0, 19).replace(/[-:]/g, '').replace('T', '_');
    const backupPath = path.join(BACKUP_DIR, `${skillName}_${timestamp}`);
    
    // Backup verzeichnis löschen falls es existiert
    if (fs.existsSync(backupPath)) {
        try {
            fs.rmSync(backupPath, { recursive: true, force: true });
            log(`Removed existing backup: ${backupPath}`);
        } catch (e) {
            log(`Failed to remove existing backup ${backupPath}: ${e.message}`, "ERROR");
            return false;
        }
    }
    
    try {
        copyRecursiveSync(source, backupPath);
        log(`Backup created: ${backupPath}`);
        return true;
    } catch (e) {
        log(`Backup failed: ${e.message}`, "ERROR");
        return false;
    }
}

// Hilfsfunktion zum rekursiven Kopieren
function copyRecursiveSync(src, dest) {
    const exists = fs.existsSync(src);
    const stats = exists && fs.statSync(src);
    const isDirectory = exists && stats.isDirectory();
    
    if (isDirectory) {
        if (!fs.existsSync(dest)) {
            fs.mkdirSync(dest);
        }
        fs.readdirSync(src).forEach(childItemName => {
            if (childItemName !== '.git') {
                copyRecursiveSync(
                    path.join(src, childItemName),
                    path.join(dest, childItemName)
                );
            }
        });
    } else {
        fs.copyFileSync(src, dest);
    }
}

// Hash-Vergleich
function getFileHash(filePath) {
    /** SHA256-Hash einer Datei */
    const fileBuffer = fs.readFileSync(filePath);
    const hashSum = crypto.createHash('sha256');
    hashSum.update(fileBuffer);
    return hashSum.digest('hex');
}

// Sync Richtung ClawHub → Git
function syncToGit(skillName, dryRun = true) {
    /** Synchronisiert ClawHub Skill zu Git */
    const source = path.join(CLAWHUB_DIR, skillName);
    const target = path.join(GIT_DIR, skillName);
    
    if (!validateSkill(source)) {
        return false;
    }
    
    // Backup vor Änderungen (nur wenn target existiert)
    if (!dryRun && fs.existsSync(target)) {
        createBackup(target, skillName);
    }
    
    // Änderungen erkennen
    const changes = [];
    
    function walkDir(currentPath, relativeBase) {
        const items = fs.readdirSync(currentPath);
        items.forEach(item => {
            if (item === '.git') return;
            
            const fullPath = path.join(currentPath, item);
            const stat = fs.statSync(fullPath);
            const relPath = path.relative(source, fullPath);
            
            if (stat.isDirectory()) {
                walkDir(fullPath, relativeBase);
            } else {
                const tgtFile = path.join(target, relPath);
                
                // Vergleich
                if (!fs.existsSync(tgtFile)) {
                    changes.push(`ADD ${relPath}`);
                } else if (getFileHash(fullPath) !== getFileHash(tgtFile)) {
                    changes.push(`UPDATE ${relPath}`);
                }
            }
        });
    }
    
    if (fs.existsSync(source)) {
        walkDir(source, source);
    }
    
    // Dry-Run Report
    if (dryRun) {
        log(`DRY-RUN: ${skillName} - ${changes.length} changes`);
        changes.forEach(change => log(`  ${change}`));
        return true;
    }
    
    // Echte Synchronisation
    log(`SYNC: ${skillName} - Applying ${changes.length} changes`);
    if (fs.existsSync(target)) {
        fs.rmSync(target, { recursive: true, force: true });
    }
    copyRecursiveSync(source, target);
    log(`SYNC: ${skillName} - Complete`);
    return true;
}

// Sync Richtung Git → ClawHub
function syncToClawhub(skillName, dryRun = true) {
    /** Synchronisiert Git Skill zu ClawHub */
    const source = path.join(GIT_DIR, skillName);
    const target = path.join(CLAWHUB_DIR, skillName);
    
    if (!validateSkill(source)) {
        return false;
    }
    
    // Backup vor Änderungen (nur wenn target existiert)
    if (!dryRun && fs.existsSync(target)) {
        createBackup(target, skillName);
    }
    
    // Änderungen erkennen
    const changes = [];
    
    function walkDir(currentPath, relativeBase) {
        const items = fs.readdirSync(currentPath);
        items.forEach(item => {
            if (item === '.git') return;
            
            const fullPath = path.join(currentPath, item);
            const stat = fs.statSync(fullPath);
            const relPath = path.relative(source, fullPath);
            
            if (stat.isDirectory()) {
                walkDir(fullPath, relativeBase);
            } else {
                const tgtFile = path.join(target, relPath);
                
                // Vergleich
                if (!fs.existsSync(tgtFile)) {
                    changes.push(`ADD ${relPath}`);
                } else if (getFileHash(fullPath) !== getFileHash(tgtFile)) {
                    changes.push(`UPDATE ${relPath}`);
                }
            }
        });
    }
    
    if (fs.existsSync(source)) {
        walkDir(source, source);
    }
    
    // Dry-Run Report
    if (dryRun) {
        log(`DRY-RUN: ${skillName} - ${changes.length} changes`);
        changes.forEach(change => log(`  ${change}`));
        return true;
    }
    
    // Echte Synchronisation
    log(`SYNC: ${skillName} - Applying ${changes.length} changes`);
    if (fs.existsSync(target)) {
        fs.rmSync(target, { recursive: true, force: true });
    }
    copyRecursiveSync(source, target);
    log(`SYNC: ${skillName} - Complete`);
    return true;
}

// Argument Parsing (simple implementation)
function parseArgs() {
    const args = {};
    for (let i = 2; i < process.argv.length; i++) {
        const arg = process.argv[i];
        if (arg.startsWith('--')) {
            const key = arg.slice(2);
            if (key === 'dry-run' || key === 'force') {
                args[key.replace(/-/g, '')] = true;
            } else {
                args[key.replace(/-/g, '')] = process.argv[++i];
            }
        }
    }
    return args;
}

// Hauptfunktion
function main() {
    const args = parseArgs();
    
    if (!args.skill || !args.direction) {
        console.error('Missing required arguments: --skill and --direction');
        process.exit(1);
    }
    
    log(`Starting sync: ${args.skill} (${args.direction})`);
    
    let success;
    if (args.direction === 'to-git') {
        success = syncToGit(args.skill, args.dryrun);
    } else if (args.direction === 'to-clawhub') {
        success = syncToClawhub(args.skill, args.dryrun);
    } else {
        console.error('Invalid direction. Use --direction to-git or --direction to-clawhub');
        process.exit(1);
    }
    
    if (!success) {
        log("Sync failed", "ERROR");
        process.exit(1);
    }
    
    log("Sync completed");
}

main();
