#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "da3463800ad8b3594a722314c5f00bbe59b8e78eab555f8fc760eb02f7756bb8", "source_sha256": "fecaa7522aec9008996f5664c745893f7fb7a2a4a3134a9f2855acde7f79596c", "target_language": "javascript"}
// extract-tiktok-streamlink.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway2:skills/tiktok-live-mon/scripts/extraction-methods/extract-tiktok-streamlink.sh
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

import { spawnSync } from 'child_process';
import os from 'os';

const emitJson = (success, method, username, url, quality, author, title, error, timestamp, status) => {
  const payload = {
    success: typeof success === 'string' ? success.toLowerCase() === 'true' : success,
    method,
    username,
    url: url || undefined,
    quality,
    author: author || undefined,
    title: title || undefined,
    error: error || undefined,
    timestamp,
    status
  };

  // Remove undefined values
  Object.keys(payload).forEach(key => {
    if (payload[key] === undefined) {
      delete payload[key];
    }
  });

  console.error(JSON.stringify(payload));
};

const runPython = (script, ...args) => {
  const result = spawnSync('python3', ['-c', script, ...args], { encoding: 'utf-8' });
  if (result.error) {
    throw result.error;
  }
  return result.stdout.trim();
};

const runCommand = (command, args = [], options = {}) => {
  const result = spawnSync(command, args, { encoding: 'utf-8', ...options });
  return {
    stdout: result.stdout,
    stderr: result.stderr,
    status: result.status,
    error: result.error
  };
};

// Get arguments
const USERNAME = process.argv[2]?.replace(/^@/, '') || '';
const QUALITY = process.argv[3] || 'best';
const JSON_FLAG = process.argv[4] || '';

// Validate username
if (!USERNAME.match(/^[A-Za-z0-9._]{1,24}$/)) {
  console.error('Invalid TikTok username');
  process.exit(64);
}

// Validate quality
if (!['best', 'worst', 'original', '1080p60', '720p60', '720p', '540p', '360p', 'auto'].includes(QUALITY)) {
  console.error('Invalid stream quality');
  process.exit(64);
}

const TIMESTAMP = new Date().toISOString().replace(/\.\d+Z$/, 'Z');

try {
  // Check system load
  const loadPerCpu = os.loadavg()[0] / Math.max(1, os.cpus().length);
  const maxLoad = parseFloat(process.env.TIKTOK_MAX_LOAD_PER_CPU || '1.5');
  
  if (loadPerCpu > maxLoad) {
    emitJson(false, 'streamlink', USERNAME, '', QUALITY, '', '', 'host overloaded', TIMESTAMP, 'overloaded');
    process.exit(75);
  }

  // Check if streamlink exists
  const streamlinkCheck = runCommand('streamlink', ['--version']);
  if (streamlinkCheck.status !== 0) {
    emitJson(false, 'streamlink', USERNAME, '', QUALITY, '', '', 'streamlink not installed', TIMESTAMP, 'dependency_missing');
    process.exit(2);
  }

  const LIVE_URL = `https://www.tiktok.com/@${USERNAME}/live`;
  
  let selector;
  switch (QUALITY) {
    case 'original':
      selector = 'origin,uhd_60,hd_60,hd,sd,ld,best,worst';
      break;
    case 'auto':
      selector = 'best,origin,uhd_60,hd_60,hd,sd,ld,worst';
      break;
    case '1080p60':
      selector = 'uhd_60,hd_60,hd,sd,ld,worst';
      break;
    case '720p60':
      selector = 'hd_60,hd,sd,ld,worst';
      break;
    case '720p':
      selector = 'hd,sd,ld,worst';
      break;
    case '540p':
      selector = 'sd,ld,worst';
      break;
    case '360p':
      selector = 'ld,worst';
      break;
    default:
      selector = QUALITY;
  }

  // Try to get JSON output first
  const jsonResult = runCommand('streamlink', ['--json', LIVE_URL, selector], { stdio: ['pipe', 'pipe', 'pipe'] });
  
  if (jsonResult.status !== 0 || !jsonResult.stdout) {
    // Fallback to stream-url
    const urlResult = runCommand('streamlink', ['--stream-url', LIVE_URL, selector], { stdio: ['pipe', 'pipe', 'pipe'] });
    
    if (urlResult.status !== 0 || !urlResult.stdout) {
      emitJson(false, 'streamlink', USERNAME, '', QUALITY, '', '', 'streamlink failed or no stream found', TIMESTAMP, 'offline');
      process.exit(1);
    }
    
    const url = urlResult.stdout.trim();
    if (JSON_FLAG === '--json') {
      emitJson(true, 'streamlink', USERNAME, url, QUALITY, '', '', '', TIMESTAMP, 'live');
    } else {
      console.log(url);
    }
    process.exit(0);
  }

  // Parse JSON output
  try {
    const data = JSON.parse(jsonResult.stdout);
    let url = data.url || '';
    const streams = data.streams || {};
    
    if (!url && typeof streams === 'object') {
      const keys = ['best', 'worst', ...Object.keys(streams)];
      for (const key of keys) {
        const value = streams[key];
        if (typeof value === 'object' && value.url) {
          url = value.url;
          break;
        }
      }
    }
    
    const metadata = data.metadata || {};
    const author = metadata.author || '';
    const title = metadata.title || '';
    
    if (!url) {
      emitJson(false, 'streamlink', USERNAME, '', QUALITY, author, title, 'could not extract stream URL', TIMESTAMP, 'offline');
      process.exit(1);
    }
    
    if (JSON_FLAG === '--json') {
      emitJson(true, 'streamlink', USERNAME, url, QUALITY, author, title, '', TIMESTAMP, 'live');
    } else {
      console.log(url);
    }
  } catch (parseError) {
    emitJson(false, 'streamlink', USERNAME, '', QUALITY, '', '', 'invalid streamlink JSON', TIMESTAMP, 'technical_error');
    process.exit(2);
  }
} catch (error) {
  emitJson(false, 'streamlink', USERNAME, '', QUALITY, '', '', 'unexpected error', TIMESTAMP, 'technical_error');
  process.exit(2);
}
