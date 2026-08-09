#!/usr/bin/env python3
# abstractions-manager.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway2:scripts/abstractions-manager.sh
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

import sys
import os
import subprocess

def main():
    """Execute the abstractions manager cron script with passed arguments."""
    script_path = "/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh"
    
    # Execute the script with all passed arguments
    try:
        result = subprocess.run([script_path] + sys.argv[1:], 
                              check=True, 
                              stdout=subprocess.PIPE, 
                              stderr=subprocess.PIPE)
        sys.stdout.buffer.write(result.stdout)
        sys.stderr.buffer.write(result.stderr)
        sys.exit(result.returncode)
    except subprocess.CalledProcessError as e:
        sys.stderr.buffer.write(e.stderr)
        sys.exit(e.returncode)
    except FileNotFoundError:
        sys.stderr.write(f"Error: Script not found at {script_path}\n")
        sys.exit(127)

if __name__ == "__main__":
    main()
