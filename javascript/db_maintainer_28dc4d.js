#!/usr/bin/env node
// db_maintainer.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway2:skills/db-maintainer/scripts/db_maintainer.py
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

/**
 * Database Maintainer Sub-Agent
 * Automated database maintenance with 30min checks, hourly backups (3 days retention),
 * band tree command execution for important/openclaw-tree.txt
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { spawnSync } = require('child_process');

const WORKSPACE = '/home/openclaw/.openclaw/workspace';
const DB_DIR = path.join(WORKSPACE, 'db');
const BACKUP_DIR = path.join(DB_DIR, 'backups');
const LOG_DIR = path.join(WORKSPACE, 'logs', 'db-maintainer');
const IMPORTANT_DIR = path.join(WORKSPACE, 'important');

// Verzeichnisse erstellen
[BACKUP_DIR, LOG_DIR].forEach(dir => {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
});

class Logger {
    /** Einfacher Logger mit Datei-Ausgabe */
    
    constructor() {
        const today = new Date().toISOString().split('T')[0];
        this.logFile = path.join(LOG_DIR, `${today}.log`);
    }
    
    log(level, message) {
        const timestamp = new Date().toISOString().replace('T', ' ').substring(0, 19);
        const line = `[${timestamp}] [${level}] ${message}`;
        console.log(line);
        fs.appendFileSync(this.logFile, line + '\n');
    }
    
    info(msg) { this.log('INFO', msg); }
    warn(msg) { this.log('WARN', msg); }
    error(msg) { this.log('ERROR', msg); }
}

class DatabaseMaintainer {
    constructor() {
        this.logger = new Logger();
        this.stateFile = path.join(DB_DIR, 'maintainer_state.json');
        this.retentionDays = 3; // 3 Tage Backup-Aufbewahrung
    }
    
    loadState() {
        /** Lädt letzten Check-Zustand */
        if (fs.existsSync(this.stateFile)) {
            const data = fs.readFileSync(this.stateFile, 'utf8');
            return JSON.parse(data);
        }
        return { last_check: null, last_backup: null, last_tree_update: null, file_hashes: {} };
    }
    
    saveState(state) {
        /** Speichert aktuellen Zustand */
        fs.writeFileSync(this.stateFile, JSON.stringify(state, null, 2));
    }
    
    getFileHash(filepath) {
        /** Berechnet MD5-Hash einer Datei */
        try {
            const data = fs.readFileSync(filepath);
            return crypto.createHash('md5').update(data).digest('hex');
        } catch {
            return null;
        }
    }
    
    runTreeCommand() {
        /** Führt tree -a -L 6 auf workspace aus und gibt Ergebnis zurück */
        try {
            const result = spawnSync('tree', ['-a', '-L', '6', WORKSPACE], {
                encoding: 'utf8',
                timeout: 60000
            });
            
            if (result.status === 0) {
                this.logger.info("tree -a -L 6 erfolgreich ausgeführt");
                return result.stdout;
            } else {
                this.logger.error(`tree command fehlgeschlagen: ${result.stderr}`);
                return null;
            }
        } catch (e) {
            this.logger.error(`tree command Exception: ${e.message}`);
            return null;
        }
    }
    
    updateTreeFile(treeOutput) {
        /** Schreibt tree-output in important/openclaw-tree.txt */
        if (!treeOutput) {
            return false;
        }
        
        const treeFile = path.join(IMPORTANT_DIR, 'openclaw-tree.txt');
        
        // Header mit Timestamp
        const header = `# OpenClaw Workspace Tree
# Generiert: ${new Date().toISOString()}
# Befehl: tree -a -L 6 ${WORKSPACE}
# Diese Datei wird automatisch von db-maintainer aktualisiert

`;
        
        try {
            fs.writeFileSync(treeFile, header + treeOutput);
            this.logger.info(`openclaw-tree.txt aktualisiert: ${treeFile}`);
            return true;
        } catch (e) {
            this.logger.error(`Fehler beim Schreiben von openclaw-tree.txt: ${e.message}`);
            return false;
        }
    }
    
