#!/usr/bin/env python3
# abstractions-manager.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway2:scripts/abstractions-manager.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import subprocess
import sys
import os

def main():
    """Execute the abstractions manager cron script with provided arguments."""
    script_path = "/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh"
    
    # Execute the script with all passed arguments
    try:
        result = subprocess.run([script_path] + sys.argv[1:], 
                              check=True, 
                              capture_output=False)
    except subprocess.CalledProcessError as e:
        sys.exit(e.returncode)
    except FileNotFoundError:
        print(f"Error: Script not found at {script_path}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
