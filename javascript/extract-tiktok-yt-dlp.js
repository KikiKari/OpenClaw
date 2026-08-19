#!/usr/bin/env node
// extract-tiktok-yt-dlp.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-yt-dlp.sh
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import { spawnSync } from 'child_process';
import os from 'os';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const USERNAME = process.argv[2]?.replace(/^@/, '') || '';
const FORMAT = process.argv[3] || 'best';
const JSON_FLAG = process.argv[4] || '';
const TIMESTAMP = new Date().toISOString().replace(/\.\d+Z$/, 'Z');

let TMP_DIR;
try {
  TMP_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'tiktok-yt-dlp-'));
} catch (err) {
  console.error('Failed to create temporary directory');
  process.exit(1);
}

process.on('exit', () => {
  if (TMP_DIR && fs.existsSync(TMP_DIR)) {
    fs.rmSync(TMP_DIR, { recursive: true });
  }
});

process.on('SIGINT', () => process.exit(130));
process.on('SIGTERM', () => process.exit(143));

function emit_json(success, method, username, url, format, error, timestamp, status) {
  const keys = ["success", "method", "username", "url", "format", "error", "timestamp", "status"];
  const values = [success, method, username, url, format, error, timestamp, status];
  const payload = {};
  
  for (let i = 0; i < keys.length; i++) {
    if (values[i] !== "" && values[i] !== undefined && values[i] !== null) {
      payload[keys[i]] = values[i];
    }
  }
  
  if (payload.success !== undefined) {
    payload.success = payload.success.toString().toLowerCase() === "true";
  }
  
  return JSON.stringify(payload);
}

if (!USERNAME.match(/^[A-Za-z0-9._]{1,24}$/)) {
  console.error("Invalid TikTok username");
  process.exit(64);
}

const validFormats = [
  "hls-origin/hls-pull/hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-origin/flv-hd/flv-ld",
  "hls-uhd_60/hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld",
  "hls-hd_60/hls-hd/hls-sd/hls-ld/flv-hd/flv-ld",
  "hls-hd/hls-sd/hls-ld/flv-hd/flv-sd/flv-ld",
  "hls-sd/hls-ld/flv-sd/flv-ld",
  "hls-ld/flv-ld",
  "hls-origin/hls-hd/hls-sd/hls-ld/hls-pull/flv-origin/flv-hd/flv-ld"
];

if (!validFormats.includes(FORMAT)) {
  console.error("Invalid yt-dlp format");
  process.exit(64);
}

const loadPerCpu = os.loadavg()[0] / Math.max(1, os.cpus().length);
const MAX_LOAD = process.env.TIKTOK_MAX_LOAD_PER_CPU ? parseFloat(process.env.TIKTOK_MAX_LOAD_PER_CPU) : 1.5;

if (loadPerCpu > MAX_LOAD) {
  const errorMsg = emit_json(
    "false", 
    "yt-dlp", 
    USERNAME, 
    "", 
    FORMAT, 
    "host overloaded", 
    TIMESTAMP, 
    "overloaded"
  );
  console.error(errorMsg);
  process.exit(75);
}

try {
  const whichResult = spawnSync('which', ['yt-dlp'], { stdio: 'pipe' });
  if (whichResult.status !== 0) {
    const errorMsg = emit_json(
      "false", 
      "yt-dlp", 
      USERNAME, 
      "", 
      FORMAT, 
      "yt-dlp not installed", 
      TIMESTAMP, 
      "dependency_missing"
    );
    console.error(errorMsg);
    process.exit(2);
  }
} catch (err) {
  const errorMsg = emit_json(
    "false", 
    "yt-dlp", 
    USERNAME, 
    "", 
    FORMAT, 
    "yt-dlp not installed", 
    TIMESTAMP, 
    "dependency_missing"
  );
  console.error(errorMsg);
  process.exit(2);
}

const LIVE_URL = `https://www.tiktok.com/@${USERNAME}/live`;
const stdoutFile = path.join(TMP_DIR, 'stdout.json');
const stderrFile = path.join(TMP_DIR, 'stderr.log');

const ytDlpResult = spawnSync(
  'yt-dlp',
  ['--no-warnings', '--dump-single-json', '--skip-download', '--format', FORMAT, LIVE_URL],
  { stdio: ['pipe', fs.openSync(stdoutFile, 'w'), fs.openSync(stderrFile, 'w')] }
);

if (ytDlpResult.status !== 0) {
  let STATUS, CODE;
  try {
    const stderrContent = fs.readFileSync(stderrFile, 'utf8').toLowerCase();
    if (stderrContent.includes('not currently live') || 
        stderrContent.includes('no live cdn found') || 
        stderrContent.includes('not available') || 
        stderrContent.includes('private video')) {
      STATUS = 'offline';
      CODE = 1;
    } else {
      STATUS = 'technical_error';
      CODE = 2;
    }
  } catch (readErr) {
    STATUS = 'technical_error';
    CODE = 2;
  }

  let errorContent = '';
  try {
    errorContent = fs.readFileSync(stderrFile, 'utf8').substring(0, 1000);
  } catch (readErr) {
    errorContent = 'Failed to read error log';
  }

  const errorMsg = emit_json(
    "false", 
    "yt-dlp", 
    USERNAME, 
    "", 
    FORMAT, 
    errorContent, 
    TIMESTAMP, 
    STATUS
  );
  console.error(errorMsg);
  process.exit(CODE);
}

let URL = '';
try {
  const jsonData = JSON.parse(fs.readFileSync(stdoutFile, 'utf8'));
  const candidates = [];
  
  if (typeof jsonData.url === 'string') {
    candidates.push(jsonData.url);
  }
  
  if (Array.isArray(jsonData.formats)) {
    for (const item of jsonData.formats) {
      if (item && typeof item.url === 'string') {
        candidates.push(item.url);
      }
    }
  }
  
  for (const value of candidates) {
    const low = value.toLowerCase();
    if (value.startsWith("https://") && (low.includes(".m3u8") || low.includes(".flv")) && !low.includes("only_audio=1")) {
      URL = value;
      break;
    }
  }
} catch (parseErr) {
  URL = '';
}

if (!URL) {
  const errorMsg = emit_json(
    "false", 
    "yt-dlp", 
    USERNAME, 
    "", 
    FORMAT, 
    "could not extract HTTPS video URL", 
    TIMESTAMP, 
    "offline"
  );
  console.error(errorMsg);
  process.exit(1);
}

if (JSON_FLAG === "--json") {
  const successMsg = emit_json(
    "true", 
    "yt-dlp", 
    USERNAME, 
    URL, 
    FORMAT, 
    "", 
    TIMESTAMP, 
    "live"
  );
  console.log(successMsg);
} else {
  console.log(URL);
}
