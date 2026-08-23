#!/usr/bin/env node
// test-agent.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-agent.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-agent.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-agent.sh
// auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-agent.sh
// Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

import fs from 'fs';
import os from 'os';
import path from 'path';
import { fileURLToPath } from 'url';
import process from 'process';

// Equivalent to set -euo pipefail
process.on('unhandledRejection', (err) => {
  throw err;
});

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Check for required environment variable
if (!process.env.PERPLEXITY_API_KEY) {
  console.error('PERPLEXITY_API_KEY is required');
  process.exit(1);
}

// Get command line argument or default prompt
const prompt = process.argv[2] || 'Compare recent open-source LLMs in terms of performance, licensing, and practical use.';
const out = process.env.TMPDIR || os.tmpdir() + '/perplexity-agent-test.json';

// Function to make HTTP request
async function makeRequest(url, options) {
  const response = await fetch(url, options);
  const data = await response.json();
  return {
    statusCode: response.status,
    data: data
  };
}

// Main execution
(async () => {
  try {
    const requestBody = JSON.stringify({
      preset: 'fast-search',
      input: prompt
    });

    const response = await makeRequest('https://api.perplexity.ai/v1/agent', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${process.env.PERPLEXITY_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: requestBody
    });

    // Write response to file
    fs.writeFileSync(out, JSON.stringify(response.data, null, 2));

    console.log(`agent_http=${response.statusCode}`);

    // Process and display selected fields like the jq command
    const result = {
      keys: Object.keys(response.data),
      id: response.data.id || null,
      status: response.data.status || null,
      output_count: (response.data.output || []).length,
      error: response.data.error || null
    };

    console.log(JSON.stringify(result, null, 2));

  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
})();
