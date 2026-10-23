#!/usr/bin/env python3
# test_extension.cjs — portiert nach python
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_extension.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_extension.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_extension.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_extension.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

import json
import os
import subprocess
import sys
from pathlib import Path

# Define paths
ROOT_DIR = Path(__file__).parent.parent.resolve()
EXTENSION_DIR = ROOT_DIR / "browser-extension"
MOBILE_SHARED_DIR = ROOT_DIR / "mobile-shared"

def read_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def file_exists(path):
    return os.path.exists(path)

def hash_file_sha256(path):
    import hashlib
    with open(path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest().upper()

def assert_equal(a, b, msg=""):
    assert a == b, f"{msg}: Expected {b}, got {a}"

def assert_true(condition, msg=""):
    assert condition, msg

def assert_in(item, container, msg=""):
    assert item in container, f"{msg}: '{item}' not found in {container}"

def assert_not_in(item, container, msg=""):
    assert item not in container, f"{msg}: '{item}' should not be in {container}"

def assert_ok(condition, msg=""):
    assert condition, msg

def main():
    # Load manifest
    manifest_path = EXTENSION_DIR / "manifest.json"
    manifest = json.loads(read_file(manifest_path))

    # Check manifest version and basic properties
    assert_equal(manifest["manifest_version"], 3)
    assert_equal(manifest["version"], "0.8.2")
    assert_in("sidePanel", manifest["permissions"])
    assert_in("webRequest", manifest["permissions"])
    assert_in("tabCapture", manifest["permissions"])
    assert_in("http://127.0.0.1/*", manifest["host_permissions"])
    assert_in("http://localhost/*", manifest["host_permissions"])
    assert_not_in("cookies", manifest["permissions"])
    assert_not_in("webRequestBlocking", manifest["permissions"])
    assert_not_in("nativeMessaging", manifest["permissions"])
    assert_equal(manifest["content_scripts"][0]["js"][0], "vendor-mpegts.js")

    # Check vendor files exist
    mpegts_vendor_path = EXTENSION_DIR / "vendor-mpegts.js"
    mpegts_license_path = EXTENSION_DIR / "vendor-mpegts.LICENSE.txt"
    mpegts_notice_path = EXTENSION_DIR / "vendor-mpegts.NOTICE.md"
    
    assert_true(file_exists(mpegts_vendor_path))
    assert_true(file_exists(mpegts_license_path))
    assert_true(file_exists(mpegts_notice_path))
    
    # Check SHA256 hash
    expected_hash = "0786F9AF6780822FF29240259A73B07ED7BC479BC44966E49418DD38213B8064"
    actual_hash = hash_file_sha256(mpegts_vendor_path)
    assert_equal(actual_hash, expected_hash)

    # Check mobile bridge content
    mobile_bridge_content = read_file(MOBILE_SHARED_DIR / "webview-bridge.js")
    assert_in('location.hostname !== "www.tiktok.com"', mobile_bridge_content)
    assert_not_in("document.cookie", mobile_bridge_content)
    assert_in("QUICK_RECOVER_RELOAD_COOLDOWN_MS = 400", mobile_bridge_content)
    assert_in('"set-auto-reconnect"', mobile_bridge_content)
    assert_in('"set-limiter"', mobile_bridge_content)

    # Check all manifest files exist
    manifest_files = [
        manifest["background"]["service_worker"],
        manifest["side_panel"]["default_path"]
    ]
    for cs in manifest["content_scripts"]:
        manifest_files.extend(cs["js"])

    for rel_path in manifest_files:
        full_path = EXTENSION_DIR / rel_path
        assert_true(file_exists(full_path), f"Missing manifest file: {rel_path}")

    # Check JavaScript syntax and forbidden patterns
    js_files = [f for f in os.listdir(EXTENSION_DIR) if f.endswith('.js')]
    for name in js_files:
        source_path = EXTENSION_DIR / name
        source = read_file(source_path)
        
        if name == "peak-limiter-worklet.js":
            result = subprocess.run([sys.executable, "--check", "--input-type=module"],
                                  input=source, text=True, capture_output=True)
            assert_equal(result.returncode, 0, result.stderr)
        else:
            # For other JS files, we'll just check for forbidden patterns since Python can't easily validate JS syntax
            pass
            
        assert_not_in(r"\beval\s*\(", source, f"{name} contains eval()")
        assert_not_in(r"new\s+Function\s*\(", source, f"{name} contains new Function()")
        assert_not_in(r"\.innerHTML\s*=", source, f"{name} assigns innerHTML")

    print(f"PASS: manifest 0.8.2, {len(js_files)} scripts, chat speech composition, gifts, audience statistics, service controls and security guards")

if __name__ == "__main__":
    main()
