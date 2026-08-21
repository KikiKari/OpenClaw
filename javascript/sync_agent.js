#!/usr/bin/env node
// sync_agent.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/clawhub-git-sync-agent/scripts/sync_agent.py
// Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

/**
 * Permanenter ClawHub ↔ Git Sync Agent
 * Multi-Node fähig, stündliche Ausführung
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { createReadStream, createWriteStream } = require('fs');
const { createGzip } = require('zlib');
const { pipeline } = require('stream/promises');
const tar = require('tar-stream');

// Import sync functions
const syncModulePath = '/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.js';
const { syncToGit, syncToClawhub, log, validateSkill, getFileHash } = require(syncModulePath);

const CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills";
const GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills";
const STATE_FILE = "/home/openclaw/.openclaw/workspace/db/sync_state.json";

// Root directory for backups
const BACKUP_ROOT = "/home/openclaw/.openclaw/workspace/backups/sync_agent";

function loadState() {
    /** Lädt den Sync-State */
    if (fs.existsSync(STATE_FILE)) {
        const data = fs.readFileSync(STATE_FILE, 'utf8');
        return JSON.parse(data);
    }
    return { sync_history: [], pending: [] };
}

function saveState(state) {
    /** Speichert den Sync-State */
    const dir = path.dirname(STATE_FILE);
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
    fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

function getAllSkills() {
    /** Findet nur valide Skill-Verzeichnisse in beiden Verzeichnissen. */
    const clawhubSkills = new Set();
    if (fs.existsSync(CLAWHUB_DIR)) {
        for (const item of fs.readdirSync(CLAWHUB_DIR)) {
            const fullPath = path.join(CLAWHUB_DIR, item);
            const stat = fs.statSync(fullPath);
            if (stat.isDirectory() && !item.startsWith('.') && !item.startsWith('_')) {
                if (fs.existsSync(path.join(fullPath, "SKILL.md"))) {
                    clawhubSkills.add(item);
                }
            }
        }
    }

    const gitSkills = new Set();
    if (fs.existsSync(GIT_DIR)) {
        for (const item of fs.readdirSync(GIT_DIR)) {
            const fullPath = path.join(GIT_DIR, item);
            const stat = fs.statSync(fullPath);
            if (stat.isDirectory() && !item.startsWith('.') && !item.startsWith('_')) {
                if (fs.existsSync(path.join(fullPath, "SKILL.md"))) {
                    gitSkills.add(item);
                }
            }
        }
    }

    return new Set([...clawhubSkills, ...gitSkills]);
}

function initGitRepo(skillPath, skillName) {
    /** Initialisiert Git-Repo wenn nötig */
    const gitDir = path.join(skillPath, ".git");
    if (!fs.existsSync(gitDir)) {
        process.chdir(skillPath);
        execSync("git init", { stdio: 'ignore' });
        execSync("git add .", { stdio: 'ignore' });
        execSync(`git commit -m "Initial commit: ${skillName} skill"`, { stdio: 'ignore' });
        log(`Git initialized for ${skillName}`);
    }
}

async function backupSkillDir(skillPath, skillName) {
    /** Creates a timestamped tar.gz backup of a skill directory. */
    if (!fs.existsSync(skillPath)) {
        return;
    }
    const timestamp = new Date().toISOString().replace(/[:.]/g, '').replace('T', '').substring(0, 12);
    const backupDir = path.join(BACKUP_ROOT, timestamp);
    if (!fs.existsSync(backupDir)) {
        fs.mkdirSync(backupDir, { recursive: true });
    }
    const archiveName = `${skillName}_${timestamp}.tar.gz`;
    const archivePath = path.join(backupDir, archiveName);
    
    // Create tar.gz manually since we don't have shutil equivalent
    const pack = tar.pack();
    const gzip = createGzip();
    const output = createWriteStream(archivePath);
    
    // Walk through directory and add files to tar
    function walkDirectory(currentPath, basePath) {
        const items = fs.readdirSync(currentPath);
        for (const item of items) {
            const fullPath = path.join(currentPath, item);
            const relativePath = path.relative(basePath, fullPath);
            const stat = fs.statSync(fullPath);
            
            if (stat.isDirectory()) {
                // Add directory entry
                pack.entry({ name: relativePath + '/' }, null, () => {});
                walkDirectory(fullPath, basePath);
            } else {
                // Add file entry
                const entry = pack.entry({ name: relativePath }, null);
                const fileStream = createReadStream(fullPath);
                fileStream.pipe(entry);
            }
        }
    }
    
    walkDirectory(skillPath, skillPath);
    pack.finalize();
    
    await pipeline(pack, gzip, output);
    log(`Backup created for ${skillName} at ${archivePath}`);
}

async function syncSkillBidirectional(skillName, dryRun = false) {
    /** Bidirektionale Synchronisation eines Skills */
    const clawhubPath = path.join(CLAWHUB_DIR, skillName);
    const gitPath = path.join(GIT_DIR, skillName);

    // Fall 1: Nur in ClawHub → zu Git
    if (fs.existsSync(clawhubPath) && !fs.existsSync(gitPath)) {
        log(`NEW in ClawHub: ${skillName} → syncing to Git`);
        if (!dryRun) {
            await backupSkillDir(clawhubPath, `${skillName}_clawhub`);
        }
        if (syncToGit(skillName, dryRun)) {
            if (!dryRun) {
                initGitRepo(gitPath, skillName);
            }
            return "synced_to_git";
        }
    }

    // Fall 2: Nur in Git → zu ClawHub
    else if (fs.existsSync(gitPath) && !fs.existsSync(clawhubPath)) {
        log(`NEW in Git: ${skillName} → syncing to ClawHub`);
        if (!dryRun) {
            await backupSkillDir(gitPath, `${skillName}_git`);
        }
        if (syncToClawhub(skillName, dryRun)) {
            return "synced_to_clawhub";
        }
    }

    // Fall 3: In beiden vorhanden → Vergleiche Timestamps
    else if (fs.existsSync(clawhubPath) && fs.existsSync(gitPath)) {
        // --- MODIFIZIERTE LOGIK: Robusterer Datei-Hash-Vergleich ---

        // Stelle sicher, dass beide als gültige Skills validiert werden
        if (!validateSkill(clawhubPath)) {
            log(`Validation failed for ClawHub skill: ${skillName}`, "ERROR");
            return "error";
        }
        if (!validateSkill(gitPath)) {
            log(`Validation failed for Git skill: ${skillName}`, "ERROR");
            return "error";
        }

        // Berechne Hashes für clawhub und git
        const clawhubHashes = getHashes(clawhubPath);
        const gitHashes = getHashes(gitPath);

        if (JSON.stringify(clawhubHashes) !== JSON.stringify(gitHashes)) {
            log(`Content difference detected for: ${skillName}`);

            // Einfache (aber oft ausreichende) Logik: Wenn clawhub neuer ist, lade hoch.
            // Eine detailliertere Strategie (z.B. welche Version von Git übernehmen)
            // könnte hier implementiert werden, falls nötig.
            // Für jetzt: Wenn sie sich unterscheiden, priorisieren wir ClawHub > Git
            // und aktualisieren Git.

            const clawhubStat = fs.statSync(clawhubPath);
            const gitStat = fs.statSync(gitPath);
            const direction = clawhubStat.mtimeMs >= gitStat.mtimeMs ? "to-git" : "to-clawhub";
            log(`UPDATE: ${skillName} → syncing ${direction}`);
            if (!dryRun) {
                await backupSkillDir(clawhubPath, `${skillName}_clawhub`);
                await backupSkillDir(gitPath, `${skillName}_git`);
            }
            const sync = direction === "to-git" ? syncToGit : syncToClawhub;
            if (sync(skillName, dryRun)) {
                if (!dryRun && direction === "to-git") {
                    process.chdir(gitPath);
                    execSync("git add .", { stdio: 'ignore' });
                    execSync(`git commit -m "Sync from ClawHub content diff: ${new Date().toISOString().slice(0, 16).replace('T', ' ')}"`, { stdio: 'ignore' });
                }
                return direction === "to-git" ? "updated_git" : "updated_clawhub";
            } else {
                log(`Failed to sync ${skillName} to Git after content diff`, "ERROR");
                return "error";
            }
        } else {
            log(`Content is identical for: ${skillName}`);
            return "no_change";
        }
    }

    return "no_change";
}

// --- Hinzufügen dieser Hilfsfunktion ---
function getHashes(skillDir) {
    /** Erzeugt ein Dictionary von Datei-Hashes für einen Skill-Ordner. */
    const hashes = {};
    
    function walk(currentPath) {
        const items = fs.readdirSync(currentPath);
        for (const item of items) {
            const fullPath = path.join(currentPath, item);
            const stat = fs.statSync(fullPath);
            
            if (stat.isDirectory()) {
                // Skip .git directories
                if (item !== '.git') {
                    walk(fullPath);
                }
            } else {
                // Skip .git files
                if (!fullPath.includes('.git')) {
                    const relativePath = path.relative(skillDir, fullPath);
                    hashes[relativePath] = getFileHash(fullPath);
                }
            }
        }
    }
    
    walk(skillDir);
    return hashes;
}

async function main() {
    /** Hauptfunktion des Sync-Agents */
    const args = process.argv.slice(2);
    const DRY_RUN = args.includes('--dry-run');
    log("=== ClawHub ↔ Git Sync Agent gestartet ===");

    const state = loadState();
    const allSkills = getAllSkills();
    log(`Gefundene Skills: ${allSkills.size}`);

    const results = {
        synced_to_git: [],
        synced_to_clawhub: [],
        updated_git: [],
        updated_clawhub: [],
        no_change: [],
        errors: []
    };

    for (const skill of Array.from(allSkills).sort()) {
        try {
            const result = await syncSkillBidirectional(skill, DRY_RUN);
            results[result].push(skill);
        } catch (e) {
            log(`ERROR syncing ${skill}: ${e.message}`, "ERROR");
            results.errors.push(skill);
        }
    }

    // Zusammenfassung
    log("\n=== SYNC ZUSAMMENFASSUNG ===");
    log(`Neu in Git: ${results.synced_to_git.length} - ${results.synced_to_git}`);
    log(`Neu in ClawHub: ${results.synced_to_clawhub.length} - ${results.synced_to_clawhub}`);
    log(`Git aktualisiert: ${results.updated_git.length} - ${results.updated_git}`);
    log(`ClawHub aktualisiert: ${results.updated_clawhub.length} - ${results.updated_clawhub}`);
    log(`Keine Änderung: ${results.no_change.length}`);
    log(`Fehler: ${results.errors.length} - ${results.errors}`);

    // Ein Dry-Run bleibt vollständig nicht-mutierend (abgesehen vom Audit-Log).
    if (!DRY_RUN) {
        if (!state.sync_history) {
            state.sync_history = [];
        }
        state.sync_history.push({
            timestamp: new Date().toISOString(),
            results: results
        });
        // Nur letzte 100 Einträge behalten
        state.sync_history = state.sync_history.slice(-100);
        saveState(state);
    }

    log("=== Sync Agent beendet ===\n");
}

if (require.main === module) {
    main().catch(err => {
        console.error(err);
        process.exit(1);
    });
}
