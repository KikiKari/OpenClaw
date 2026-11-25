#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "eb1c7345640dc59dbbb3c3b37229b6afb9a28bf29bf019365622aadb86dd281f", "source_sha256": "e31da3d72f8d806a159d6709f37f55500c7f16939f04c094f2ab46a959e70c57", "target_language": "python"}
# translation-worker-node5.ps1 — portiert nach python
# Quelle: powershell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node5.ps1
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import argparse
import hashlib
import os
import subprocess
import sys
from pathlib import Path

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['prepare', 'run'], help='Action to perform')
    args = parser.parse_args()

    # Windows does not use chmod. The Python worker and Python 3 must already be
    # installed locally; no credentials are copied or placed on a command line.
    worker = Path.home() / '.openclaw' / 'workers' / 'translation_worker.py'
    expected = '9f8e810dd49f30fbc05064a98faf280d1f2480fdb8f125115ad006d486cd555b'

    if not worker.exists():
        raise SystemExit(f"Worker missing: {worker}")

    if worker.is_symlink():
        raise SystemExit('Worker link rejected')

    with open(worker, 'rb') as f:
        file_hash = hashlib.sha256(f.read()).hexdigest().lower()

    if file_hash != expected:
        raise SystemExit('Worker checksum mismatch')

    python = subprocess.run(['where', 'python.exe'], capture_output=True, text=True, check=True)
    python_path = python.stdout.strip().split('\n')[0]

    if args.action == 'prepare':
        print(f"Worker verified: {worker}")
        return 0

    result = subprocess.run([python_path, str(worker)])
    sys.exit(result.returncode)

if __name__ == '__main__':
    main()
