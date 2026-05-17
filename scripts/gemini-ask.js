#!/usr/bin/env node
/**
 * gemini-ask.js - CLI tool for Google Gemini API
 * 
 * Usage:
 *   node gemini-ask.js "Your question here"
 *   echo "Your question" | node gemini-ask.js
 *   node gemini-ask.js --file prompt.txt
 *   node gemini-ask.js --model gemini-pro "Your question"
 * 
 * Environment:
 *   GEMINI_API_KEY - Required API key
 *   GEMINI_MODEL   - Optional default model (default: gemini-pro)
 */

import { GoogleGenerativeAI } from '@google/generative-ai';
import fs from 'fs';

const DEFAULT_MODEL = process.env.GEMINI_MODEL || 'gemini-pro';

async function main() {
  // Check API key
  if (!process.env.GEMINI_API_KEY) {
    console.error('Error: GEMINI_API_KEY environment variable is required');
    process.exit(1);
  }

  // Parse arguments
  let prompt = '';
  let modelName = DEFAULT_MODEL;
  const args = process.argv.slice(2);
  
  // Check for --model flag
  const modelIndex = args.findIndex(a => a === '--model' || a === '-m');
  if (modelIndex !== -1 && args[modelIndex + 1]) {
    modelName = args[modelIndex + 1];
    args.splice(modelIndex, 2);
  }

  // Check for --system flag (system prompt)
  let systemPrompt = '';
  const systemIndex = args.findIndex(a => a === '--system' || a === '-s');
  if (systemIndex !== -1 && args[systemIndex + 1]) {
    systemPrompt = args[systemIndex + 1];
    args.splice(systemIndex, 2);
  }

  if (args.includes('--file') || args.includes('-f')) {
    const fileIndex = args.findIndex(a => a === '--file' || a === '-f');
    const filePath = args[fileIndex + 1];
    if (!filePath) {
      console.error('Error: No file specified');
      process.exit(1);
    }
    prompt = fs.readFileSync(filePath, 'utf-8');
    // Remove --file and path from args
    args.splice(fileIndex, 2);
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
    console.error('Usage: gemini-ask "your question"');
    console.error('       gemini-ask --model gemini-pro "your question"');
    console.error('       echo "your question" | gemini-ask');
    process.exit(1);
  }

  try {
    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({ model: modelName });

    // Prepare generation config
    const generationConfig = {
      maxOutputTokens: 8192,
      temperature: 0.7,
      topP: 0.95,
    };

    let result;
    
    if (systemPrompt) {
      // Use chat with system prompt
      const chat = model.startChat({
        generationConfig,
        history: [
          { role: 'user', parts: [{ text: systemPrompt }] },
          { role: 'model', parts: [{ text: 'Understood. I will follow that instruction.' }] },
        ],
      });
      result = await chat.sendMessage(prompt);
    } else {
      // Direct generation
      result = await model.generateContent({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        generationConfig,
      });
    }

    const response = await result.response;
    const text = response.text();
    
    console.log(text);
  } catch (error) {
    console.error('Error:', error.message);
    if (error.message.includes('API key')) {
      console.error('Make sure GEMINI_API_KEY is set correctly');
    }
    process.exit(1);
  }
}

main();
