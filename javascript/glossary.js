#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "272d8c6b0141cfa4341ea65fce025312e1a314259584f720bcea4aaa80f42f30", "source_sha256": "969958657b3b071c8b5067af0ac0287ac68f3fbc6c5832a0339555e3a87d3357", "target_language": "javascript"}
// glossary.go — portiert nach javascript
// Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/glossary.go
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

class GlossaryEntry {
  constructor(source, target) {
    this.source = source;
    this.target = target;
  }
}

async function LoadGlossary(path) {
  try {
    const data = await require('fs').promises.readFile(path, 'utf8');
    const entries = JSON.parse(data);
    return entries.map(entry => new GlossaryEntry(entry.source, entry.target));
  } catch (err) {
    if (err.code === 'ENOENT') {
      return null;
    }
    if (err instanceof SyntaxError) {
      throw new Error(`glossary parse failed: ${err.message}`);
    }
    throw err;
  }
}

module.exports = { GlossaryEntry, LoadGlossary };
