#!/usr/bin/env node
// sync_clawhub_git.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway2:scripts/sync_clawhub_git.py
// auch in: Projects@clawhub:clawhub/Skills/sync_clawhub_git.py
// Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

/**
 * Bidirektionale ClawHub ↔ Git Synchronisation
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');

// Konfiguration
// Resolve paths relative to this repository so the helper works both in the
// hosted workspace and in environments without a /workspace mount.
const __dirnameResolved = path.resolve(__dirname);
const WORKSPACE_ROOT = path.resolve(__dirnameResolved, '..');
const CLAWHUB_DIR = path.join(WORKSPACE_ROOT, "skills");
const GIT_DIR = path.join(WORKSPACE_ROOT, "git", "skills");
const BACKUP_DIR = path.join(WORKSPACE_ROOT, "backups", "sync");
const LOG_FILE = path.join(WORKSPACE_ROOT, "logs", "sync-agent.log");
const IGNORED_NAMES = new Set([".git", ".clawhub", "node_modules", "__pycache__", ".pytest_cache"]);
const RESERVED_SKILL_NAMES = new Set(["github-clones", "skills", "backups", ".restore", "git", "Abstraktionen"]);
const PRESERVED_TARGET_NAMES = IGNORED_NAMES;

// Erstelle Verzeichnisse
function ensureDirExists(dirPath) {
    if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
    }
}
ensureDirExists(GIT_DIR);
ensureDirExists(BACKUP_DIR);
ensureDirExists(path.dirname(LOG_FILE));

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
    const skillName = path.basename(skillDir);
    if (RESERVED_SKILL_NAMES.has(skillName)) {
        log(`Validation failed: ${skillName} is reserved and must not be synced as a skill`, "ERROR");
        return false;
    }
    const skillMdPath = path.join(skillDir, "SKILL.md");
    if (!fs.existsSync(skillMdPath)) {
        log(`Validation failed: ${skillName} missing SKILL.md`, "ERROR");
        return false;
    }
    return true;
}

function isIgnoredPath(filePath) {
    const parts = filePath.split(path.sep);
    return parts.some(part => IGNORED_NAMES.has(part) || part.endsWith(".pyc"));
}

function isGeneratedDuplicatePath(root, relPath) {
    /** Detect generated duplicate folders such as <skill>/<skill> or scripts/scripts. */
    const parts = relPath.split(path.sep).filter(p => p !== '');
    if (parts.length === 0) return false;
    const rootName = path.basename(root);
    if (parts[0] === rootName) return true;
    for (let i = 1; i < parts.length; i++) {
        if (parts[i] === parts[i - 1]) return true;
    }
    return false;
}

function* iterSyncFiles(root) {
    /** Yield files that should participate in sync comparisons. */
    const walk = function* (currentRoot, relRootParts) {
        const entries = fs.readdirSync(currentRoot, { withFileTypes: true });
        for (const entry of entries) {
            const fullPath = path.join(currentRoot, entry.name);
            const relPathParts = [...relRootParts, entry.name];
            const relPath = path.join(...relPathParts);

            if (entry.isDirectory()) {
                if (IGNORED_NAMES.has(entry.name) || entry.name.startsWith("__pycache__")) {
                    continue;
                }
                if (isGeneratedDuplicatePath(root, relPath)) {
                    continue;
                }
                if (isIgnoredPath(relPath)) {
                    continue;
                }
                yield* walk(fullPath, relPathParts);
            } else {
                if (IGNORED_NAMES.has(entry.name) || entry.name.endsWith(".pyc")) {
                    continue;
                }
                if (isIgnoredPath(relPath)) {
                    continue;
                }
                if (isGeneratedDuplicatePath(root, relPath)) {
                    continue;
                }
                if (entry.name === "SKILL.md" && relPath !== "SKILL.md") {
                    continue;
                }
                if (!entry.isFile()) {
                    continue;
                }
                yield [fullPath, relPath];
            }
        }
    };
    yield* walk(root, []);
}

function resetSyncTarget(target) {
    /** Remove stale synced content before copying, preserving local-only metadata. */
    ensureDirExists(target);
    const entries = fs.readdirSync(target, { withFileTypes: true });
    for (const entry of entries) {
        if (PRESERVED_TARGET_NAMES.has(entry.name)) {
            continue;
        }
        const fullPath = path.join(target, entry.name);
        if (entry.isDirectory() && !entry.isSymbolicLink()) {
            fs.rmSync(fullPath, { recursive: true });
        } else {
            fs.unlinkSync(fullPath);
        }
    }
}

function copySyncFiles(source, target) {
    resetSyncTarget(target);
    for (const [srcFile, relPath] of iterSyncFiles(source)) {
        const destFile = path.join(target, relPath);
        const destDir = path.dirname(destFile);
        ensureDirExists(destDir);
        fs.copyFileSync(srcFile, destFile);
    }
}

