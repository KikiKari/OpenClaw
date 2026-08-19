#!/usr/bin/env python3
# frame.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:skills/video-frames/scripts/frame.sh
# auch in: OpenClaw@gateway2:skills/video-frames/scripts/frame.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

import sys
import os
import subprocess
import argparse
from pathlib import Path

def usage():
    """Print usage information and exit."""
    print("""Usage:
  frame.py <video-file> [--time HH:MM:SS] [--index N] --out /path/to/frame.jpg

Examples:
  frame.py video.mp4 --out /tmp/frame.jpg
  frame.py video.mp4 --time 00:00:10 --out /tmp/frame-10s.jpg
  frame.py video.mp4 --index 0 --out /tmp/frame0.png""", file=sys.stderr)
    sys.exit(2)

def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        usage()

    # Parse arguments manually to maintain exact behavior
    args = sys.argv[1:]
    if not args:
        usage()
    
    in_file = args[0]
    args = args[1:]
    
    time_arg = ""
    index_arg = ""
    out_file = ""
    
    i = 0
    while i < len(args):
        if args[i] == "--time":
            if i + 1 >= len(args):
                print("Missing value for --time", file=sys.stderr)
                usage()
            time_arg = args[i + 1]
            i += 2
        elif args[i] == "--index":
            if i + 1 >= len(args):
                print("Missing value for --index", file=sys.stderr)
                usage()
            index_arg = args[i + 1]
            i += 2
        elif args[i] == "--out":
            if i + 1 >= len(args):
                print("Missing value for --out", file=sys.stderr)
                usage()
            out_file = args[i + 1]
            i += 2
        else:
            print(f"Unknown arg: {args[i]}", file=sys.stderr)
            usage()
    
    if not os.path.isfile(in_file):
        print(f"File not found: {in_file}", file=sys.stderr)
        sys.exit(1)
    
    if not out_file:
        print("Missing --out", file=sys.stderr)
        usage()
    
    # Create output directory
    out_path = Path(out_file)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Build ffmpeg command
    cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"]
    
    if index_arg:
        cmd.extend(["-i", in_file, "-vf", f"select=eq(n\\,{index_arg})", "-vframes", "1", out_file])
    elif time_arg:
        cmd.extend(["-ss", time_arg, "-i", in_file, "-frames:v", "1", out_file])
    else:
        cmd.extend(["-i", in_file, "-vf", "select=eq(n\\,0)", "-vframes", "1", out_file])
    
    # Execute ffmpeg
    try:
        subprocess.run(cmd, check=True, capture_output=True)
    except subprocess.CalledProcessError as e:
        print(f"ffmpeg failed with return code {e.returncode}", file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError:
        print("ffmpeg not found. Please install ffmpeg.", file=sys.stderr)
        sys.exit(1)
    
    print(out_file)

if __name__ == "__main__":
    main()
