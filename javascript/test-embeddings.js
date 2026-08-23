#!/usr/bin/env node
// test-embeddings.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/workspace/skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: OpenClaw@gateway1:perplexity-pack/files/skills/perplexity-pro-search/scripts/test-embeddings.sh
// auch in: OpenClaw@gateway2:skills/perplexity-pro-search/scripts/test-embeddings.sh
// Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

import fs from 'fs';
import os from 'os';
import path from 'path';
import { fileURLToPath } from 'url';
import fetch from 'node-fetch';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Check for required environment variable
if (!process.env.PERPLEXITY_API_KEY) {
    console.error('PERPLEXITY_API_KEY is required');
    process.exit(1);
}

const out = path.join(os.tmpdir(), 'perplexity-embeddings-test.json');

const payload = {
    input: [
        "Scientists explore the universe driven by curiosity.",
        "Curiosity compels us to seek explanations, not just observations.",
        "Historical discoveries began with curious questions.",
        "The pursuit of knowledge distinguishes human curiosity from mere stimulus response.",
        "Philosophy examines the nature of curiosity."
    ],
    model: "pplx-embed-v1-4b"
};

try {
    const response = await fetch('https://api.perplexity.ai/v1/embeddings', {
        method: 'POST',
        headers: {
            'Authorization': `Bearer ${process.env.PERPLEXITY_API_KEY}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
    });

    const responseData = await response.json();
    
    // Write response to temp file
    fs.writeFileSync(out, JSON.stringify(responseData, null, 2));
    
    console.log(`embeddings_http=${response.status}`);
    
    // Process and display results similar to jq command
    const result = {
        keys: Object.keys(responseData),
        model: responseData.model || null,
        item_count: (responseData.data || []).length,
        first_dim: (((responseData.data || [])[0] || {}).embedding || []).length,
        error: responseData.error || null
    };
    
    console.log(JSON.stringify(result, null, 2));
    
} catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
}
