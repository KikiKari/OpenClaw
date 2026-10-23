#!/usr/bin/env python3
# wait-for-text.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:skills/tmux/scripts/wait-for-text.sh
# auch in: OpenClaw@gateway2:skills/tmux/scripts/wait-for-text.sh
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

import argparse
import subprocess
import time
import sys
import re
from datetime import datetime, timedelta

def usage():
    """Show usage information"""
    print("""
Usage: wait-for-text.py -t target -p pattern [options]

Poll a tmux pane for text and exit when found.

Options:
  -t, --target    tmux target (session:window.pane), required
  -p, --pattern   regex pattern to look for, required
  -F, --fixed     treat pattern as a fixed string (grep -F)
  -T, --timeout   seconds to wait (integer, default: 15)
  -i, --interval  poll interval in seconds (default: 0.5)
  -l, --lines     number of history lines to inspect (integer, default: 1000)
  -h, --help      show this help
""")

def main():
    parser = argparse.ArgumentParser(add_help=False, usage=argparse.SUPPRESS)
    parser.add_argument('-t', '--target', required=True)
    parser.add_argument('-p', '--pattern', required=True)
    parser.add_argument('-F', '--fixed', action='store_true')
    parser.add_argument('-T', '--timeout', type=int, default=15)
    parser.add_argument('-i', '--interval', type=float, default=0.5)
    parser.add_argument('-l', '--lines', type=int, default=1000)
    parser.add_argument('-h', '--help', action='store_true')

    try:
        args = parser.parse_args()
    except SystemExit:
        usage()
        sys.exit(1)

    if args.help:
        usage()
        sys.exit(0)

    target = args.target
    pattern = args.pattern
    grep_flag = args.fixed
    timeout = args.timeout
    interval = args.interval
    lines = args.lines

    # Validate timeout is integer
    if not isinstance(timeout, int) or timeout < 0:
        print("timeout must be an integer number of seconds", file=sys.stderr)
        sys.exit(1)

    # Validate lines is integer
    if not isinstance(lines, int) or lines < 0:
        print("lines must be an integer", file=sys.stderr)
        sys.exit(1)

    # Check if tmux exists
    if not subprocess.run(['which', 'tmux'], capture_output=True).returncode == 0:
        print("tmux not found in PATH", file=sys.stderr)
        sys.exit(1)

    # End time in epoch seconds
    start_time = datetime.now()
    deadline = start_time + timedelta(seconds=timeout)

    while True:
        # Capture pane content
        try:
            result = subprocess.run(
                ['tmux', 'capture-pane', '-p', '-J', '-t', target, '-S', f'-{lines}'],
                capture_output=True,
                text=True,
                check=True
            )
            pane_text = result.stdout
        except subprocess.CalledProcessError:
            pane_text = ""

        # Check for pattern
        found = False
        if grep_flag:  # Fixed string search
            if pattern in pane_text:
                found = True
        else:  # Regex search
            try:
                if re.search(pattern, pane_text):
                    found = True
            except re.error:
                print(f"Invalid regex pattern: {pattern}", file=sys.stderr)
                sys.exit(1)

        if found:
            sys.exit(0)

        now = datetime.now()
        if now >= deadline:
            print(f"Timed out after {timeout}s waiting for pattern: {pattern}", file=sys.stderr)
            print(f"Last {lines} lines from {target}:", file=sys.stderr)
            print(pane_text, file=sys.stderr)
            sys.exit(1)

        time.sleep(interval)

if __name__ == '__main__':
    main()
