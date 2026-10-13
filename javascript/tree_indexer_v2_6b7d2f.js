#!/usr/bin/env node
// tree_indexer_v2.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway2:scripts/tree_indexer_v2.py
// Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

/**
 * Tree Indexer v2 - Erweitertes Tracking mit Metadaten
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { spawnSync } = require('child_process');

const WORKSPACE = '/workspace';
const DB_DIR = WORKSPACE;

class TreeIndexerV2 {
    constructor() {
        this.dbPath = path.join(WORKSPACE, "db", "tree.db");
        this.sqlite3 = null;
        this.db = null;
    }

    async connect() {
        if (!this.sqlite3) {
            this.sqlite3 = require('sqlite3').verbose();
        }
        if (!this.db) {
            // Stelle sicher, dass das db-Verzeichnis existiert
            const dbDir = path.dirname(this.dbPath);
            if (!fs.existsSync(dbDir)) {
                fs.mkdirSync(dbDir, { recursive: true });
            }
            
            this.db = new this.sqlite3.Database(this.dbPath);
        }
        return this.db;
    }

    async initSchemaV2() {
        /**Erstellt erweiterte Tabellenstruktur*/
        const db = await this.connect();
        
        return new Promise((resolve, reject) => {
            db.serialize(() => {
                // Haupttabelle mit erweiterten Metadaten
                db.run(`
                    CREATE TABLE IF NOT EXISTS tree_entries_v2 (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        file_id TEXT UNIQUE,              -- Eindeutige Datei-ID (Hash von Pfad)
                        root_path TEXT NOT NULL,
                        relative_path TEXT NOT NULL,
                        name TEXT NOT NULL,
                        type TEXT CHECK(type IN ('file', 'directory', 'symlink')),
                        depth INTEGER,
                        parent_path TEXT,
                        
                        -- Größen-Tracking
                        size_bytes INTEGER,               -- Aktuelle Größe
                        previous_size_bytes INTEGER,      -- Vorherige Größe (für Delta)
                        size_change_bytes INTEGER,        -- Änderung (positiv/negativ)
                        
                        -- Zeitstempel
                        mtime_timestamp REAL,             -- Letzte Änderung (Unix timestamp)
                        mtime_iso TEXT,                   -- ISO-Format für Lesbarkeit
                        first_seen_timestamp REAL,        -- Wann wurde Datei erste Mal gesehen
                        last_seen_timestamp REAL,         -- Wann wurde Datei zuletzt gesehen
                        
                        -- Änderungs-Tracking
                        change_type TEXT CHECK(change_type IN ('NEW', 'MODIFIED', 'MOVED', 'RENAMED', 'UNCHANGED', 'DELETED')),
                        
                        -- Historie
                        original_name TEXT,               -- Ursprünglicher Name wenn umbenannt
                        original_path TEXT,               -- Ursprünglicher Pfad wenn verschoben
                        previous_path TEXT,               -- Vorheriger Pfad
                        
                        -- Content-Hash (optionale Integritätsprüfung)
                        content_hash TEXT,                -- MD5 der Datei (nur für kleine Dateien)
                        
                        -- Metadaten
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                `, (err) => {
                    if (err) reject(err);
                });

                // Historie-Tabelle für alle Änderungen
                db.run(`
                    CREATE TABLE IF NOT EXISTS file_history (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        file_id TEXT NOT NULL,
                        timestamp REAL NOT NULL,
                        change_type TEXT NOT NULL,
                        old_path TEXT,
                        new_path TEXT,
                        old_size INTEGER,
                        new_size INTEGER,
                        FOREIGN KEY (file_id) REFERENCES tree_entries_v2(file_id)
                    )
                `, (err) => {
                    if (err) reject(err);
                });

                // Index für schnelle Suchen
                db.run('CREATE INDEX IF NOT EXISTS idx_file_id ON tree_entries_v2(file_id)', (err) => {
                    if (err) reject(err);
                });
                db.run('CREATE INDEX IF NOT EXISTS idx_path ON tree_entries_v2(relative_path)', (err) => {
                    if (err) reject(err);
                });
                db.run('CREATE INDEX IF NOT EXISTS idx_mtime ON tree_entries_v2(mtime_timestamp)', (err) => {
                    if (err) reject(err);
                });
                db.run('CREATE INDEX IF NOT EXISTS idx_change_type ON tree_entries_v2(change_type)', (err) => {
                    if (err) reject(err);
                });

                console.log("✅ tree.db Schema v2 erstellt/aktualisiert");
                resolve(this);
            });
        });
    }

    getFileMetadata(fullPath) {
        /**Extrahiert Metadaten einer Datei*/
        try {
            const stat = fs.statSync(fullPath);
            return {
                size: stat.size,
                mtime: stat.mtime.getTime() / 1000,
                mtime_iso: stat.mtime.toISOString()
            };
        } catch (error) {
            return { size: 0, mtime: 0, mtime_iso: null };
        }
    }

    generateFileId(relativePath) {
        /**Generiert eindeutige ID aus Pfad*/
        return crypto.createHash('md5').update(relativePath.toString()).digest('hex').substring(0, 16);
    }

    scanDirectoryDetailed(rootPath, maxDepth = 8) {
        /**Detailliertes Scanning mit Metadaten*/
        const entries = [];
        const root = path.resolve(rootPath);

        function walkDir(currentPath) {
            try {
                const items = fs.readdirSync(currentPath, { withFileTypes: true });
                
                for (const item of items) {
                    const fullPath = path.join(currentPath, item.name);
                    const relativePath = path.relative(root, fullPath);
                    
                    // Max depth prüfen
                    const depth = relativePath.split(path.sep).length;
                    if (depth > maxDepth) {
                        continue;
                    }
                    
                    const fileId = this.generateFileId(relativePath);
                    const metadata = this.getFileMetadata(fullPath);
                    
                    const entry = {
                        file_id: fileId,
                        root_path: rootPath,
                        relative_path: relativePath,
                        name: item.name,
                        type: item.isDirectory() ? 'directory' : (item.isSymbolicLink() ? 'symlink' : 'file'),
                        depth: depth,
                        parent_path: path.dirname(relativePath) !== '.' ? path.dirname(relativePath) : '',
                        size_bytes: metadata.size,
                        mtime_timestamp: metadata.mtime,
                        mtime_iso: metadata.mtime_iso
                    };
                    entries.push(entry);
                    
                    if (item.isDirectory()) {
                        walkDir.call(this, fullPath);
                    }
                }
            } catch (error) {
                console.error(`Fehler beim Lesen von ${currentPath}:`, error.message);
            }
        }

        walkDir.call(this, root);
        return entries;
    }

    async updateDatabase(entries) {
        /**Aktualisiert DB mit Änderungs-Erkennung*/
        const db = await this.connect();
        
        return new Promise((resolve, reject) => {
            db.serialize(() => {
                // Aktuelle Zeit
                const now = new Date();
                const nowTimestamp = now.getTime() / 1000;
                
                // Alle bestehenden Einträge als "potentiell gelöscht" markieren
                db.run("UPDATE tree_entries_v2 SET change_type = NULL", (err) => {
                    if (err) reject(err);
                });
                
                const stats = { new: 0, modified: 0, unchanged: 0, moved: 0 };
                
                let processed = 0;
                const totalEntries = entries.length;
                
                function processNext() {
                    if (processed >= totalEntries) {
                        // Markiere nicht aktualisierte Einträge als DELETED
                        db.all(`
                            SELECT * FROM tree_entries_v2 
                            WHERE change_type IS NULL OR last_seen_timestamp < ?
                        `, [nowTimestamp - 3600], (err, deleted) => {
                            if (err) reject(err);
                            
                            let deletedProcessed = 0;
                            if (deleted.length === 0) {
                                stats.deleted = 0;
                                resolve(stats);
                                return;
                            }
                            
                            stats.deleted = deleted.length;
                            
                            deleted.forEach((item) => {
                                db.run(`
                                    UPDATE tree_entries_v2 
                                    SET change_type = 'DELETED', updated_at = CURRENT_TIMESTAMP
                                    WHERE file_id = ?
                                `, [item.file_id], (err) => {
                                    if (err) reject(err);
                                    
                                    deletedProcessed++;
                                    if (deletedProcessed === deleted.length) {
                                        db.run('COMMIT', (err) => {
                                            if (err) reject(err);
                                            resolve(stats);
                                        });
                                    }
                                });
                            });
                        });
                        return;
                    }
                    
                    const entry = entries[processed];
                    processed++;
                    
                    db.get(
                        "SELECT * FROM tree_entries_v2 WHERE file_id = ?",
                        [entry.file_id],
                        (err, existing) => {
                            if (err) reject(err);
                            
                            if (existing) {
                                // Vergleiche Metadaten
                                const oldMtime = existing.mtime_timestamp || 0;
                                const oldSize = existing.size_bytes || 0;
                                const oldPath = existing.relative_path;
                                
                                // Größenänderung berechnen
                                const sizeChange = entry.size_bytes - oldSize;
                                
                                // Änderungstyp bestimmen
                                let changeType;
                                if (oldPath !== entry.relative_path) {
                                    changeType = 'MOVED';
                                    stats.moved += 1;
                                } else if (oldMtime !== entry.mtime_timestamp || oldSize !== entry.size_bytes) {
                                    changeType = 'MODIFIED';
                                    stats.modified += 1;
                                } else {
                                    changeType = 'UNCHANGED';
                                    stats.unchanged += 1;
                                }
                                
                                // Update
                                db.run(`
                                    UPDATE tree_entries_v2 SET
                                        size_bytes = ?,
                                        previous_size_bytes = ?,
                                        size_change_bytes = ?,
                                        mtime_timestamp = ?,
                                        mtime_iso = ?,
                                        last_seen_timestamp = ?,
                                        change_type = ?,
                                        previous_path = ?,
                                        original_path = COALESCE(original_path, ?),
                                        updated_at = CURRENT_TIMESTAMP
                                    WHERE file_id = ?
                                `, [
                                    entry.size_bytes,
                                    oldSize,
                                    sizeChange,
                                    entry.mtime_timestamp,
                                    entry.mtime_iso,
                                    nowTimestamp,
                                    changeType,
                                    changeType === 'MOVED' ? oldPath : null,
                                    changeType === 'MOVED' ? oldPath : null,
                                    entry.file_id
                                ], (err) => {
                                    if (err) reject(err);
                                    
                                    // Änderung in Historie loggen
                                    if (changeType === 'MODIFIED' || changeType === 'MOVED') {
                                        db.run(`
                                            INSERT INTO file_history
                                            (file_id, timestamp, change_type, old_path, new_path, old_size, new_size)
                                            VALUES (?, ?, ?, ?, ?, ?, ?)
                                        `, [
                                            entry.file_id,
                                            nowTimestamp,
                                            changeType,
                                            oldPath,
                                            entry.relative_path,
                                            oldSize,
                                            entry.size_bytes
                                        ], (err) => {
                                            if (err) reject(err);
                                            processNext();
                                        });
                                    } else {
                                        processNext();
                                    }
                                });
                            } else {
                                // Neue Datei
                                stats.new += 1;
                                db.run(`
                                    INSERT INTO tree_entries_v2
                                    (file_id, root_path, relative_path, name, type, depth, parent_path,
                                     size_bytes, previous_size_bytes, size_change_bytes,
                                     mtime_timestamp, mtime_iso, first_seen_timestamp, last_seen_timestamp,
                                     change_type, content_hash)
                                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                                `, [
                                    entry.file_id,
                                    entry.root_path,
                                    entry.relative_path,
                                    entry.name,
                                    entry.type,
                                    entry.depth,
                                    entry.parent_path,
                                    entry.size_bytes,
                                    entry.size_bytes,
                                    0,
                                    entry.mtime_timestamp,
                                    entry.mtime_iso,
                                    nowTimestamp,
                                    nowTimestamp,
                                    'NEW',
                                    null  // content_hash
                                ], (err) => {
                                    if (err) reject(err);
                                    processNext();
                                });
                            }
                        }
                    );
                }
                
                db.run('BEGIN TRANSACTION', (err) => {
                    if (err) reject(err);
                    processNext();
                });
            });
        });
    }

    async exportChanges(sinceHours = 24) {
        /**Exportiert Änderungen der letzten X Stunden*/
        const db = await this.connect();
        
        return new Promise((resolve, reject) => {
            const since = (Date.now() / 1000) - (sinceHours * 3600);
            
            db.all(`
                SELECT * FROM tree_entries_v2 
                WHERE change_type IN ('NEW', 'MODIFIED', 'MOVED', 'DELETED')
                AND last_seen_timestamp > ?
                ORDER BY last_seen_timestamp DESC
            `, [since], (err, changes) => {
                if (err) reject(err);
                
                const exportFile = path.join(WORKSPACE, `tree_changes_last_${sinceHours}h.json`);
                
                const data = changes.map(row => {
                    const obj = {};
                    for (const key in row) {
                        obj[key] = row[key];
                    }
                    return obj;
                });
                
                fs.writeFile(exportFile, JSON.stringify(data, null, 2), (err) => {
                    if (err) reject(err);
                    
                    console.log(`✅ Änderungen exportiert: ${exportFile} (${changes.length} Einträge)`);
                    resolve(exportFile);
                });
            });
        });
    }
}

