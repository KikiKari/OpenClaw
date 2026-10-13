#!/usr/bin/env node
// update_docs_db.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway2:scripts/update_docs_db.py
// Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import sqlite3 from 'sqlite3';
import { promisify } from 'util';

const WORKSPACE = '/workspace';
const DB_PATH = path.join(WORKSPACE, 'db', 'docs.db');

async function* iterDocs() {
  const walk = async function* (dir) {
    try {
      const entries = await fs.promises.readdir(dir, { withFileTypes: true });
      for (const entry of entries) {
        const fullPath = path.join(dir, entry.name);
        if (entry.isSymbolicLink()) {
          continue;
        }
        if (entry.isDirectory()) {
          const rel = path.relative(WORKSPACE, fullPath);
          const parts = rel.split(path.sep);
          if (parts.some(part => ['node_modules', '.git', 'backups'].includes(part))) {
            continue;
          }
          yield* walk(fullPath);
        } else if (entry.isFile() && entry.name.endsWith('.md')) {
          yield fullPath;
        }
      }
    } catch (err) {
      // Ignore errors
    }
  };
  yield* walk(WORKSPACE);
}

function fileHash(filePath) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash('md5');
    const stream = fs.createReadStream(filePath);
    stream.on('data', chunk => hash.update(chunk));
    stream.on('end', () => resolve(hash.digest('hex')));
    stream.on('error', reject);
  });
}

async function wordCount(filePath) {
  try {
    const content = await fs.promises.readFile(filePath, 'utf8');
    return content.split(/\s+/).filter(word => word.length > 0).length;
  } catch (err) {
    return 0;
  }
}

async function buildRows() {
  const indexed = Date.now() / 1000;
  const rows = [];
  for await (const mdFile of iterDocs()) {
    const relPath = path.relative(WORKSPACE, mdFile);
    rows.push({
      path: relPath,
      content_hash: await fileHash(mdFile),
      last_indexed: indexed,
      word_count: await wordCount(mdFile)
    });
  }
  return rows;
}

function ensureSchema(db) {
  return new Promise((resolve, reject) => {
    db.serialize(() => {
      db.run(`
        CREATE TABLE IF NOT EXISTS documents (
          path TEXT PRIMARY KEY,
          content_hash TEXT,
          last_indexed REAL,
          word_count INTEGER
        )
      `, err => {
        if (err) return reject(err);
        
        db.run(`
          CREATE TABLE IF NOT EXISTS tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            path TEXT,
            tag TEXT
          )
        `, err => {
          if (err) return reject(err);
          resolve();
        });
      });
    });
  });
}

async function updateDatabase(rows) {
  const db = new sqlite3.Database(DB_PATH);
  const runAsync = promisify(db.run.bind(db));
  
  try {
    await ensureSchema(db);
    await runAsync('DELETE FROM documents');
    
    if (rows.length > 0) {
      const stmt = db.prepare('INSERT INTO documents (path, content_hash, last_indexed, word_count) VALUES (?, ?, ?, ?)');
      const execAsync = promisify(stmt.run.bind(stmt));
      
      for (const row of rows) {
        await execAsync(row.path, row.content_hash, row.last_indexed, row.word_count);
      }
      
      stmt.finalize();
    }
    
    await new Promise((resolve, reject) => {
      db.exec('COMMIT', err => err ? reject(err) : resolve());
    });
  } finally {
    db.close();
  }
}

async function exportTable(table) {
  const db = new sqlite3.Database(DB_PATH);
  const allAsync = promisify(db.all.bind(db));
  
  try {
    const rows = await allAsync(`SELECT * FROM ${table}`);
    
    const jsonPath = path.join(WORKSPACE, `db_${table}.json`);
    const csvPath = path.join(WORKSPACE, `db_${table}.csv`);
    
    await fs.promises.writeFile(jsonPath, JSON.stringify(rows, null, 2));
    
    const csvStream = fs.createWriteStream(csvPath);
    const writeCsv = promisify((data, callback) => {
      csvStream.write(data, 'utf8', callback);
    });
    
    if (rows.length > 0) {
      const headers = Object.keys(rows[0]);
      await writeCsv(headers.join(',') + '\n');
      
      for (const row of rows) {
        const values = headers.map(header => row[header]).join(',');
        await writeCsv(values + '\n');
      }
    } else {
      await writeCsv('\n');
    }
    
    csvStream.end();
    await new Promise(resolve => csvStream.on('finish', resolve));
  } finally {
    db.close();
  }
}

async function main() {
  console.log('=' .repeat(60));
  console.log('DOCS.DB UPDATER');
  console.log('=' .repeat(60));
  
  const rows = await buildRows();
  console.log(`Gefunden: ${rows.length} Dokumente`);
  
  await updateDatabase(rows);
  console.log(`✅ ${rows.length} Dokumente in docs.db aktualisiert`);
  
  await exportTable('documents');
  await exportTable('tags');
  console.log('✅ Exporte aktualisiert');
  
  console.log('\n' + '=' .repeat(60));
  console.log('DOCS.DB AKTUALISIERT');
  console.log('=' .repeat(60));
}

main().catch(console.error);
