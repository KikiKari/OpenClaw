#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "c64f77bcd71d5eceeebbc197e84b1f578cd08133964a305fe66eb5a36e40e5e1", "source_sha256": "a137d03b3b37332439a1592831d60479ff86315c7e6d6ed7da0fb799db0f13f7", "target_language": "javascript"}
// find-sessions.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:skills/tmux/scripts/find-sessions.sh
// auch in: OpenClaw@gateway2:skills/tmux/scripts/find-sessions.sh
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

function usage() {
  process.stderr.write(`Usage: find-sessions.js [-L socket-name|-S socket-path|-A] [-q pattern]

List tmux sessions on a socket (default tmux socket if none provided).

Options:
  -L, --socket       tmux socket name (passed to tmux -L)
  -S, --socket-path  tmux socket path (passed to tmux -S)
  -A, --all          scan all sockets under CLAWDBOT_TMUX_SOCKET_DIR
  -q, --query        case-insensitive substring to filter session names
  -h, --help         show this help
`);
}

function listSessions(label, ...tmuxArgs) {
  const tmuxCmd = ['tmux', ...tmuxArgs];
  
  const result = spawnSync(tmuxCmd[0], [...tmuxCmd.slice(1), 'list-sessions', '-F', '#{session_name}\t#{session_attached}\t#{session_created_string}'], {
    encoding: 'utf8',
    stdio: ['pipe', 'pipe', 'pipe']
  });

  if (result.status !== 0) {
    console.error(`No tmux server found on ${label}`);
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
    if (line.trim()) {
      const [name, attached, created] = line.split('\t');
      const attachedLabel = (attached === '1') ? 'attached' : 'detached';
      console.log(`  - ${name} (${attachedLabel}, started ${created})`);
    }
  });
  
  return true;
}

let socketName = '';
let socketPath = '';
let query = '';
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
      socketName = args[i + 1] || '';
      i += 2;
      break;
    case '-S':
    case '--socket-path':
      socketPath = args[i + 1] || '';
      i += 2;
      break;
    case '-A':
    case '--all':
      scanAll = true;
      i++;
      break;
    case '-q':
    case '--query':
      query = args[i + 1] || '';
      i += 2;
      break;
    case '-h':
    case '--help':
      usage();
      process.exit(0);
      break;
    default:
      console.error(`Unknown option: ${arg}`);
      usage();
      process.exit(1);
  }
}

if (scanAll && (socketName || socketPath)) {
  console.error('Cannot combine --all with -L or -S');
  process.exit(1);
}

if (socketName && socketPath) {
  console.error('Use either -L or -S, not both');
  process.exit(1);
}

// Check if tmux exists
const tmuxCheck = spawnSync('which', ['tmux'], { stdio: 'pipe' });
if (tmuxCheck.status !== 0) {
  console.error('tmux not found in PATH');
  process.exit(1);
}

if (scanAll) {
  if (!fs.existsSync(socketDir) || !fs.statSync(socketDir).isDirectory()) {
    console.error(`Socket directory not found: ${socketDir}`);
    process.exit(1);
  }

  const files = fs.readdirSync(socketDir);
  const sockets = files.map(file => path.join(socketDir, file)).filter(file => 
    fs.existsSync(file) && fs.statSync(file).isSocket()
  );

  if (sockets.length === 0) {
    console.error(`No sockets found under ${socketDir}`);
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

let socketLabel = 'default socket';
const tmuxArgs = [];

if (socketName) {
  tmuxArgs.push('-L', socketName);
  socketLabel = `socket name '${socketName}'`;
} else if (socketPath) {
  tmuxArgs.push('-S', socketPath);
  socketLabel = `socket path '${socketPath}'`;
}

listSessions(socketLabel, ...tmuxArgs);
