#!/usr/bin/env node
// openclaw-audit.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/openclaw-audit.sh
// auch in: OpenClaw@gateway2:scripts/openclaw-audit.sh
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

// OpenClaw read-only audit/diagnostic sweep
// Output: openclaw-audit-YYYY-MM-DD.log im selben Verzeichnis wie dieses Script

import { spawnSync } from 'child_process';
import { writeFileSync, appendFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { hostname } from 'os';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const DATE_STAMP = new Date().toISOString().slice(0, 10);
const OUT = join(__dirname, `openclaw-audit-${DATE_STAMP}.log`);

const OC = ['openclaw', '--no-color'];

const runCommand = (command, ...args) => {
  const result = spawnSync(command, args, { encoding: 'utf8' });
  return {
    stdout: result.stdout,
    stderr: result.stderr,
    status: result.status,
    error: result.error
  };
};

const writeHeader = () => {
  const header = [
    "================================================================",
    "OpenClaw audit run",
    `Started:  ${new Date().toISOString()}`,
    `Host:     ${hostname()}`,
    `User:     ${process.env.USER || process.env.USERNAME || 'unknown'}`,
    `Version:  ${(runCommand('openclaw', '--version').stdout || 'unknown').trim()}`,
    `Output:   ${OUT}`,
    "================================================================\n"
  ].join('\n');
  
  writeFileSync(OUT, header);
};

const run_cmd = (title, ...cmd) => {
  const timestamp = new Date().toISOString();
  const commandLine = cmd.join(' ');
  
  const output = [
    "----------------------------------------------------------------",
    `### ${title}`,
    `### $ ${commandLine}`,
    `### ${timestamp}`,
    "----------------------------------------------------------------"
  ].join('\n') + '\n';
  
  appendFileSync(OUT, `\n${output}`);
  
  try {
    const result = spawnSync(cmd[0], cmd.slice(1), { 
      encoding: 'utf8',
      maxBuffer: 1024 * 1024 * 10 // 10MB buffer
    });
    
    if (result.stdout) {
      appendFileSync(OUT, result.stdout);
    }
    if (result.stderr) {
      appendFileSync(OUT, result.stderr);
    }
    
    const exitCode = result.status !== null ? result.status : (result.error ? 1 : 0);
    appendFileSync(OUT, `[exit: ${exitCode}]\n`);
  } catch (error) {
    appendFileSync(OUT, `[error: ${error.message}]\n`);
  }
};

writeHeader();

run_cmd("tasks audit --severity error", ...OC, "tasks", "audit", "--severity", "error");
run_cmd("secrets audit", ...OC, "secrets", "audit");
run_cmd("security audit", ...OC, "security", "audit");
run_cmd("plugins doctor", ...OC, "plugins", "doctor");
run_cmd("plugins deps", ...OC, "plugins", "deps");
run_cmd("plugins registry", ...OC, "plugins", "registry");
run_cmd("skills check", ...OC, "skills", "check");
run_cmd("hooks check", ...OC, "hooks", "check");
run_cmd("gateway status --deep", ...OC, "gateway", "status", "--deep");
run_cmd("channels status --probe", ...OC, "channels", "status", "--probe");
run_cmd("memory status --deep", ...OC, "memory", "status", "--deep");
run_cmd("sessions --all-agents", ...OC, "sessions", "--all-agents");
run_cmd("tasks list", ...OC, "tasks", "list");
run_cmd("cron list", ...OC, "cron", "list");

const footer = [
  "",
  "================================================================",
  `Audit complete: ${new Date().toISOString()}`,
  "================================================================"
].join('\n') + '\n';

appendFileSync(OUT, footer);

console.log(`Audit complete. Output: ${OUT}`);