async function main() {
    console.log("=".repeat(60));
    console.log("TREE INDEXER v2 - Erweitertes Tracking");
    console.log("=".repeat(60));
    
    const indexer = new TreeIndexerV2();
    await indexer.initSchemaV2();
    
    console.log("\n--- Scanning Workspace ---");
    const entries = indexer.scanDirectoryDetailed(WORKSPACE, 8);
    console.log(`Gefunden: ${entries.length} Einträge`);
    
    console.log("\n--- Aktualisiere Datenbank ---");
    const stats = await indexer.updateDatabase(entries);
    console.log("Statistiken:");
    console.log(`  NEU:        ${stats.new || 0}`);
    console.log(`  MODIFIED:   ${stats.modified || 0}`);
    console.log(`  MOVED:      ${stats.moved || 0}`);
    console.log(`  UNCHANGED:  ${stats.unchanged || 0}`);
    console.log(`  DELETED:    ${stats.deleted || 0}`);
    
    console.log("\n--- Exportiere Änderungen (24h) ---");
    await indexer.exportChanges(24);
    
    console.log("\n" + "=".repeat(60));
    console.log("TREE INDEXING ABGESCHLOSSEN");
    console.log("=".repeat(60));
}

if (require.main === module) {
    main().catch(console.error);
}

module.exports = TreeIndexerV2;
