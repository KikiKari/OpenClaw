#!/usr/bin/env node
// update_docs_db.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:scripts/update_docs_db.py
// Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

/**
 * Scannt alle vorhandenen Dokumentationen und aktualisiert docs.db
 */

const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();

const WORKSPACE = "/home/openclaw/.openclaw/workspace";
const DB_PATH = path.join(WORKSPACE, "db", "docs.db");


function scanDocumentations() {
    /** Scannt alle .md Dateien im Workspace */
    let docs = [];
    
    // Hauptverzeichnis
    const mainDirFiles = fs.readdirSync(WORKSPACE);
    for (const file of mainDirFiles) {
        const filePath = path.join(WORKSPACE, file);
        const stat = fs.statSync(filePath);
        if (file.endsWith('.md') && stat.isFile() && !fs.lstatSync(filePath).isSymbolicLink()) {
            docs.push({
                name: file,
                path: '/',
                category: 'main',
                description: getDescription(filePath),
                type: 'doc',
                has_symlink: false,
                symlink_path: null,
                last_update: getMtime(filePath)
            });
        }
    }
    
    // WebSearch Verzeichnis
    const websearchDir = path.join(WORKSPACE, "websearch");
    if (fs.existsSync(websearchDir)) {
        const websearchFiles = fs.readdirSync(websearchDir);
        for (const file of websearchFiles) {
            if (file.endsWith('.md')) {
                const filePath = path.join(websearchDir, file);
                docs.push({
                    name: file,
                    path: 'websearch/',
                    category: 'websearch',
                    description: getDescription(filePath),
                    type: file.includes('GUIDE') ? 'guide' : 'config',
                    has_symlink: true,
                    symlink_path: `websearch/${file}`,
                    last_update: getMtime(filePath)
                });
            }
        }
    }
    
    // MCP Verzeichnis
    const mcpDir = path.join(WORKSPACE, "mcp");
    if (fs.existsSync(mcpDir)) {
        const mcpFiles = fs.readdirSync(mcpDir);
        for (const file of mcpFiles) {
            if (file.endsWith('.md')) {
                const filePath = path.join(mcpDir, file);
                const isSymlink = fs.lstatSync(filePath).isSymbolicLink();
                docs.push({
                    name: file,
                    path: 'mcp/',
                    category: 'mcp',
                    description: getDescription(filePath),
                    type: isSymlink ? 'symlink' : 'guide',
                    has_symlink: isSymlink,
                    symlink_path: isSymlink ? fs.readlinkSync(filePath) : null,
                    last_update: getMtime(filePath)
                });
            }
        }
    }
    
    // Docs-Unterverzeichnisse
    const docsDir = path.join(WORKSPACE, "docs");
    if (fs.existsSync(docsDir)) {
        const subdirs = fs.readdirSync(docsDir, { withFileTypes: true })
            .filter(dirent => dirent.isDirectory())
            .map(dirent => dirent.name);
            
        for (const subdir of subdirs) {
            const subdirPath = path.join(docsDir, subdir);
            const subdirFiles = fs.readdirSync(subdirPath);
            for (const file of subdirFiles) {
                if (file.endsWith('.md')) {
                    const filePath = path.join(subdirPath, file);
                    docs.push({
                        name: file,
                        path: `docs/${subdir}/`,
                        category: subdir,
                        description: getDescription(filePath),
                        type: 'doc',
                        has_symlink: false,
                        symlink_path: null,
                        last_update: getMtime(filePath)
                    });
                }
            }
        }
    }
    
    // Cluster, Memory, Reports, Skills
    const categories = ['cluster', 'memory', 'reports', 'skills'];
    for (const category of categories) {
        const catDir = path.join(WORKSPACE, category);
        if (fs.existsSync(catDir)) {
            const catFiles = fs.readdirSync(catDir);
            for (const file of catFiles) {
                if (file.endsWith('.md')) {
                    const filePath = path.join(catDir, file);
                    docs.push({
                        name: file,
                        path: `${category}/`,
                        category: category,
                        description: getDescription(filePath),
                        type: 'doc',
                        has_symlink: false,
                        symlink_path: null,
                        last_update: getMtime(filePath)
                    });
                }
            }
        }
    }
    
    return docs;
}


