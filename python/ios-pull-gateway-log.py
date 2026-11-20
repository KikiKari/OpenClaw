#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "9c4b5835cfe047ee196ae85c3b140f4a7567b2b79e9de9a0a8457df34cbe94b6", "source_sha256": "994170e8e95ae7e8bd7564512b31b67821e81c5b77b3b9fd41bad3d0fc2ee46c", "target_language": "python"}
# ios-pull-gateway-log.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/dev/ios-pull-gateway-log.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

import subprocess
import sys
import os

def main():
    # Set default values for arguments
    DEVICE_UDID = "00008130-000630CE0146001C"
    BUNDLE_ID = "ai.openclaw.ios.dev.mariano.test"
    DEST = "/tmp/openclaw-gateway.log"
    
    # Override defaults with command line arguments if provided
    if len(sys.argv) > 1:
        DEVICE_UDID = sys.argv[1]
    if len(sys.argv) > 2:
        BUNDLE_ID = sys.argv[2]
    if len(sys.argv) > 3:
        DEST = sys.argv[3]
    
    # Execute the xcrun command to copy the log file from the device
    subprocess.run([
        "xcrun", "devicectl", "device", "copy", "from",
        "--device", DEVICE_UDID,
        "--domain-type", "appDataContainer",
        "--domain-identifier", BUNDLE_ID,
        "--source", "Documents/openclaw-gateway.log",
        "--destination", DEST
    ], check=True, stdout=subprocess.DEVNULL)
    
    # Print confirmation message
    print(f"Pulled to: {DEST}")
    
    # Show last 200 lines of the copied file
    with open(DEST, 'r') as f:
        lines = f.readlines()
        # Print last 200 lines (or all lines if less than 200)
        for line in lines[-200:]:
            print(line, end='')

if __name__ == "__main__":
    main()
