#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "0f100fe8879b3f3b262b2040b572963cad12336f62e70aa14af6d53e1e21ce2b", "source_sha256": "4c4552ce0adb2754080969f00b761c1c118766771e0595b8c9b416ee0842fbae", "target_language": "javascript"}
// find-sessions.sh — portiert nach javascript
// Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/tmux/scripts/find-sessions.sh
// Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const { spawnSync } = require('child_process');
const path = require('path');

const usage = () => {
  process.stdout.write(`Usage: find-sessions.sh [-L socket-name|-S socket-path|-A] [-q pattern]

List tmux sessions on a socket (default tmux socket if none provided).

Options:
  -L, --socket       tmux socket name (passed to tmux -L)
  -S, --socket-path  tmux socket path (passed to tmux -S)
  -A, --all          scan all sockets under OPENCLAW_TMUX_SOCKET_DIR
  -q, --query        case-insensitive substring to filter session names
  -h, --help         show this help
`);
};

let socketName = "";
let socketPath = "";
let query = "";
let scanAll = false;
const socketDir = process.env.OPENCLAW_TMUX_SOCKET_DIR || 
                 (process.env.TMPDIR || '/tmp') + '/openclaw-tmux-sockets';

const args = process.argv.slice(2);
let i = 0;

while (i < args.length) {
  const arg = args[i];
  
  switch (arg) {
    case '-L':
    case '--socket':
      if (i + 1 >= args.length) {
        console.error("Option requires an argument: " + arg);
        usage();
        process.exit(1);
      }
      socketName = args[i + 1];
      i += 2;
      break;
      
    case '-S':
    case '--socket-path':
      if (i + 1 >= args.length) {
        console.error("Option requires an argument: " + arg);
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
        console.error("Option requires an argument: " + arg);
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
      console.error("Unknown option: " + arg);
      usage();
      process.exit(1);
      break;
  }
}

if (scanAll && (socketName !== "" || socketPath !== "")) {
  console.error("Cannot combine --all with -L or -S");
  process.exit(1);
}

if (socketName !== "" && socketPath !== "") {
  console.error("Use either -L or -S, not both");
  process.exit(1);
}

// Check if tmux exists
const tmuxCheck = spawnSync('which', ['tmux'], { stdio: 'pipe' });
if (tmuxCheck.status !== 0) {
  console.error("tmux not found in PATH");
  process.exit(1);
}

const listSessions = (label, tmuxArgs) => {
  const tmuxCmd = ['tmux', ...tmuxArgs, 'list-sessions', '-F', '#{session_name}\t#{session_attached}\t#{session_created_string}'];
  
  const result = spawnSync(tmuxCmd[0], tmuxCmd.slice(1), { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] });
  
  if (result.status !== 0) {
    console.error("No tmux server found on " + label);
    return false;
  }
  
  let sessions = result.stdout.trim();
  
  if (query !== "") {
    const lines = sessions.split('\n').filter(line => line.toLowerCase().includes(query.toLowerCase()));
    sessions = lines.join('\n');
  }
  
  if (sessions === "") {
    console.log("No sessions found on " + label);
    return true;
  }
  
  console.log("Sessions on " + label + ":");
  
  sessions.split('\n').forEach(line => {
    if (line.trim() === '') return;
    
    const [name, attached, created] = line.split('\t');
    const attachedLabel = (attached === "1") ? "attached" : "detached";
    console.log(`  - ${name} (${attachedLabel}, started ${created})`);
  });
  
  return true;
};

if (scanAll) {
  if (!fs.existsSync(socketDir) || !fs.statSync(socketDir).isDirectory()) {
    console.error("Socket directory not found: " + socketDir);
    process.exit(1);
  }
  
  const files = fs.readdirSync(socketDir);
  const sockets = files.map(file => path.join(socketDir, file))
                      .filter(file => fs.existsSync(file) && fs.statSync(file).isSocket());
  
  if (sockets.length === 0) {
    console.error("No sockets found under " + socketDir);
    process.exit(1);
  }
  
  let exitCode = 0;
  for (const sock of sockets) {
    if (!listSessions("socket path '" + sock + "'", ['-S', sock])) {
      exitCode = 1;
    }
  }
  
  process.exit(exitCode);
}

let tmuxArgs = [];
let socketLabel = "default socket";

if (socketName !== "") {
  tmuxArgs = ['-L', socketName];
  socketLabel = "socket name '" + socketName + "'";
} else if (socketPath !== "") {
  tmuxArgs = ['-S', socketPath];
  socketLabel = "socket path '" + socketPath + "'";
}

listSessions(socketLabel, tmuxArgs);