    scanDocumentations() {
        /** Scannt alle .md Dateien auf Änderungen */
        const docs = [];
        const walkDir = (dir) => {
            const entries = fs.readdirSync(dir, { withFileTypes: true });
            for (const entry of entries) {
                const fullPath = path.join(dir, entry.name);
                const relativePath = path.relative(WORKSPACE, fullPath);
                
                // Skip backup and node_modules directories
                if (relativePath.includes('db/backups') || relativePath.includes('node_modules')) {
                    continue;
                }
                
                if (entry.isFile() && entry.name.endsWith('.md')) {
                    const stat = fs.statSync(fullPath);
                    docs.push({
                        path: relativePath,
                        hash: this.getFileHash(fullPath),
                        mtime: stat.mtimeMs
                    });
                } else if (entry.isDirectory()) {
                    walkDir(fullPath);
                }
            }
        };
        
        walkDir(WORKSPACE);
        return docs;
    }
    
    checkForChanges() {
        /** Prüft auf Änderungen seit letztem Lauf */
        const state = this.loadState();
        const currentDocs = this.scanDocumentations();
        
        const changes = [];
        const currentHashes = {};
        
        for (const doc of currentDocs) {
            const docPath = doc.path;
            currentHashes[docPath] = doc.hash;
            
            if (!(docPath in state.file_hashes)) {
                changes.push(`NEW: ${docPath}`);
            } else if (state.file_hashes[docPath] !== doc.hash) {
                changes.push(`CHANGED: ${docPath}`);
            }
        }
        
        // Prüfe auf gelöschte Dateien
        for (const oldPath in state.file_hashes) {
            if (!(oldPath in currentHashes)) {
                changes.push(`DELETED: ${oldPath}`);
            }
        }
        
        return changes, currentHashes;
    }
    
    updateDatabases() {
        /** Führt DB-Update-Scripts aus */
        try {
            const scriptPath = path.join(WORKSPACE, 'scripts', 'update_docs_db.py');
            const result = spawnSync('python3', [scriptPath], {
                encoding: 'utf8',
                timeout: 60000
            });
            
            if (result.status === 0) {
                this.logger.info("docs.db aktualisiert");
                return true;
            } else {
                this.logger.error(`DB-Update fehlgeschlagen: ${result.stderr}`);
                return false;
            }
        } catch (e) {
            this.logger.error(`DB-Update Exception: ${e.message}`);
            return false;
        }
    }
    
    updateTreeDbV2() {
        /** Führt tree_indexer_v2.py aus */
        try {
            const scriptPath = path.join(WORKSPACE, 'scripts', 'tree_indexer_v2.py');
            const result = spawnSync('python3', [scriptPath], {
                encoding: 'utf8',
                timeout: 120000
            });
            
            if (result.status === 0) {
                this.logger.info("tree.db v2 aktualisiert");
                return true;
            } else {
                this.logger.error(`Tree-DB v2 fehlgeschlagen: ${result.stderr}`);
                return false;
            }
        } catch (e) {
            this.logger.error(`Tree-DB v2 Exception: ${e.message}`);
            return false;
        }
    }
    
    createBackup() {
        /** Erstellt Backup beider Datenbanken */
        const timestamp = new Date().toISOString().replace(/[:T]/g, '-').substring(0, 16);
        
        ['docs.db', 'tree.db'].forEach(dbName => {
            const source = path.join(DB_DIR, dbName);
            if (fs.existsSync(source)) {
                const backupName = `${timestamp}_${dbName}.bak`;
                const backupPath = path.join(BACKUP_DIR, backupName);
                fs.copyFileSync(source, backupPath);
                this.logger.info(`Backup erstellt: ${backupName}`);
            }
        });
        
        return timestamp;
    }
    
