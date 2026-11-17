#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "c0fd31879b210cdb3321e83f98b64ee24673973c78e393c3893384dc80ccc584", "source_sha256": "b00f64d55d344bbcc351ae7ade12137f0d9293b556aa0881ede43bef5bcb778b", "target_language": "javascript"}
// extract-tiktok-yt-dlp.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-yt-dlp.sh
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

import { spawnSync } from 'child_process';
import { mkdtempSync, writeFileSync, readFileSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';
import { rmSync } from 'fs';

const USERNAME = process.argv[2]?.replace(/^@/, '') || '';
const FORMAT = process.argv[3] || 'best';
const JSON_FLAG = process.argv[4] || '';
const TIMESTAMP = new Date().toISOString().replace(/\.\d+Z$/, 'Z');

const TMP_DIR = mkdtempSync(join(tmpdir(), 'tiktok-yt-dlp-'));
let cleanupDone = false;

function cleanup() {
  if (!cleanupDone) {
    rmSync(TMP_DIR, { recursive: true, force: true });
    cleanupDone = true;
  }
}

process.on('exit', cleanup);
process.on('SIGINT', () => { cleanup(); process.exit(128 + 2); });
process.on('SIGTERM', () => { cleanup(); process.exit(128 + 15); });

function emitJson(success, method, username, url, format, error, timestamp, status) {
  const payload = {};
  const keys = ["success", "method", "username", "url", "format", "error", "timestamp", "status"];
  const values = [success, method, username, url, format, error, timestamp, status];
  
  for (let i = 0; i < keys.length; i++) {
    if (values[i] !== undefined && values[i] !== null && values[i] !== "") {
      payload[keys[i]] = values[i];
    }
  }
  
  if (payload.success !== undefined) {
    payload.success = payload.success === true || payload.success === "true";
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

const loadAvgResult = spawnSync('python3', ['-c', 'import os; print(os.getloadavg()[0] / max(1, os.cpu_count() or 1))'], { encoding: 'utf-8' });
const LOAD_PER_CPU = parseFloat(loadAvgResult.stdout.trim());
const MAX_LOAD = process.env.TIKTOK_MAX_LOAD_PER_CPU ? parseFloat(process.env.TIKTOK_MAX_LOAD_PER_CPU) : 1.5;

if (LOAD_PER_CPU > MAX_LOAD) {
  const errorMsg = emitJson("false", "yt-dlp", USERNAME, "", FORMAT, "host overloaded", TIMESTAMP, "overloaded");
  console.error(errorMsg);
  process.exit(75);
}

try {
  const whichResult = spawnSync('which', ['yt-dlp'], { encoding: 'utf-8' });
  if (whichResult.status !== 0) {
    const errorMsg = emitJson("false", "yt-dlp", USERNAME, "", FORMAT, "yt-dlp not installed", TIMESTAMP, "dependency_missing");
    console.error(errorMsg);
    process.exit(2);
  }
} catch (error) {
  const errorMsg = emitJson("false", "yt-dlp", USERNAME, "", FORMAT, "yt-dlp not installed", TIMESTAMP, "dependency_missing");
  console.error(errorMsg);
  process.exit(2);
}

const LIVE_URL = `https://www.tiktok.com/@${USERNAME}/live`;
const stdoutFile = join(TMP_DIR, 'stdout.json');
const stderrFile = join(TMP_DIR, 'stderr.log');

const ytDlpResult = spawnSync(
  'yt-dlp',
  ['--no-warnings', '--dump-single-json', '--skip-download', '--format', FORMAT, LIVE_URL],
  { encoding: 'utf-8' }
);

writeFileSync(stdoutFile, ytDlpResult.stdout || '');
writeFileSync(stderrFile, ytDlpResult.stderr || '');

const EXIT_CODE = ytDlpResult.status;

if (EXIT_CODE !== 0) {
  let STATUS, CODE;
  const stderrContent = readFileSync(stderrFile, 'utf-8');
  
  if (/not currently live|No live cdn found|not available|private video/i.test(stderrContent)) {
    STATUS = "offline";
    CODE = 1;
  } else {
    STATUS = "technical_error";
    CODE = 2;
  }
  
  const errorMsg = emitJson("false", "yt-dlp", USERNAME, "", FORMAT, 
    stderrContent.substring(0, 1000), TIMESTAMP, STATUS);
  console.error(errorMsg);
  process.exit(CODE);
}

let URL = "";
try {
  const data = JSON.parse(readFileSync(stdoutFile, 'utf-8'));
  const candidates = [];
  
  if (typeof data.url === 'string') {
    candidates.push(data.url);
  }
  
  if (Array.isArray(data.formats)) {
    for (const item of data.formats) {
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
} catch (e) {
  // Ignore parsing errors
}

if (!URL) {
  const errorMsg = emitJson("false", "yt-dlp", USERNAME, "", FORMAT, 
    "could not extract HTTPS video URL", TIMESTAMP, "offline");
  console.error(errorMsg);
  process.exit(1);
}

if (JSON_FLAG === "--json") {
  const successMsg = emitJson("true", "yt-dlp", USERNAME, URL, FORMAT, "", TIMESTAMP, "live");
  console.log(successMsg);
} else {
  console.log(URL);
}
