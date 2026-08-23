#!/usr/bin/env node
// test-search.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-search.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-search.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-search.sh
// auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-search.sh
// Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

import fs from 'fs';
import os from 'os';
import path from 'path';
import { execSync } from 'child_process';

if (!process.env.PERPLEXITY_API_KEY) {
  console.error('PERPLEXITY_API_KEY is required');
  process.exit(1);
}

const query = process.argv[2] || 'Perplexity API Platform';
const maxResults = process.env.PERPLEXITY_MAX_RESULTS || '3';
const maxTokensPerPage = process.env.PERPLEXITY_MAX_TOKENS_PER_PAGE || '256';
const out = path.join(process.env.TMPDIR || os.tmpdir(), 'perplexity-search-test.json');

const data = JSON.stringify({
  query: query,
  max_results: parseInt(maxResults),
  max_tokens_per_page: parseInt(maxTokensPerPage)
});

let code = '200';
try {
  const response = await fetch('https://api.perplexity.ai/search', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.PERPLEXITY_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: data
  });

  code = response.status.toString();
  
  const responseData = await response.json();
  fs.writeFileSync(out, JSON.stringify(responseData));
} catch (error) {
  if (error.cause && error.cause.code) {
    code = error.cause.code;
  } else {
    code = '000';
  }
  fs.writeFileSync(out, '{}');
}

console.log(`search_http=${code}`);

const content = JSON.parse(fs.readFileSync(out, 'utf8'));
const results = content.results || content.data || [];
const first = results.length > 0 ? results[0] : null;

console.log(JSON.stringify({
  keys: Object.keys(content),
  result_count: results.length,
  first: first
}, null, 2));
