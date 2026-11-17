#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "f47059fccede8aa1dea57d31cdc070df3ea4b528a6afc4e9344ddfb81be3d811", "source_sha256": "b339455e9e618c836ccf2e3732e4fec9897f079730d8814eadb716e2459df453", "target_language": "python"}
# frame.sh — portiert nach python
# Quelle: shell, OpenClaw@gateway1:skills/video-frames/scripts/frame.sh
# auch in: OpenClaw@gateway2:skills/video-frames/scripts/frame.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

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
    
    in_file = sys.argv[1]
    
    # Parse arguments manually to match original behavior
    args = sys.argv[2:]
    time_arg = ""
    index_arg = ""
    out_arg = ""
    
    i = 0
    while i < len(args):
        if args[i] == "--time":
            if i + 1 < len(args):
                time_arg = args[i + 1]
                i += 2
            else:
                print("Missing value for --time", file=sys.stderr)
                usage()
        elif args[i] == "--index":
            if i + 1 < len(args):
                index_arg = args[i + 1]
                i += 2
            else:
                print("Missing value for --index", file=sys.stderr)
                usage()
        elif args[i] == "--out":
            if i + 1 < len(args):
                out_arg = args[i + 1]
                i += 2
            else:
                print("Missing value for --out", file=sys.stderr)
                usage()
        else:
            print(f"Unknown arg: {args[i]}", file=sys.stderr)
            usage()
    
    if not os.path.isfile(in_file):
        print(f"File not found: {in_file}", file=sys.stderr)
        sys.exit(1)
    
    if out_arg == "":
        print("Missing --out", file=sys.stderr)
        usage()
    
    # Create output directory
    out_path = Path(out_arg)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Build ffmpeg command based on provided arguments
    cmd = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel", "error",
        "-y"
    ]
    
    if index_arg != "":
        cmd.extend([
            "-i", in_file,
            "-vf", f"select=eq(n\\,{index_arg})",
            "-vframes", "1",
            out_arg
        ])
    elif time_arg != "":
        cmd.extend([
            "-ss", time_arg,
            "-i", in_file,
            "-frames:v", "1",
            out_arg
        ])
    else:
        cmd.extend([
            "-i", in_file,
            "-vf", "select=eq(n\\,0)",
            "-vframes", "1",
            out_arg
        ])
    
    # Execute ffmpeg command
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        sys.exit(e.returncode)
    
    print(out_arg)

if __name__ == "__main__":
    main()
