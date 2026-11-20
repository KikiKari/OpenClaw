#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "9024f522aad0b26aaafa67989788228bed04824c0f8917f5339a94d3a1faa1cd", "source_sha256": "2cdcdc862375b173b06398d139b611f6f002e0435191f56d26d3e48a3cef02cf", "target_language": "python"}
# ios-beta-archive.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/ios-beta-archive.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import subprocess
from pathlib import Path

def usage():
    print('''Usage:
  scripts/ios-beta-archive.sh [--build-number 7]

Archives and exports a beta-release IPA locally without uploading.''', file=sys.stderr)

def main():
    build_number = os.environ.get('IOS_BETA_BUILD_NUMBER', '')
    
    # Get the root directory (parent of the script's directory)
    script_dir = Path(__file__).parent
    root_dir = script_dir.parent.resolve()
    
    # Parse command line arguments
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        arg = args[i]
        if arg == '--':
            i += 1
        elif arg == '--build-number':
            if i + 1 < len(args):
                build_number = args[i + 1]
                i += 2
            else:
                print("Error: --build-number requires a value", file=sys.stderr)
                usage()
                sys.exit(1)
        elif arg in ('-h', '--help'):
            usage()
            sys.exit(0)
        else:
            print(f"Unknown argument: {arg}", file=sys.stderr)
            usage()
            sys.exit(1)
    
    # Change to the iOS app directory and run fastlane
    ios_dir = root_dir / 'apps' / 'ios'
    env = os.environ.copy()
    env['IOS_BETA_BUILD_NUMBER'] = build_number
    
    try:
        subprocess.run(['fastlane', 'ios', 'beta_archive'], 
                      cwd=ios_dir, 
                      env=env, 
                      check=True)
    except subprocess.CalledProcessError as e:
        sys.exit(e.returncode)
    except FileNotFoundError:
        print("Error: fastlane not found. Please ensure it is installed and in PATH.", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
