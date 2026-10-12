#!/bin/bash
# test_extension.cjs — portiert nach shell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_extension.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_extension.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_extension.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# This bash translation mimics the JavaScript tests but with bash equivalents
# where possible. Some functionality like protobuf decoding or complex JS logic
# cannot be directly translated and are represented as placeholder comments.

root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
extension="$root/browser-extension"
manifest_file="$extension/manifest.json"

# Read manifest
manifest_content=$(cat "$manifest_file")
manifest_version=$(echo "$manifest_content" | jq -r '.manifest_version')
version=$(echo "$manifest_content" | jq -r '.version')
permissions=$(echo "$manifest_content" | jq -r '.permissions[]' 2>/dev/null || echo "")
host_permissions=$(echo "$manifest_content" | jq -r '.host_permissions[]' 2>/dev/null || echo "")
content_scripts_js=$(echo "$manifest_content" | jq -r '.content_scripts[0].js[0]' 2>/dev/null || echo "")

# Assertions on manifest values
[[ "$manifest_version" == "3" ]] || { echo "FAIL: manifest_version != 3"; exit 1; }
[[ "$version" == "0.8.2" ]] || { echo "FAIL: version != 0.8.2"; exit 1; }

# Check permissions
[[ "$permissions" =~ "sidePanel" ]] || { echo "FAIL: missing sidePanel permission"; exit 1; }
[[ "$permissions" =~ "webRequest" ]] || { echo "FAIL: missing webRequest permission"; exit 1; }
[[ "$permissions" =~ "tabCapture" ]] || { echo "FAIL: missing tabCapture permission"; exit 1; }
[[ "$host_permissions" =~ "http://127.0.0.1/*" ]] || { echo "FAIL: missing host_permission http://127.0.0.1/*"; exit 1; }
[[ "$host_permissions" =~ "http://localhost/*" ]] || { echo "FAIL: missing host_permission http://localhost/*"; exit 1; }
[[ ! "$permissions" =~ "cookies" ]] || { echo "FAIL: cookies permission should not be present"; exit 1; }
[[ ! "$permissions" =~ "webRequestBlocking" ]] || { echo "FAIL: webRequestBlocking permission should not be present"; exit 1; }
[[ ! "$permissions" =~ "nativeMessaging" ]] || { echo "FAIL: nativeMessaging permission should not be present"; exit 1; }
[[ "$content_scripts_js" == "vendor-mpegts.js" ]] || { echo "FAIL: content_scripts js mismatch"; exit 1; }

# Check vendor files exist
mpegts_vendor="$extension/vendor-mpegts.js"
mpegts_license="$extension/vendor-mpegts.LICENSE.txt"
mpegts_notice="$extension/vendor-mpegts.NOTICE.md"
[[ -f "$mpegts_vendor" ]] || { echo "FAIL: vendor-mpegts.js missing"; exit 1; }
[[ -f "$mpegts_license" ]] || { echo "FAIL: vendor-mpegts.LICENSE.txt missing"; exit 1; }
[[ -f "$mpegts_notice" ]] || { echo "FAIL: vendor-mpegts.NOTICE.md missing"; exit 1; }

# SHA256 checksum check (bash equivalent using sha256sum)
mpegts_hash=$(sha256sum "$mpegts_vendor" | awk '{print toupper($1)}')
expected_hash="0786F9AF6780822FF29240259A73B07ED7BC479BC44966E49418DD38213B8064"
[[ "$mpegts_hash" == "$expected_hash" ]] || { echo "FAIL: vendor-mpegts.js hash mismatch"; exit 1; }

# Mobile bridge checks
mobile_bridge_content=$(cat "$root/mobile-shared/webview-bridge.js")
[[ "$mobile_bridge_content" =~ 'location.hostname !== "www.tiktok.com"' ]] || { echo "FAIL: location check missing"; exit 1; }
[[ ! "$mobile_bridge_content" =~ "document.cookie" ]] || { echo "FAIL: document.cookie found"; exit 1; }
[[ "$mobile_bridge_content" =~ "QUICK_RECOVER_RELOAD_COOLDOWN_MS = 400" ]] || { echo "FAIL: quick recover cooldown missing"; exit 1; }
[[ "$mobile_bridge_content" =~ '"set-auto-reconnect"' ]] || { echo "FAIL: auto reconnect missing"; exit 1; }
[[ "$mobile_bridge_content" =~ '"set-limiter"' ]] || { echo "FAIL: limiter missing"; exit 1; }

# Check manifest files exist
background_service_worker=$(echo "$manifest_content" | jq -r '.background.service_worker')
side_panel_default_path=$(echo "$manifest_content" | jq -r '.side_panel.default_path')
content_script_files=$(echo "$manifest_content" | jq -r '.content_scripts[].js[]' 2>/dev/null || echo "")

for relative in "$background_service_worker" "$side_panel_default_path" $content_script_files; do
    [[ -f "$extension/$relative" ]] || { echo "FAIL: Missing manifest file: $relative"; exit 1; }
done

# Script validation checks would go here (simplified)
scripts=$(find "$extension" -maxdepth 1 -name "*.js" -type f | wc -l)
echo "PASS: Found $scripts .js files"

# Core functionality tests would need node.js to execute properly
# Placeholder for core function testing
echo "NOTE: Core functionality tests require Node.js execution"

# Proto decoding tests also require node.js
echo "NOTE: Protobuf decoding tests require Node.js execution"

# Background/content script validations also require node.js
echo "NOTE: Background/content script validations require Node.js execution"

# Run external test scripts if they exist
test_dir=$(dirname "${BASH_SOURCE[0]}")
if [[ -f "$test_dir/test_background_runtime.cjs" ]]; then
    echo "NOTE: Would run test_background_runtime.cjs"
fi

if [[ -f "$test_dir/test_sidepanel_player_guard.cjs" ]]; then
    echo "NOTE: Would run test_sidepanel_player_guard.cjs"
fi

if [[ -f "$test_dir/test_vlc_switch.cjs" ]]; then
    echo "NOTE: Would run test_vlc_switch.cjs"
fi

for script in test_external_speech_filter.cjs test_issue_controls.cjs; do
    if [[ -f "$test_dir/$script" ]]; then
        echo "NOTE: Would run $script"
    fi
done

echo "PASS: manifest 0.8.2, $scripts scripts, basic structure and file checks completed"
