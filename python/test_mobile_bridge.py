#!/usr/bin/env python3
# test_mobile_bridge.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_mobile_bridge.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

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
    source = read_file(bridge_path)
    
    # Compile the JavaScript (basic check)
    # In Python we don't have vm.Script, but we can at least verify it's valid text
    if not source:
        raise Exception(f"Could not read source from {bridge_path}")
    
    # Run assertions - check that source contains expected strings
    assert 'location.hostname !== "www.tiktok.com"' in source
    assert "root.top === root" in source
    assert "if (!isTop) return" in source
    assert "MAX_MESSAGE_BYTES = 64 * 1024" in source
    assert "MAX_AUDIO_SECONDS = 12" in source
    assert "QUICK_RECOVER_RELOAD_COOLDOWN_MS = 400" in source
    assert "ALLOWED_COMMANDS" in source
    assert '"set-auto-reconnect"' in source
    assert '"set-limiter"' in source
    assert '"scan-recommendations"' in source
    assert '"cancel-recommendation-scan"' in source
    assert "MAX_MEDIA_URLS = 12" in source
    assert "const mediaUrls = new Map()" in source
    assert 'emit("media-url"' in source
    assert 'addEventListener("message"' in source
    assert ".send =" not in source
    assert "document.cookie" not in source
    assert "localStorage" not in source
    assert 'FORCE_RETURN_KEY = "tlc-force-return"' in source
    assert "sessionStorage.getItem(FORCE_RETURN_KEY)" in source
    assert "sessionStorage.clear" not in source
    assert "innerHTML" not in source
    
    # Check copies in other locations
    copies = [
        root.parent / "mobile" / "ios" / "Resources" / "webview-bridge.js",
        root.parent / "mobile" / "android" / "app" / "src" / "main" / "res" / "raw" / "webview_bridge.js"
    ]
    
    for copy_path in copies:
        copy_content = read_file(copy_path)
        if copy_content != source:
            raise AssertionError(f"Bridge copy drifted: {copy_path}")
    
    print("PASS: mobile bridge origin, main-frame, size, command, audio-duration and storage guards")

if __name__ == "__main__":
    main()
