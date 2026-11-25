#!/usr/bin/env python3.12
# abstraction-provenance: {"artifact_sha256": "730250b869146c73a14037b90620f2c73d6715bf09c4fedb00b9b56bcdfa5391", "source_sha256": "9caa03d9bb15f9d91f7e2672653c8c81852b35f9076edf8b7f839f4f06ac7dfd", "target_language": "python"}
# translation-worker-node.sh — portiert nach python
# Quelle: shell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node.sh
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import sys
import os
import hashlib
import subprocess

# Run on the selected node after transferring its native worker. JSON stdin is
# forwarded unchanged to the worker in run mode.

def main():
    if len(sys.argv) != 3:
        print('Usage: translation-worker-node.py node2|node3|node4|node6 prepare|health|run', file=sys.stderr)
        sys.exit(2)

    node = sys.argv[1]
    action = sys.argv[2]

    # Map nodes to worker path and expected checksum
    node_config = {
        'node2': ('/home/node/.openclaw/workers/translation-worker', '565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286'),
        'node3': ('/home/openclaw/.openclaw/workers/translation-worker', '9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de'),
        'node4': ('/root/.openclaw/workers/translation-worker', '565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286'),
        'node6': ('/home/node/.openclaw/workers/translation-worker', '9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de')
    }

    if node not in node_config:
        print('Unknown or non-POSIX node', file=sys.stderr)
        sys.exit(2)

    worker, expected = node_config[node]

    valid_actions = {'prepare', 'health', 'run'}
    if action not in valid_actions:
        print('Unknown action', file=sys.stderr)
        sys.exit(2)

    # Check if worker exists and is not a symlink
    if not os.path.isfile(worker) or os.path.islink(worker):
        print(f"Missing worker or symlink rejected: {worker}", file=sys.stderr)
        sys.exit(1)

    # Calculate SHA256 checksum
    sha256_hash = hashlib.sha256()
    try:
        with open(worker, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                sha256_hash.update(chunk)
    except Exception as e:
        print(f"Error reading worker file: {e}", file=sys.stderr)
        sys.exit(1)

    actual = sha256_hash.hexdigest()

    if actual != expected:
        print(f"Worker checksum mismatch: {worker}", file=sys.stderr)
        sys.exit(1)

    # Make worker executable
    try:
        os.chmod(worker, os.stat(worker).st_mode | 0o111)
    except Exception as e:
        print(f"Error making worker executable: {e}", file=sys.stderr)
        sys.exit(1)

    if action == 'prepare':
        print(f"Worker verified and executable: {worker}")
    elif action == 'health':
        os.execv(worker, [worker, '--health'])
    elif action == 'run':
        os.execv(worker, [worker])

if __name__ == '__main__':
    main()
