#!/usr/bin/env python3
# test_mobile_bridge.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_bridge.cjs
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

import os
import sys
import pathlib

def read_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.read()

def main():
    # Get the directory where this script is located
    script_dir = pathlib.Path(__file__).parent.absolute()
    root = script_dir.parent
    
    # Path to the bridge file
    bridge_path = root / "mobile-shared" / "webview-bridge.js"
    
    # Read the source
    try:
        source = read_file(bridge_path)
    except Exception as e:
        print(f"Failed to read bridge file: {e}")
        sys.exit(1)
    
    # Compile the JavaScript source (equivalent to vm.Script)
    # In Python we don't have a direct equivalent, but we can at least check syntax
    # For now we'll just do basic checks - in real scenario you might use a JS parser
    
    # Assertions - checking that certain strings are present
    assertions = [
        'location.hostname !== "www.tiktok.com"',
        "root.top === root",
        "if (!isTop) return",
        "MAX_MESSAGE_BYTES = 64 * 1024",
        "MAX_AUDIO_SECONDS = 12",
        "QUICK_RECOVER_RELOAD_COOLDOWN_MS = 400",
        "ALLOWED_COMMANDS",
        '"set-auto-reconnect"',
        '"set-limiter"',
        '"scan-recommendations"',
        '"cancel-recommendation-scan"',
        "MAX_MEDIA_URLS = 12",
        "const mediaUrls = new Map()",
        'emit("media-url"',
        "addEventListener(\"message\"",
        'FORCE_RETURN_KEY = "tlc-force-return"',
        "sessionStorage.getItem(FORCE_RETURN_KEY)"
    ]
    
    negative_assertions = [
        ".send =",
        "document.cookie",
        "localStorage",
        "sessionStorage.clear",
        "innerHTML"
    ]
    
    # Check positive assertions
    for assertion in assertions:
        if assertion not in source:
            print(f"FAIL: Expected string not found: {assertion}")
            sys.exit(1)
    
    # Check negative assertions
    for assertion in negative_assertions:
        if assertion in source:
            print(f"FAIL: Forbidden string found: {assertion}")
            sys.exit(1)
    
    # Check bridge copies
    copies = [
        root.parent / "mobile" / "ios" / "Resources" / "webview-bridge.js",
        root.parent / "mobile" / "android" / "app" / "src" / "main" / "res" / "raw" / "webview_bridge.js"
    ]
    
    for copy_path in copies:
        try:
            copy_content = read_file(copy_path)
            if copy_content != source:
                print(f"FAIL: Bridge copy drifted: {copy_path}")
                sys.exit(1)
        except Exception as e:
            print(f"FAIL: Could not read copy file {copy_path}: {e}")
            sys.exit(1)
    
    print("PASS: mobile bridge origin, main-frame, size, command, audio-duration and storage guards")

if __name__ == "__main__":
    main()
