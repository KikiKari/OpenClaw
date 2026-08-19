#!/usr/bin/env node
// frame.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:skills/video-frames/scripts/frame.sh
// auch in: OpenClaw@gateway2:skills/video-frames/scripts/frame.sh
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

function usage() {
  console.error(`Usage:
  frame.js <video-file> [--time HH:MM:SS] [--index N] --out /path/to/frame.jpg

Examples:
  frame.js video.mp4 --out /tmp/frame.jpg
  frame.js video.mp4 --time 00:00:10 --out /tmp/frame-10s.jpg
  frame.js video.mp4 --index 0 --out /tmp/frame0.png`);
  process.exit(2);
}

if (process.argv.length < 3 || process.argv[2] === '-h' || process.argv[2] === '--help') {
  usage();
}

let args = process.argv.slice(2);
let in_file = args[0];
let rest_args = args.slice(1);

let time = "";
let index = "";
let out = "";

let i = 0;
while (i < rest_args.length) {
  let arg = rest_args[i];
  switch (arg) {
    case '--time':
      if (i + 1 >= rest_args.length) {
        console.error("Missing value for --time");
        usage();
      }
      time = rest_args[i + 1];
      i += 2;
      break;
    case '--index':
      if (i + 1 >= rest_args.length) {
        console.error("Missing value for --index");
        usage();
      }
      index = rest_args[i + 1];
      i += 2;
      break;
    case '--out':
      if (i + 1 >= rest_args.length) {
        console.error("Missing value for --out");
        usage();
      }
      out = rest_args[i + 1];
      i += 2;
      break;
    default:
      console.error(`Unknown arg: ${arg}`);
      usage();
  }
}

if (!fs.existsSync(in_file)) {
  console.error(`File not found: ${in_file}`);
  process.exit(1);
}

if (out === "") {
  console.error("Missing --out");
  usage();
}

// Ensure output directory exists
const outDir = path.dirname(out);
if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

let ffmpegArgs;
if (index !== "") {
  ffmpegArgs = [
    '-hide_banner',
    '-loglevel', 'error',
    '-y',
    '-i', in_file,
    '-vf', `select=eq(n\\,${index})`,
    '-vframes', '1',
    out
  ];
} else if (time !== "") {
  ffmpegArgs = [
    '-hide_banner',
    '-loglevel', 'error',
    '-y',
    '-ss', time,
    '-i', in_file,
    '-frames:v', '1',
    out
  ];
} else {
  ffmpegArgs = [
    '-hide_banner',
    '-loglevel', 'error',
    '-y',
    '-i', in_file,
    '-vf', 'select=eq(n\\,0)',
    '-vframes', '1',
    out
  ];
}

const result = spawnSync('ffmpeg', ffmpegArgs, { stdio: 'inherit' });

if (result.error) {
  console.error(`Error running ffmpeg: ${result.error.message}`);
  process.exit(1);
}

if (result.status !== 0) {
  process.exit(result.status);
}

console.log(out);
