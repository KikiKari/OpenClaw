#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "b93c157b2d69d27a56004863fbbc1b8fdfed9d9dad05517678f7d047fe641948", "source_sha256": "04efde297083102c20b5caf33f76d4e5638a8f6b50c3d7c5e9b15e889a91b227", "target_language": "javascript"}
// html_translate.go — portiert nach javascript
// Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/html_translate.go
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

import { parse, serialize, walk } from 'parse5';
import { TextDecoder, TextEncoder } from 'util';

class HTMLReplacement {
  constructor(start, stop, value) {
    this.start = start;
    this.stop = stop;
    this.value = value;
  }
}

async function translateHTMLBlocks(ctx, translator, body, srcLang, tgtLang) {
  const doc = parse(body);
  const replacements = [];
  
  walk(doc, node => {
    if (node.tagName === 'html') return;
    
    if (node.nodeName === '#text' && node.parentNode && 
        ['code', 'pre', 'script', 'style'].includes(node.parentNode.tagName?.toLowerCase())) {
      return;
    }
    
    if (node.nodeName === '#text' && node.value.trim()) {
      const originalText = node.value;
      node.value = 'TRANSLATING_' + Math.random().toString(36).substr(2, 9); // Placeholder marker
      
      replacements.push({
        node: node,
        original: originalText,
        placeholder: node.value
      });
    }
  });

  // Translate all text nodes
  for (const replacement of replacements) {
    try {
      replacement.translated = await translator.Translate(ctx, replacement.original, srcLang, tgtLang);
    } catch (err) {
      throw new Error(`Translation failed: ${err.message}`);
    }
  }

  let result = serialize(doc);
  
  // Replace placeholders with translations
  for (const replacement of replacements) {
    result = result.replace(replacement.placeholder, replacement.translated);
  }
  
  return result;
}

function isSkipTag(tag) {
  return ['code', 'pre', 'script', 'style'].includes(tag.toLowerCase());
}

export { translateHTMLBlocks };
