#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "873734d5e68e7a46ffa8103ae2da3b353d6b83fd359144dc4366b1f0c074d8c3", "source_sha256": "74168ccc75bdca2481fb7bf1298fad30cea4e5fdd917205e7f1815e86948ca0c", "target_language": "python"}
# ios-beta-release.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-release.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
from pathlib import Path

def usage():
    print("""
Usage:
  scripts/ios-beta-release.sh [--build-number 7]

Archives and uploads a beta-release IPA to TestFlight locally.
""", file=sys.stderr)

def main():
    build_number = os.environ.get("IOS_BETA_BUILD_NUMBER", "")
    root_dir = Path(__file__).parent.parent.resolve()
    
    # Parse command line arguments
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--":
            i += 1
            continue
        elif args[i] == "--build-number":
            if i + 1 < len(args):
                build_number = args[i + 1]
                i += 2
            else:
                print("Error: --build-number requires a value", file=sys.stderr)
                usage()
                sys.exit(1)
        elif args[i] in ("-h", "--help"):
            usage()
            sys.exit(0)
        else:
            print(f"Unknown argument: {args[i]}", file=sys.stderr)
            usage()
            sys.exit(1)
    
    # Change to iOS app directory and run fastlane
    ios_dir = root_dir / "apps" / "ios"
    env = os.environ.copy()
    env["IOS_BETA_BUILD_NUMBER"] = build_number
    
    try:
        subprocess.run(
            ["fastlane", "ios", "beta"],
            cwd=ios_dir,
            env=env,
            check=True
        )
    except subprocess.CalledProcessError as e:
        sys.exit(e.returncode)
    except FileNotFoundError:
        print("Error: fastlane not found. Please ensure it is installed and in PATH.", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
