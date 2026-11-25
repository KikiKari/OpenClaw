#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "327a75625d7ae8ea53c20361ce36e9628c9761fe50a54d760c65049319c418b8", "source_sha256": "bd1408a3d37597ed2c41b37fe2104f806ee5ea009396e16c58748eb01356bfb6", "target_language": "javascript"}
// tm.go — portiert nach javascript
// Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/tm.go
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');

class TMEntry {
  constructor(data = {}) {
    this.cache_key = data.cache_key || '';
    this.segment_id = data.segment_id || '';
    this.source_path = data.source_path || '';
    this.text_hash = data.text_hash || '';
    this.text = data.text || '';
    this.translated = data.translated || '';
    this.provider = data.provider || '';
    this.model = data.model || '';
    this.src_lang = data.src_lang || '';
    this.tgt_lang = data.tgt_lang || '';
    this.updated_at = data.updated_at || '';
  }
}

class TranslationMemory {
  constructor(filePath) {
    this.path = filePath;
    this.entries = new Map();
  }

  static async load(filePath) {
    const tm = new TranslationMemory(filePath);
    
    try {
      await fs.promises.mkdir(path.dirname(filePath), { recursive: true });
    } catch (err) {
      if (err.code !== 'EEXIST') {
        throw err;
      }
    }

    try {
      const data = await fs.promises.readFile(filePath, 'utf8');
      const lines = data.split('\n');
      
      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed) {
          try {
            const entry = JSON.parse(trimmed);
            if (entry.cache_key && (entry.translated || '').trim()) {
              tm.entries.set(entry.cache_key, new TMEntry(entry));
            }
          } catch (err) {
            throw new Error(`translation memory decode failed: ${err.message}`);
          }
        }
      }
    } catch (err) {
      if (err.code !== 'ENOENT') {
        throw err;
      }
    }
    
    return tm;
  }

  get(cacheKey) {
    const entry = this.entries.get(cacheKey);
    if (!entry) {
      return [null, false];
    }
    if (!(entry.translated || '').trim()) {
      return [null, false];
    }
    return [entry, true];
  }

  put(entry) {
    if (!entry.cache_key) {
      return;
    }
    this.entries.set(entry.cache_key, entry);
  }

  async save() {
    if (!this.path) {
      return;
    }
    
    const tmpPath = this.path + '.tmp';
    
    const sortedKeys = Array.from(this.entries.keys()).sort();
    
    let content = '';
    for (const key of sortedKeys) {
      const entry = this.entries.get(key);
      content += JSON.stringify(entry) + '\n';
    }
    
    await fs.promises.writeFile(tmpPath, content, 'utf8');
    await fs.promises.rename(tmpPath, this.path);
  }
}

module.exports = { TranslationMemory, TMEntry };