    cleanupOldBackups() {
        /** Löscht Backups älter als 3 Tage */
        const cutoff = new Date(Date.now() - this.retentionDays * 24 * 60 * 60 * 1000);
        let deleted = 0;
        
        ['docs.db', 'tree.db'].forEach(dbName => {
            const backups = fs.readdirSync(BACKUP_DIR)
                .filter(file => file.endsWith(`_${dbName}.bak`))
                .map(file => path.join(BACKUP_DIR, file));
            
            backups.forEach(backup => {
                try {
                    const filename = path.basename(backup);
                    const dateStr = filename.split('_')[0];
                    const timeStr = filename.split('_')[1];
                    const backupTime = new Date(`${dateStr}T${timeStr.replace('-', ':')}`);
                    
                    if (backupTime < cutoff) {
                        fs.unlinkSync(backup);
                        deleted++;
                        this.logger.info(`Altes Backup gelöscht: ${filename}`);
                    }
                } catch {
                    this.logger.warn(`Konnte Backup-Datum nicht parsen: ${path.basename(backup)}`);
                }
            });
        });
        
        if (deleted === 0) {
            this.logger.info("Keine alten Backups zum Löschen");
        } else {
            this.logger.info(`${deleted} alte Backups gelöscht (< 3 Tage)`);
        }
    }
    
    runCycle() {
        /** Ein kompletter Wartungszyklus */
        this.logger.info("=".repeat(60));
        this.logger.info("DB MAINTAINER CYCLE START");
        this.logger.info("=".repeat(60));
        
        const state = this.loadState();
        
        // 1. Tree-Befehl ausführen und in openclaw-tree.txt schreiben
        this.logger.info("Führe tree -a -L 8 aus...");
        const treeOutput = this.runTreeCommand();
        if (treeOutput) {
            this.updateTreeFile(treeOutput);
            state.last_tree_update = new Date().toISOString();
        }
        
        // 2. tree.db aktualisieren (intern v2)
        this.logger.info("Aktualisiere tree.db v2...");
        this.updateTreeDbV2();
        
        // 3. Änderungen prüfen
        this.logger.info("Prüfe auf Dokumentations-Änderungen...");
        const [changes, currentHashes] = this.checkForChanges();
        
        if (changes.length > 0) {
            this.logger.info(`${changes.length} Änderungen gefunden:`);
            changes.slice(0, 10).forEach(change => {
                this.logger.info(`  - ${change}`);
            });
            if (changes.length > 10) {
                this.logger.info(`  ... und ${changes.length - 10} weitere`);
            }
            
            // 4. docs.db aktualisieren
            this.logger.info("Aktualisiere docs.db...");
            if (this.updateDatabases()) {
                state.last_check = new Date().toISOString();
                state.file_hashes = currentHashes;
            }
        } else {
            this.logger.info("Keine Dokumentations-Änderungen gefunden");
        }
        
        // 5. Prüfe ob Backup fällig (stündlich)
        const lastBackup = state.last_backup;
        let doBackup = false;
        
        if (lastBackup) {
            const lastBackupTime = new Date(lastBackup);
            doBackup = (Date.now() - lastBackupTime.getTime()) >= 60 * 60 * 1000; // 1 hour
        } else {
            doBackup = true;
        }
        
        if (doBackup) {
            this.logger.info("Erstelle stündliches Backup...");
            const timestamp = this.createBackup();
            state.last_backup = new Date().toISOString();
            
            // 6. Alte Backups aufräumen (3 Tage Retention)
            this.logger.info("Räume alte Backups auf (3 Tage Retention)...");
            this.cleanupOldBackups();
        } else {
            this.logger.info("Backup nicht nötig (letztes < 1h)");
        }
        
        this.saveState(state);
        
        this.logger.info("=".repeat(60));
        this.logger.info("DB MAINTAINER CYCLE END");
        this.logger.info("=".repeat(60));
    }
}

function main() {
    /** Hauptfunktion */
    const maintainer = new DatabaseMaintainer();
    
    try {
        maintainer.runCycle();
    } catch (e) {
        maintainer.logger.error(`CRITICAL ERROR: ${e.message}`);
        process.exit(1);
    }
}

main();
