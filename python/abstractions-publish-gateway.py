#!/usr/bin/env python3
# abstractions-publish-gateway.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway2:scripts/abstractions-publish-gateway.sh
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Workspace-visible wrapper for the gateway publish job.
import subprocess
import sys
import os

def main():
    # Define the path to the actual script
    script_path = "/home/openclaw/.openclaw/scripts/abstractions-publish-gateway.sh"
    
    # Check if the script exists
    if not os.path.exists(script_path):
        print(f"Error: Script not found at {script_path}", file=sys.stderr)
        sys.exit(1)
    
    # Execute the script with all passed arguments
    try:
        result = subprocess.run([script_path] + sys.argv[1:])
        sys.exit(result.returncode)
    except FileNotFoundError:
        print(f"Error: Could not execute {script_path}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