function getDescription(mdFilePath) {
    /** Extrahiert erste Zeile als Beschreibung */
    try {
        const content = fs.readFileSync(mdFilePath, 'utf8');
        const lines = content.split('\n');
        const firstLine = lines[0].trim();
        if (firstLine.startsWith('#')) {
            return firstLine.substring(1).trim();
        }
        return firstLine.length > 50 ? firstLine.substring(0, 50) + '...' : firstLine;
    } catch (error) {
        return 'Dokumentation';
    }
}


function getMtime(mdFilePath) {
    /** Gibt letzte Änderung zurück */
    try {
        const stats = fs.statSync(mdFilePath);
        const date = new Date(stats.mtime);
        return date.toISOString().split('T')[0];
    } catch (error) {
        return '2026-04-18';
    }
}


function updateDatabase(docs) {
    /** Aktualisiert docs.db mit allen gefundenen Dokumenten */
    const db = new sqlite3.Database(DB_PATH);
    
    return new Promise((resolve, reject) => {
        db.serialize(() => {
            // Lösche alte Einträge (außer config)
            db.run("DELETE FROM documents WHERE category != 'config'", (err) => {
                if (err) {
                    db.close();
                    return reject(err);
                }
                
                let inserted = 0;
                const stmt = db.prepare(`
                    INSERT INTO documents 
                    (name, path, category, description, type, has_symlink, symlink_path, last_update)
                    VALUES (?,?,?,?,?,?,?,?)
                `);
                
                docs.forEach(doc => {
                    stmt.run(
                        doc.name, doc.path, doc.category,
                        doc.description, doc.type, doc.has_symlink ? 1 : 0,
                        doc.symlink_path, doc.last_update,
                        (err) => {
                            if (err) {
                                console.error('Error inserting document:', err);
                            } else {
                                inserted++;
                            }
                        }
                    );
                });
                
                stmt.finalize((err) => {
                    if (err) {
                        db.close();
                        return reject(err);
                    }
                    
                    db.close();
                    resolve(inserted);
                });
            });
        });
    });
}


async function exportAll() {
    /** Erstellt alle Exporte */
    const db = new sqlite3.Database(DB_PATH);
    
    return new Promise((resolve, reject) => {
        db.serialize(() => {
            const tables = ['documents', 'skills', 'symlinks'];
            
            let completed = 0;
            tables.forEach(table => {
                db.all(`SELECT * FROM ${table}`, (err, rows) => {
                    if (err) {
                        console.error(`Error querying ${table}:`, err);
                        return;
                    }
                    
                    // JSON Export
                    const jsonData = rows.map(row => {
                        const obj = {};
                        for (const key in row) {
                            obj[key] = row[key];
                        }
                        return obj;
                    });
                    
                    const jsonPath = path.join(WORKSPACE, `db_${table}.json`);
                    fs.writeFileSync(jsonPath, JSON.stringify(jsonData, null, 2));
                    console.log(`✅ ${jsonPath}`);
                    
                    // CSV Export
                    if (rows.length > 0) {
                        const headers = Object.keys(rows[0]).join(',');
                        const csvData = rows.map(row => 
                            Object.values(row).map(value => 
                                `"${String(value).replace(/"/g, '""')}"`
                            ).join(',')
                        ).join('\n');
                        
                        const csvPath = path.join(WORKSPACE, `db_${table}.csv`);
                        fs.writeFileSync(csvPath, `${headers}\n${csvData}`);
                        console.log(`✅ ${csvPath}`);
                    }
                    
                    completed++;
                    if (completed === tables.length) {
                        db.close();
                        resolve();
                    }
                });
            });
        });
    });
}


async function main() {
    console.log("=" .repeat(60));
    console.log("DOCS.DB UPDATER");
    console.log("=" .repeat(60));
    
    console.log("\n--- Scanne Dokumentationen ---");
    const docs = scanDocumentations();
    console.log(`Gefunden: ${docs.length} Dokumente`);
    
    console.log("\n--- Aktualisiere docs.db ---");
    try {
        const inserted = await updateDatabase(docs);
        console.log(`✅ ${inserted} Dokumente in docs.db aktualisiert`);
    } catch (error) {
        console.error("Fehler beim Aktualisieren der Datenbank:", error);
        process.exit(1);
    }
    
    console.log("\n--- Erstelle Exporte ---");
    try {
        await exportAll();
    } catch (error) {
        console.error("Fehler beim Erstellen der Exporte:", error);
        process.exit(1);
    }
    
    console.log("\n" + "=" .repeat(60));
    console.log("DOCS.DB AKTUALISIERT");
    console.log("=" .repeat(60));
}

// Start the application
main().catch(console.error);
