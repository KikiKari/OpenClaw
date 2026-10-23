#!/usr/bin/env node
// wait-for-text.sh — portiert nach javascript
// Quelle: shell, OpenClaw@gateway1:skills/tmux/scripts/wait-for-text.sh
// auch in: OpenClaw@gateway2:skills/tmux/scripts/wait-for-text.sh
// Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

const fs = require('fs');
const { spawn, execSync } = require('child_process');

const usage = () => {
  process.stderr.write(`\
Usage: wait-for-text.js -t target -p pattern [options]

Poll a tmux pane for text and exit when found.

Options:
  -t, --target    tmux target (session:window.pane), required
  -p, --pattern   regex pattern to look for, required
  -F, --fixed     treat pattern as a fixed string (grep -F)
  -T, --timeout   seconds to wait (integer, default: 15)
  -i, --interval  poll interval in seconds (default: 0.5)
  -l, --lines     number of history lines to inspect (integer, default: 1000)
  -h, --help      show this help
`);
};

let target = "";
let pattern = "";
let grepFlag = "-E";
let timeout = 15;
let interval = 0.5;
let lines = 1000;

const args = process.argv.slice(2);
for (let i = 0; i < args.length; i++) {
  switch (args[i]) {
    case '-t':
    case '--target':
      target = args[++i] || "";
      break;
    case '-p':
    case '--pattern':
      pattern = args[++i] || "";
      break;
    case '-F':
    case '--fixed':
      grepFlag = "-F";
      break;
    case '-T':
    case '--timeout':
      timeout = parseInt(args[++i]) || timeout;
      break;
    case '-i':
    case '--interval':
      interval = parseFloat(args[++i]) || interval;
      break;
    case '-l':
    case '--lines':
      lines = parseInt(args[++i]) || lines;
      break;
    case '-h':
    case '--help':
      usage();
      process.exit(0);
    default:
      process.stderr.write(`Unknown option: ${args[i]}\n`);
      usage();
      process.exit(1);
  }
}

if (!target || !pattern) {
  process.stderr.write("target and pattern are required\n");
  usage();
  process.exit(1);
}

if (!Number.isInteger(timeout)) {
  process.stderr.write("timeout must be an integer number of seconds\n");
  process.exit(1);
}

if (!Number.isInteger(lines)) {
  process.stderr.write("lines must be an integer\n");
  process.exit(1);
}

// Check if tmux is available
try {
  execSync('which tmux', { stdio: 'ignore' });
} catch (error) {
  process.stderr.write("tmux not found in PATH\n");
  process.exit(1);
}

const startTime = Math.floor(Date.now() / 1000);
const deadline = startTime + timeout;

const checkPattern = (text, pattern, isFixed) => {
  if (isFixed) {
    return text.includes(pattern);
  } else {
    const regex = new RegExp(pattern);
    return regex.test(text);
  }
};

const poll = () => {
  const pollInterval = setInterval(() => {
    try {
      // -J joins wrapped lines, -S uses negative index to read last N lines
      const tmux = spawn('tmux', ['capture-pane', '-p', '-J', '-t', target, `-S`, `-${lines}`]);
      
      let paneText = '';
      tmux.stdout.on('data', (data) => {
        paneText += data.toString();
      });

      tmux.on('close', (code) => {
        if (checkPattern(paneText, pattern, grepFlag === "-F")) {
          clearInterval(pollInterval);
          process.exit(0);
        }

        const now = Math.floor(Date.now() / 1000);
        if (now >= deadline) {
          clearInterval(pollInterval);
          process.stderr.write(`Timed out after ${timeout}s waiting for pattern: ${pattern}\n`);
          process.stderr.write(`Last ${lines} lines from ${target}:\n`);
          process.stderr.write(paneText);
          process.exit(1);
        }
      });

      tmux.on('error', (error) => {
        clearInterval(pollInterval);
        process.exit(1);
      });
    } catch (error) {
      clearInterval(pollInterval);
      process.exit(1);
    }
  }, interval * 1000);
};

poll();
