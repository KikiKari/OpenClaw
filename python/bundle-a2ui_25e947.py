#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "3afcf88a969db4138d89dc9cd20b6a0798bb76ac38bce38449be121643f561aa", "source_sha256": "25e94789e3af346018b091c7c4d6d65632394c19fcf9eaaeac876efbe534149a", "target_language": "python"}
# bundle-a2ui.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess

# Get the root directory (parent of the script's directory)
script_dir = os.path.dirname(os.path.abspath(__file__))
root_dir = os.path.join(script_dir, "..")

# Execute the Node.js script with all arguments passed to this script
node_script = os.path.join(root_dir, "scripts", "bundle-a2ui.mjs")
subprocess.run(["node", node_script] + sys.argv[1:], check=True)
