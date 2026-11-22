#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "3d4cba13581c54efe3dc51474c23a0f384c1c0faf6a9203953d9a91c165d053e", "source_sha256": "fb758d6839889536b8c614e3eeae8bf16b595283b7e0b680d6bbb9606448105e", "target_language": "javascript"}
// recover-orphaned-processes.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/recover-orphaned-processes.sh
// Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

'use strict';

const { execFileSync } = require('node:child_process');
const fs = require('node:fs');

function usage() {
  process.stderr.write(`Usage: recover-orphaned-processes.js

Scans for likely orphaned coding agent processes and prints JSON.
`);
}

function main() {
  const args = process.argv.slice(2);
  
  if (args.includes('--help') || args.includes('-h')) {
    usage();
    process.exit(0);
  }
  
  if (args.length > 0) {
    usage();
    process.exit(2);
  }
  
  try {
    execFileSync('node', ['--version'], {
      stdio: 'ignore'
    });
  } catch (err) {
    let ts = 'unknown';
    try {
      ts = new Date().toISOString();
    } catch (dateErr) {
      // ignore
    }
    console.log(JSON.stringify({
      error: 'node not found on PATH',
      orphaned: [],
      ts: ts
    }));
    process.exit(0);
  }
  
  scanProcesses();
}

function scanProcesses() {
  let username = process.env.USER || process.env.LOGNAME || '';
  
  if (username && !/^[a-zA-Z0-9._-]+$/.test(username)) {
    username = '';
  }
  
  function runFile(file, args) {
    try {
      return execFileSync(file, args, {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
      });
    } catch (err) {
      if (err && typeof err.stdout === 'string') {
        return err.stdout;
      }
      if (err && err.stdout && Buffer.isBuffer(err.stdout)) {
        return err.stdout.toString('utf8');
      }
      return '';
    }
  }
  
  function resolveStarted(pid) {
    const started = runFile('ps', ['-o', 'lstart=', '-p', String(pid)]).trim();
    return started.length > 0 ? started : 'unknown';
  }
  
  function resolveCwd(pid) {
    if (process.platform === 'linux') {
      try {
        return fs.readlinkSync(`/proc/${pid}/cwd`);
      } catch {
        return 'unknown';
      }
    }
    const lsof = runFile('lsof', ['-a', '-d', 'cwd', '-p', String(pid), '-Fn']);
    const match = lsof.match(/^n(.+)$/m);
    return match ? match[1] : 'unknown';
  }
  
  function sanitizeCommand(cmd) {
    return cmd
      .replace(
        /(--(?:token|api[-_]?key|password|secret|authorization)\s+)([^\s]+)/gi,
        '$1<redacted>'
      )
      .replace(
        /((?:token|api[-_]?key|password|secret|authorization)=)([^\s]+)/gi,
        '$1<redacted>'
      )
      .replace(/(Bearer\s+)[A-Za-z0-9._~+/=-]+/g, '$1<redacted>');
  }
  
  let pgrepUnavailable = false;
  let pgrepResult = '';
  
  const pgrepArgs = username.length > 0
    ? ['-u', username, '-f', 'codex|claude']
    : ['-f', 'codex|claude'];
    
  try {
    pgrepResult = execFileSync('pgrep', pgrepArgs, {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });
  } catch (err) {
    if (err && err.code === 'ENOENT') {
      pgrepUnavailable = true;
      pgrepResult = '';
    } else if (err && typeof err.stdout === 'string') {
      pgrepResult = err.stdout;
    }
  }
  
  const candidatePids = pgrepResult
    .split('\n')
    .map(s => s.trim())
    .filter(s => s.length > 0 && /^\d+$/.test(s));
    
  let lines = [];
  if (candidatePids.length > 0) {
    lines = runFile('ps', ['-o', 'pid=,command=', '-p', candidatePids.join(',')]).split('\n');
  } else if (pgrepUnavailable && username.length > 0) {
    lines = runFile('ps', ['-U', username, '-o', 'pid=,command=']).split('\n');
  } else if (pgrepUnavailable) {
    lines = runFile('ps', ['-axo', 'pid=,command=']).split('\n');
  }
  
  const includePattern = /codex|claude/i;
  
  const excludePatterns = [
    /openclaw-gateway/i,
    /signal-cli/i,
    /node_modules\/\.bin\/openclaw/i,
    /recover-orphaned-processes\.sh/i,
  ];
  
  const orphaned = [];
  
  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line) continue;
    
    const match = line.match(/^(\d+)\s+(.+)$/);
    if (!match) continue;
    
    const pid = Number(match[1]);
    const cmd = match[2];
    
    if (!Number.isInteger(pid) || pid <= 0 || pid === process.pid) continue;
    if (!includePattern.test(cmd)) continue;
    if (excludePatterns.some(pattern => pattern.test(cmd))) continue;
    
    orphaned.push({
      pid,
      cmd: sanitizeCommand(cmd),
      cwd: resolveCwd(pid),
      started: resolveStarted(pid),
    });
  }
  
  console.log(JSON.stringify({
    orphaned,
    ts: new Date().toISOString(),
  }));
}

main();
