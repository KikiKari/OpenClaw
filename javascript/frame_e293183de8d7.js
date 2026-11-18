#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "2c6a06c0374d8ec2f6204ad8883c370f1542eb174c4af5bd25261f9bf43b3370", "source_sha256": "b339455e9e618c836ccf2e3732e4fec9897f079730d8814eadb716e2459df453", "target_language": "javascript"}
// frame.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:skills/video-frames/scripts/frame.sh
// auch in: OpenClaw@gateway2:skills/video-frames/scripts/frame.sh
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

function usage() {
  console.error(`Usage:
  frame.sh <video-file> [--time HH:MM:SS] [--index N] --out /path/to/frame.jpg

Examples:
  frame.sh video.mp4 --out /tmp/frame.jpg
  frame.sh video.mp4 --time 00:00:10 --out /tmp/frame-10s.jpg
  frame.sh video.mp4 --index 0 --out /tmp/frame0.png`);
  process.exit(2);
}

const args = process.argv.slice(2);

if (args.length === 0 || args[0] === '-h' || args[0] === '--help') {
  usage();
}

let inFile = args[0];
let time = '';
let index = '';
let outFile = '';

let i = 1;
while (i < args.length) {
  switch (args[i]) {
    case '--time':
      time = args[i + 1] || '';
      i += 2;
      break;
    case '--index':
      index = args[i + 1] || '';
      i += 2;
      break;
    case '--out':
      outFile = args[i + 1] || '';
      i += 2;
      break;
    default:
      console.error(`Unknown arg: ${args[i]}`);
      usage();
  }
}

if (!fs.existsSync(inFile)) {
  console.error(`File not found: ${inFile}`);
  process.exit(1);
}

if (!outFile) {
  console.error('Missing --out');
  usage();
}

// Stelle sicher, dass das Ausgabeverzeichnis existiert
const outDir = path.dirname(outFile);
fs.mkdirSync(outDir, { recursive: true });

let ffmpegArgs;

if (index !== '') {
  ffmpegArgs = [
    '-hide_banner',
    '-loglevel', 'error',
    '-y',
    '-i', inFile,
    '-vf', `select=eq(n\\,${index})`,
    '-vframes', '1',
    outFile
  ];
} else if (time !== '') {
  ffmpegArgs = [
    '-hide_banner',
    '-loglevel', 'error',
    '-y',
    '-ss', time,
    '-i', inFile,
    '-frames:v', '1',
    outFile
  ];
} else {
  ffmpegArgs = [
    '-hide_banner',
    '-loglevel', 'error',
    '-y',
    '-i', inFile,
    '-vf', 'select=eq(n\\,0)',
    '-vframes', '1',
    outFile
  ];
}

const result = spawnSync('ffmpeg', ffmpegArgs, { stdio: 'inherit' });

if (result.error) {
  console.error(result.error.message);
  process.exit(1);
}

if (result.status !== 0) {
  process.exit(result.status);
}

console.log(outFile);
