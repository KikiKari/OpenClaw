#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "f2769ce670abd1982e5fbbfdfb9fb7a1c4c0faef2b60f28df26cd9a147fedca3", "source_sha256": "4c4552ce0adb2754080969f00b761c1c118766771e0595b8c9b416ee0842fbae", "target_language": "python"}
# find-sessions.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/tmux/scripts/find-sessions.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

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
  -A, --all          scan all sockets under OPENCLAW_TMUX_SOCKET_DIR
  -q, --query        case-insensitive substring to filter session names
  -h, --help         show this help
""")

def list_sessions(label, tmux_cmd, query):
    try:
        result = subprocess.run(
            tmux_cmd + ["list-sessions", "-F", "#{session_name}\t#{session_attached}\t#{session_created_string}"],
            capture_output=True,
            text=True,
            check=True
        )
        sessions = result.stdout.strip()
    except subprocess.CalledProcessError:
        print(f"No tmux server found on {label}", file=sys.stderr)
        return False

    if query:
        filtered_lines = []
        for line in sessions.split('\n'):
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
    parser = argparse.ArgumentParser(add_help=False, usage=argparse.SUPPRESS)
    parser.add_argument('-L', '--socket', dest='socket_name')
    parser.add_argument('-S', '--socket-path', dest='socket_path')
    parser.add_argument('-A', '--all', action='store_true', dest='scan_all')
    parser.add_argument('-q', '--query', dest='query')
    parser.add_argument('-h', '--help', action='store_true', dest='show_help')

    args, unknown = parser.parse_known_args()

    if args.show_help:
        usage()
        sys.exit(0)

    if unknown:
        print(f"Unknown option: {unknown[0]}", file=sys.stderr)
        usage()
        sys.exit(1)

    socket_name = args.socket_name or ""
    socket_path = args.socket_path or ""
    query = args.query or ""
    scan_all = args.scan_all

    socket_dir = os.environ.get('OPENCLAW_TMUX_SOCKET_DIR', 
                               os.path.join(os.environ.get('TMPDIR', '/tmp'), 'openclaw-tmux-sockets'))

    if scan_all and (socket_name or socket_path):
        print("Cannot combine --all with -L or -S", file=sys.stderr)
        sys.exit(1)

    if socket_name and socket_path:
        print("Use either -L or -S, not both", file=sys.stderr)
        sys.exit(1)

    if not shutil.which('tmux'):
        print("tmux not found in PATH", file=sys.stderr)
        sys.exit(1)

    if scan_all:
        socket_path_obj = Path(socket_dir)
        if not socket_path_obj.is_dir():
            print(f"Socket directory not found: {socket_dir}", file=sys.stderr)
            sys.exit(1)

        sockets = list(socket_path_obj.glob('*'))
        if not sockets:
            print(f"No sockets found under {socket_dir}", file=sys.stderr)
            sys.exit(1)

        exit_code = 0
        for sock in sockets:
            if sock.is_socket():
                if not list_sessions(f"socket path '{sock}'", ['tmux', '-S', str(sock)], query):
                    exit_code = 1
        sys.exit(exit_code)

    tmux_cmd = ['tmux']
    socket_label = "default socket"

    if socket_name:
        tmux_cmd.extend(['-L', socket_name])
        socket_label = f"socket name '{socket_name}'"
    elif socket_path:
        tmux_cmd.extend(['-S', socket_path])
        socket_label = f"socket path '{socket_path}'"

    list_sessions(socket_label, tmux_cmd[1:], query)

if __name__ == '__main__':
    import shutil
    main()
