#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "cad67d5dfbdd75a20b8078784e7412a7725b75b7b77527878189d75b3e842464", "source_sha256": "fe4cfd779f66ea7706f9bdfe3744e5d0a5b102609de3aca3ad086e40c76e8a2f", "target_language": "python"}
# build-and-run-mac.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/build-and-run-mac.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import os
import subprocess
import sys
import time

def main():
    # Change to the correct directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    os.chdir(os.path.join(script_dir, "../apps/macos"))

    BUILD_PATH = ".build-local"
    PRODUCT = "OpenClaw"
    BIN = os.path.join(BUILD_PATH, "debug", PRODUCT)

    print(f"\n▶️  Building {PRODUCT} (debug, build path: {BUILD_PATH})")
    subprocess.run(["swift", "build", "-c", "debug", "--product", PRODUCT, "--build-path", BUILD_PATH], check=True)

    print(f"\n⏹  Stopping existing {PRODUCT}...")
    try:
        subprocess.run(["killall", "-q", PRODUCT], check=True)
    except subprocess.CalledProcessError:
        # Ignore errors if the process is not running
        pass

    print(f"\n🚀 Launching {BIN} ...")
    
    # Open log file
    with open("/tmp/openclaw.log", "w") as log_file:
        # Start the process
        process = subprocess.Popen([BIN], stdout=log_file, stderr=subprocess.STDOUT)
        PID = process.pid
        print(f"Started {PRODUCT} (PID {PID}). Logs: /tmp/openclaw.log")

if __name__ == "__main__":
    main()
