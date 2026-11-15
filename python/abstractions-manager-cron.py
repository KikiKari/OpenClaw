#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "fe1d84e39775e304f4cf8f890e30736945c6816514227c144859524ec2a1904d", "source_sha256": "1b01ca0f5943b16d3905faf557953600ee54f15ecf1dc18c1461585eba94d376", "target_language": "python"}
# abstractions-manager-cron.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:scripts/abstractions-manager-cron.sh
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
import fcntl
from pathlib import Path

def main():
    # Set PATH
    os.environ["PATH"] = "/home/openclaw/.local/bin:/usr/local/bin:/usr/bin:/bin"
    
    # Load environment variables from file
    env_file = Path("/home/openclaw/.openclaw/.env")
    if env_file.exists():
        with open(env_file) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    os.environ[key] = value
    
    # Check required environment variable
    if "OPENROUTER_API_KEY" not in os.environ:
        raise SystemExit("OPENROUTER_API_KEY fehlt")
    
    # Set GITHUB_TOKEN with fallback values
    github_token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN") or os.environ.get("GH_ACCESS_TOKEN")
    if github_token:
        os.environ["GITHUB_TOKEN"] = github_token
    
    # Define paths
    lock_file_path = "/home/openclaw/.openclaw/locks/abstractions-manager.lock"
    script_path = "/home/openclaw/.openclaw/workspace/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py"
    
    # Create lock directory if it doesn't exist
    lock_dir = Path(lock_file_path).parent
    lock_dir.mkdir(parents=True, exist_ok=True)
    
    try:
        # Try to acquire an exclusive lock on the lock file
        with open(lock_file_path, 'w') as lock_file:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            
            # Execute the Python script with all arguments
            result = subprocess.run([
                "/usr/bin/python3",
                script_path
            ] + sys.argv[1:])
            
            sys.exit(result.returncode)
            
    except BlockingIOError:
        # Lock is already held by another process
        print("Another instance is already running", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
