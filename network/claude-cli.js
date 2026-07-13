#!/usr/bin/env node
/**
 * claude-cli.js - Command-line interface for Claude AI agent
 * 
 * Usage:
 *   node claude-cli.js "Your question here"
 *   echo "Your question" | node claude-cli.js
 *   node claude-cli.js --file prompt.txt
 * 
 * Environment:
 *   ANTHROPIC_API_KEY - Required API key
 *   CLAUDE_MODEL      - Optional model (default: claude-fable-5)
 */

import { Anthropic } from '@anthropic-ai/sdk';
import fs from 'fs';
import path from 'path';

const MODEL = process.env.CLAUDE_MODEL || 'claude-fable-5';

async function main() {
  // Check API key
  if (!process.env.ANTHROPIC_API_KEY) {
    console.error('Error: ANTHROPIC_API_KEY environment variable is required');
    process.exit(1);
  }

  const client = new Anthropic({
    apiKey: process.env.ANTHROPIC_API_KEY,
  });

  // Parse arguments
  let prompt = '';
  const args = process.argv.slice(2);
  
  if (args.includes('--file') || args.includes('-f')) {
    const fileIndex = args.findIndex(a => a === '--file' || a === '-f');
    const filePath = args[fileIndex + 1];
    if (!filePath) {
      console.error('Error: No file specified');
      process.exit(1);
    }
    prompt = fs.readFileSync(filePath, 'utf-8');
  } else if (args.length > 0) {
    prompt = args.join(' ');
  } else if (!process.stdin.isTTY) {
    // Read from stdin
    const chunks = [];
    for await (const chunk of process.stdin) {
      chunks.push(chunk);
    }
    prompt = Buffer.concat(chunks).toString('utf-8');
  }

  if (!prompt.trim()) {
    console.error('Error: No prompt provided');
    console.error('Usage: claude-cli "your question"');
    process.exit(1);
  }

  try {
    const response = await client.messages.create({
      model: MODEL,
      max_tokens: 4096,
      messages: [{ role: 'user', content: prompt }],
    });

    // Extract and print response text
    const text = response.content
      .filter(c => c.type === 'text')
      .map(c => c.text)
      .join('\n');
    
    console.log(text);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

main();
