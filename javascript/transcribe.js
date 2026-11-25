#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "43d92e9f696a7179ec8b0a084f7b04afff3dfc73c1c7eb09973f7f9e861d35b6", "source_sha256": "9c8abc93c198b77f804a6837db7baf1e85c902dc35a853c8086222a89f83fc89", "target_language": "javascript"}
// transcribe.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/openai-whisper-api/scripts/transcribe.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

function usage() {
  console.error('Usage:');
  console.error('  transcribe.js <audio-file> [--model whisper-1] [--out /path/to/out.txt] [--language en] [--prompt "hint"] [--json]');
  process.exit(2);
}

function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0 || args[0] === '-h' || args[0] === '--help') {
    usage();
  }

  let input = args[0];
  args.shift();

  let model = 'whisper-1';
  let out = '';
  let language = '';
  let prompt = '';
  let responseFormat = 'text';

  while (args.length > 0) {
    const arg = args[0];
    switch (arg) {
      case '--model':
        if (args.length < 2) usage();
        model = args[1];
        args.splice(0, 2);
        break;
      case '--out':
        if (args.length < 2) usage();
        out = args[1];
        args.splice(0, 2);
        break;
      case '--language':
        if (args.length < 2) usage();
        language = args[1];
        args.splice(0, 2);
        break;
      case '--prompt':
        if (args.length < 2) usage();
        prompt = args[1];
        args.splice(0, 2);
        break;
      case '--json':
        responseFormat = 'json';
        args.shift();
        break;
      default:
        console.error(`Unknown arg: ${arg}`);
        usage();
    }
  }

  if (!fs.existsSync(input)) {
    console.error(`File not found: ${input}`);
    process.exit(1);
  }

  if (!process.env.OPENAI_API_KEY) {
    console.error('Missing OPENAI_API_KEY');
    process.exit(1);
  }

  if (!out) {
    const base = path.parse(input).name;
    if (responseFormat === 'json') {
      out = `${base}.json`;
    } else {
      out = `${base}.txt`;
    }
  }

  // Create output directory
  const outDir = path.dirname(out);
  if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
  }

  const apiBase = process.env.OPENAI_BASE_URL 
    ? process.env.OPENAI_BASE_URL.replace(/\/$/, '')
    : 'https://api.openai.com/v1';

  // Build curl command
  const curlArgs = [
    '-sS',
    `${apiBase}/audio/transcriptions`,
    '-H', `Authorization: Bearer ${process.env.OPENAI_API_KEY}`,
    '-H', 'Accept: application/json',
    '-F', `file=@${input}`,
    '-F', `model=${model}`,
    '-F', `response_format=${responseFormat}`
  ];

  if (language) {
    curlArgs.push('-F', `language=${language}`);
  }

  if (prompt) {
    curlArgs.push('-F', `prompt=${prompt}`);
  }

  curlArgs.push(`>${out}`);

  // Execute curl command
  const result = spawnSync('sh', ['-c', `curl ${curlArgs.join(' ')}`], {
    stdio: ['pipe', 'pipe', 'pipe']
  });

  if (result.error) {
    console.error(result.error.message);
    process.exit(1);
  }

  if (result.status !== 0) {
    console.error(result.stderr.toString());
    process.exit(1);
  }

  console.log(out);
}

main();
