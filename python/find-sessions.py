#!/usr/bin/env python3
# find-sessions.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:skills/tmux/scripts/find-sessions.sh
# auch in: OpenClaw@gateway2:skills/tmux/scripts/find-sessions.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
import argparse
from pathlib import Path

def usage():
    print("""
Usage: find-sessions.sh [-L socket-name|-S socket-path|-A] [-q pattern]

List tmux sessions on a socket (default tmux socket if none provided).

Options:
  -L, --socket       tmux socket name (passed to tmux -L)
  -S, --socket-path  tmux socket path (passed to tmux -S)
  -A, --all          scan all sockets under CLAWDBOT_TMUX_SOCKET_DIR
  -q, --query        case-insensitive substring to filter session names
  -h, --help         show this help
""")

def list_sessions(label, tmux_args, query):
    tmux_cmd = ["tmux"] + tmux_args + ["list-sessions", "-F", "#{session_name}\t#{session_attached}\t#{session_created_string}"]
    
    try:
        result = subprocess.run(tmux_cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"No tmux server found on {label}", file=sys.stderr)
            return False
    except FileNotFoundError:
        print("tmux not found in PATH", file=sys.stderr)
        sys.exit(1)
    
    sessions = result.stdout.strip()
    
    if query:
        lines = sessions.split('\n') if sessions else []
        filtered_lines = []
        for line in lines:
            if query.lower() in line.lower():
                filtered_lines.append(line)
        sessions = '\n'.join(filtered_lines)
    
    if not sessions:
        print(f"No sessions found on {label}")
        return True
    
    print(f"Sessions on {label}:")
    for line in sessions.split('\n'):
        if line.strip():
            parts = line.split('\t')
            if len(parts) >= 3:
                name, attached, created = parts[0], parts[1], parts[2]
                attached_label = "attached" if attached == "1" else "detached"
                print(f"  - {name} ({attached_label}, started {created})")
    return True

def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument('-L', '--socket', dest='socket_name')
    parser.add_argument('-S', '--socket-path', dest='socket_path')
    parser.add_argument('-A', '--all', action='store_true')
    parser.add_argument('-q', '--query')
    parser.add_argument('-h', '--help', action='store_true')
    
    args, unknown = parser.parse_known_args()
    
    if args.help:
        usage()
        sys.exit(0)
    
    if unknown:
        print(f"Unknown option: {unknown[0]}", file=sys.stderr)
        usage()
        sys.exit(1)
    
    socket_name = args.socket_name or ""
    socket_path = args.socket_path or ""
    query = args.query or ""
    scan_all = args.all
    
    if scan_all and (socket_name or socket_path):
        print("Cannot combine --all with -L or -S", file=sys.stderr)
        sys.exit(1)
    
    if socket_name and socket_path:
        print("Use either -L or -S, not both", file=sys.stderr)
        sys.exit(1)
    
    socket_dir = os.environ.get('CLAWDBOT_TMUX_SOCKET_DIR', 
                               os.path.join(os.environ.get('TMPDIR', '/tmp'), 'clawdbot-tmux-sockets'))
    
    if scan_all:
        socket_path_obj = Path(socket_dir)
        if not socket_path_obj.is_dir():
            print(f"Socket directory not found: {socket_dir}", file=sys.stderr)
            sys.exit(1)
        
        sockets = list(socket_path_obj.iterdir())
        
        if not sockets:
            print(f"No sockets found under {socket_dir}", file=sys.stderr)
            sys.exit(1)
        
        exit_code = 0
        for sock in sockets:
            if sock.is_socket():
                if not list_sessions(f"socket path '{sock}'", ['-S', str(sock)], query):
                    exit_code = 1
        sys.exit(exit_code)
    
    tmux_args = []
    socket_label = "default socket"
    
    if socket_name:
        tmux_args.extend(['-L', socket_name])
        socket_label = f"socket name '{socket_name}'"
    elif socket_path:
        tmux_args.extend(['-S', socket_path])
        socket_label = f"socket path '{socket_path}'"
    
    list_sessions(socket_label, tmux_args, query)

if __name__ == "__main__":
    main()