// Backup
function createBackup(source, skillName) {
    /** Erstellt Backup eines Skills */
    const timestamp = new Date().toISOString().slice(0, 19).replace(/[:]/g, '').replace('T', '_');
    const backupPath = path.join(BACKUP_DIR, `${skillName}_${timestamp}`);

    // Backup verzeichnis löschen falls es existiert
    if (fs.existsSync(backupPath)) {
        try {
            fs.rmSync(backupPath, { recursive: true });
            log(`Removed existing backup: ${backupPath}`);
        } catch (e) {
            log(`Failed to remove existing backup ${backupPath}: ${e.message}`, "ERROR");
            return false;
        }
    }

    try {
        fs.cpSync(source, backupPath, { recursive: true });
        log(`Backup created: ${backupPath}`);
        return true;
    } catch (e) {
        log(`Backup failed: ${e.message}`, "ERROR");
        return false;
    }
}

// Hash-Vergleich
function getFileHash(filePath) {
    /** SHA256-Hash einer Datei */
    // Ensure the path points to a regular file.
    try {
        const stat = fs.statSync(filePath);
        if (!stat.isFile()) {
            return "";
        }
        const hasher = crypto.createHash('sha256');
        const stream = fs.createReadStream(filePath);
        return new Promise((resolve, reject) => {
            stream.on('data', (chunk) => hasher.update(chunk));
            stream.on('end', () => resolve(hasher.digest('hex')));
            stream.on('error', reject);
        });
    } catch (e) {
        log(`Failed to hash ${filePath}: ${e.message}`, "ERROR");
        return "";
    }
}

async function getFileHashAsync(filePath) {
    try {
        return await getFileHash(filePath);
    } catch (e) {
        log(`Failed to hash ${filePath}: ${e.message}`, "ERROR");
        return "";
    }
}

// Sync Richtung ClawHub → Git
async function syncToGit(skillName, dryRun = true) {
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
    for (const [srcFile, relPath] of iterSyncFiles(source)) {
        const tgtFile = path.join(target, relPath);
        if (!fs.existsSync(tgtFile)) {
            changes.push(`ADD ${relPath}`);
        } else {
            const srcHash = await getFileHashAsync(srcFile);
            const tgtHash = await getFileHashAsync(tgtFile);
            if (srcHash !== tgtHash) {
                changes.push(`UPDATE ${relPath}`);
            }
        }
    }

    // Dry-Run Report
    if (dryRun) {
        log(`DRY-RUN: ${skillName} - ${changes.length} changes`);
        for (const change of changes) {
            log(`  ${change}`);
        }
        return true;
    }

    // Echte Synchronisation
    log(`SYNC: ${skillName} - Applying ${changes.length} changes`);
    copySyncFiles(source, target);
    log(`SYNC: ${skillName} - Complete`);
    return true;
}

// Sync Richtung Git → ClawHub
async function syncToClawhub(skillName, dryRun = true) {
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

    // Änderungen erkennen (gleiche Logik wie oben)
    const changes = [];
    for (const [srcFile, relPath] of iterSyncFiles(source)) {
        const tgtFile = path.join(target, relPath);
        if (!fs.existsSync(tgtFile)) {
            changes.push(`ADD ${relPath}`);
        } else {
            const srcHash = await getFileHashAsync(srcFile);
            const tgtHash = await getFileHashAsync(tgtFile);
            if (srcHash !== tgtHash) {
                changes.push(`UPDATE ${relPath}`);
            }
        }
    }

    // Dry-Run Report
    if (dryRun) {
        log(`DRY-RUN: ${skillName} - ${changes.length} changes`);
        for (const change of changes) {
            log(`  ${change}`);
        }
        return true;
    }

    // Echte Synchronisation
    log(`SYNC: ${skillName} - Applying ${changes.length} changes`);
    copySyncFiles(source, target);
    log(`SYNC: ${skillName} - Complete`);
    return true;
}

// Hauptfunktion
async function main() {
    const args = process.argv.slice(2);
    let skillName, direction, dryRun = false, force = false;

    for (let i = 0; i < args.length; i++) {
        switch (args[i]) {
            case '--skill':
                skillName = args[++i];
                break;
            case '--direction':
                direction = args[++i];
                break;
            case '--dry-run':
                dryRun = true;
                break;
            case '--force':
                force = true;
                break;
        }
    }

    if (!skillName || !direction) {
        console.error("Missing required arguments: --skill and --direction");
        process.exit(1);
    }

    if (direction !== 'to-git' && direction !== 'to-clawhub') {
        console.error("Invalid direction. Use 'to-git' or 'to-clawhub'");
        process.exit(1);
    }

    log(`Starting sync: ${skillName} (${direction})`);

    let success;
    if (direction === 'to-git') {
        success = await syncToGit(skillName, dryRun);
    } else {
        success = await syncToClawhub(skillName, dryRun);
    }

    if (!success) {
        log("Sync failed", "ERROR");
        process.exit(1);
    }

    log("Sync completed");
}

main().catch(err => {
    console.error(err);
    process.exit(1);
});
