#!/usr/bin/env node
// tree_fallback.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway2:db-maintainer/scripts/tree_fallback.py
// Erzeugt: 2026-10-13 durch ABSTRACTIONS_MANAGER.py

/**
 * Fallback tree generator for when the `tree` binary is unavailable.
 *
 * Produces output similar to `tree -a -L <depth>` and writes it to
 * important/openclaw-tree.txt with a timestamp header.
 */

const fs = require('fs');
const path = require('path');

const WORKSPACE = '/workspace';
const DEPTH = 6;
const SKIP = new Set(['.git', 'node_modules', '__pycache__', 'venv', '.cache', '.npm', '.local']);
const OUT = path.join(WORKSPACE, 'important', 'openclaw-tree.txt');

function walk(dirPath, prefix = '', depth = 0) {
  const lines = [];
  if (depth >= DEPTH) {
    return lines;
  }
  
  try {
    const entries = fs.readdirSync(dirPath, { withFileTypes: true });
    entries.sort((a, b) => {
      // directories first, then alphabetically
      if (a.isDirectory() !== b.isDirectory()) {
        return a.isDirectory() ? -1 : 1;
      }
      return a.name.localeCompare(b.name);
    });
    
    const filteredEntries = entries.filter(entry => !SKIP.has(entry.name));
    
    for (let i = 0; i < filteredEntries.length; i++) {
      const entry = filteredEntries[i];
      const last = i === filteredEntries.length - 1;
      const connector = last ? '└── ' : '├── ';
      const suffix = entry.isDirectory() ? '/' : '';
      lines.push(`${prefix}${connector}${entry.name}${suffix}`);
      
      const fullPath = path.join(dirPath, entry.name);
      if (entry.isDirectory() && !entry.isSymbolicLink()) {
        const extension = last ? '    ' : '│   ';
        lines.push(...walk(fullPath, prefix + extension, depth + 1));
      }
    }
  } catch (error) {
    // Ignore permission errors or other OS errors
  }
  
  return lines;
}

function main() {
  const lines = [WORKSPACE];
  lines.push(...walk(WORKSPACE));
  const body = lines.join('\n') + '\n';
  const now = new Date().toISOString();
  const header = 
    `# OpenClaw Workspace Tree\n` +
    `# Generiert: ${now}\n` +
    `# Fallback (tree binary nicht verfuegbar), Tiefe ${DEPTH}\n` +
    `# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n`;
  
  // Ensure parent directory exists
  const outDir = path.dirname(OUT);
  fs.mkdirSync(outDir, { recursive: true });
  
  fs.writeFileSync(OUT, header + body);
  console.log(`openclaw-tree.txt aktualisiert (Fallback): ${OUT} (${lines.length} Eintraege)`);
}

main();
