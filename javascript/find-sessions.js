#!/usr/bin/env node
// find-sessions.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:skills/tmux/scripts/find-sessions.sh
// auch in: OpenClaw@gateway2:skills/tmux/scripts/find-sessions.sh
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

function usage() {
  process.stderr.write(`\
Usage: find-sessions.sh [-L socket-name|-S socket-path|-A] [-q pattern]

List tmux sessions on a socket (default tmux socket if none provided).

Options:
  -L, --socket       tmux socket name (passed to tmux -L)
  -S, --socket-path  tmux socket path (passed to tmux -S)
  -A, --all          scan all sockets under CLAWDBOT_TMUX_SOCKET_DIR
  -q, --query        case-insensitive substring to filter session names
  -h, --help         show this help
`);
}

let socketName = "";
let socketPath = "";
let query = "";
let scanAll = false;
const socketDir = process.env.CLAWDBOT_TMUX_SOCKET_DIR || 
                  (process.env.TMPDIR ? path.join(process.env.TMPDIR, 'clawdbot-tmux-sockets') : '/tmp/clawdbot-tmux-sockets');

const args = process.argv.slice(2);
let i = 0;

while (i < args.length) {
  const arg = args[i];
  
  switch (arg) {
    case '-L':
    case '--socket':
      if (i + 1 >= args.length) {
        process.stderr.write("Option requires an argument: " + arg + "\n");
        usage();
        process.exit(1);
      }
      socketName = args[i + 1];
      i += 2;
      break;
      
    case '-S':
    case '--socket-path':
      if (i + 1 >= args.length) {
        process.stderr.write("Option requires an argument: " + arg + "\n");
        usage();
        process.exit(1);
      }
      socketPath = args[i + 1];
      i += 2;
      break;
      
    case '-A':
    case '--all':
      scanAll = true;
      i++;
      break;
      
    case '-q':
    case '--query':
      if (i + 1 >= args.length) {
        process.stderr.write("Option requires an argument: " + arg + "\n");
        usage();
        process.exit(1);
      }
      query = args[i + 1];
      i += 2;
      break;
      
    case '-h':
    case '--help':
      usage();
      process.exit(0);
      break;
      
    default:
      process.stderr.write("Unknown option: " + arg + "\n");
      usage();
      process.exit(1);
  }
}

if (scanAll && (socketName || socketPath)) {
  process.stderr.write("Cannot combine --all with -L or -S\n");
  process.exit(1);
}

if (socketName && socketPath) {
  process.stderr.write("Use either -L or -S, not both\n");
  process.exit(1);
}

// Check if tmux exists
const tmuxCheck = spawnSync('which', ['tmux'], { encoding: 'utf8' });
if (tmuxCheck.status !== 0) {
  process.stderr.write("tmux not found in PATH\n");
  process.exit(1);
}

function listSessions(label, ...tmuxArgs) {
  const tmuxCmd = ['tmux', ...tmuxArgs, 'list-sessions', '-F', '#{session_name}\t#{session_attached}\t#{session_created_string}'];
  
  const result = spawnSync(tmuxCmd[0], tmuxCmd.slice(1), { encoding: 'utf8' });
  
  if (result.status !== 0) {
    process.stderr.write(`No tmux server found on ${label}\n`);
    return false;
  }
  
  let sessions = result.stdout.trim();
  
  if (query) {
    const lines = sessions.split('\n').filter(line => line.toLowerCase().includes(query.toLowerCase()));
    sessions = lines.join('\n');
  }
  
  if (!sessions) {
    console.log(`No sessions found on ${label}`);
    return true;
  }
  
  console.log(`Sessions on ${label}:`);
  
  sessions.split('\n').forEach(line => {
    if (!line) return;
    const [name, attached, created] = line.split('\t');
    const attachedLabel = attached === "1" ? "attached" : "detached";
    console.log(`  - ${name} (${attachedLabel}, started ${created})`);
  });
  
  return true;
}

if (scanAll) {
  if (!fs.existsSync(socketDir) || !fs.statSync(socketDir).isDirectory()) {
    process.stderr.write(`Socket directory not found: ${socketDir}\n`);
    process.exit(1);
  }
  
  const sockets = fs.readdirSync(socketDir)
    .map(file => path.join(socketDir, file))
    .filter(file => fs.statSync(file).isSocket());
  
  if (sockets.length === 0) {
    process.stderr.write(`No sockets found under ${socketDir}\n`);
    process.exit(1);
  }
  
  let exitCode = 0;
  for (const sock of sockets) {
    if (!listSessions(`socket path '${sock}'`, '-S', sock)) {
      exitCode = 1;
    }
  }
  process.exit(exitCode);
}

const socketLabel = socketName ? `socket name '${socketName}'` : 
                   socketPath ? `socket path '${socketPath}'` : 
                   "default socket";

const tmuxArgs = [];
if (socketName) {
  tmuxArgs.push('-L', socketName);
} else if (socketPath) {
  tmuxArgs.push('-S', socketPath);
}

listSessions(socketLabel, ...tmuxArgs);
