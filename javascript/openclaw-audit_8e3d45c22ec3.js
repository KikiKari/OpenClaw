#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "a6c8266a3fbe2da7f4dbfef8e593b607be7e9d5c1277309a254b2fb2eb85f6ce", "source_sha256": "e51b94641336291974fe14bf4bb7299a75ec7dcce49e1d413282c8043e9f09f1", "target_language": "javascript"}
// openclaw-audit.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:scripts/openclaw-audit.sh
// auch in: OpenClaw@gateway2:scripts/openclaw-audit.sh
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

// OpenClaw read-only audit/diagnostic sweep
// Output: openclaw-audit-YYYY-MM-DD.log im selben Verzeichnis wie dieses Script

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const SCRIPT_DIR = path.dirname(process.argv[1]);
const DATE_STAMP = new Date().toISOString().slice(0, 10);
const OUT = path.join(SCRIPT_DIR, `openclaw-audit-${DATE_STAMP}.log`);

const OC = ['openclaw', '--no-color'];

function writeHeader() {
  const header = `================================================================
OpenClaw audit run
Started:  ${new Date().toISOString()}
Host:     ${require('os').hostname()}
User:     ${require('os').userInfo().username}
Version:  ${(function() {
  try {
    const result = spawnSync('openclaw', ['--version'], { encoding: 'utf8' });
    return result.stdout.trim() || 'unknown';
  } catch (e) {
    return 'unknown';
  }
})()}
Output:   ${OUT}
================================================================\n`;
  
  fs.writeFileSync(OUT, header);
}

function runCmd(title, ...cmd) {
  const timestamp = new Date().toISOString();
  const commandLine = cmd.join(' ');
  
  const output = `\n----------------------------------------------------------------
### ${title}
### $ ${commandLine}
### ${timestamp}
----------------------------------------------------------------\n`;
  
  fs.appendFileSync(OUT, output);
  
  try {
    const result = spawnSync(cmd[0], cmd.slice(1), { encoding: 'utf8' });
    fs.appendFileSync(OUT, result.stdout + result.stderr);
    fs.appendFileSync(OUT, `[exit: ${result.status}]\n`);
  } catch (error) {
    fs.appendFileSync(OUT, `[error: ${error.message}]\n`);
  }
}

function writeFooter() {
  const footer = `\n================================================================
Audit complete: ${new Date().toISOString()}
================================================================\n`;
  
  fs.appendFileSync(OUT, footer);
}

writeHeader();

runCmd("tasks audit --severity error", ...OC, "tasks", "audit", "--severity", "error");
runCmd("secrets audit", ...OC, "secrets", "audit");
runCmd("security audit", ...OC, "security", "audit");
runCmd("plugins doctor", ...OC, "plugins", "doctor");
runCmd("plugins deps", ...OC, "plugins", "deps");
runCmd("plugins registry", ...OC, "plugins", "registry");
runCmd("skills check", ...OC, "skills", "check");
runCmd("hooks check", ...OC, "hooks", "check");
runCmd("gateway status --deep", ...OC, "gateway", "status", "--deep");
runCmd("channels status --probe", ...OC, "channels", "status", "--probe");
runCmd("memory status --deep", ...OC, "memory", "status", "--deep");
runCmd("sessions --all-agents", ...OC, "sessions", "--all-agents");
runCmd("tasks list", ...OC, "tasks", "list");
runCmd("cron list", ...OC, "cron", "list");

writeFooter();

console.log(`Audit complete. Output: ${OUT}`);
