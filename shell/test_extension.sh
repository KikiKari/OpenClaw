#!/bin/bash
# test_extension.cjs — portiert nach shell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_extension.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_extension.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_extension.cjs
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# This bash translation mimics the JavaScript tests but uses bash equivalents
# where possible. Due to fundamental differences between JavaScript and bash,
# some functionality like protobuf decoding or complex object manipulation
# cannot be directly translated and would need specific implementations.

root=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
extension="$root/browser-extension"

# Check if required files exist
[[ -f "$extension/manifest.json" ]] || { echo "manifest.json not found"; exit 1; }
[[ -f "$extension/content-core.js" ]] || { echo "content-core.js not found"; exit 1; }
[[ -f "$extension/proto-main.js" ]] || { echo "proto-main.js not found"; exit 1; }

# Read manifest
manifest_content=$(cat "$extension/manifest.json")
version=$(echo "$manifest_content" | jq -r '.version')
manifest_version=$(echo "$manifest_content" | jq -r '.manifest_version')

# Assertions on manifest values
[[ "$manifest_version" == "3" ]] || { echo "Manifest version assertion failed"; exit 1; }
[[ "$version" == "0.8.0" ]] || { echo "Version assertion failed"; exit 1; }

# Check permissions
permissions=$(echo "$manifest_content" | jq -r '.permissions[]')
host_permissions=$(echo "$manifest_content" | jq -r '.host_permissions[]')

required_permissions=("sidePanel" "webRequest" "tabCapture")
for perm in "${required_permissions[@]}"; do
    echo "$permissions" | grep -q "^$perm$" || { echo "Permission $perm missing"; exit 1; }
done

forbidden_permissions=("cookies" "webRequestBlocking" "nativeMessaging")
for perm in "${forbidden_permissions[@]}"; do
    echo "$permissions" | grep -q "^$perm$" && { echo "Forbidden permission $perm present"; exit 1; }
done

# Check host permissions
required_hosts=("http://127.0.0.1/*" "http://localhost/*")
for host in "${required_hosts[@]}"; do
    echo "$host_permissions" | grep -q "^$host$" || { echo "Host permission $host missing"; exit 1; }
done

# Check content scripts
content_script_js=$(echo "$manifest_content" | jq -r '.content_scripts[0].js[0]')
[[ "$content_script_js" == "vendor-mpegts.js" ]] || { echo "vendor-mpegts.js not first content script"; exit 1; }

# Check vendor files exist
mpegts_files=("vendor-mpegts.js" "vendor-mpegts.LICENSE.txt" "vendor-mpegts.NOTICE.md")
for file in "${mpegts_files[@]}"; do
    [[ -f "$extension/$file" ]] || { echo "$file not found"; exit 1; }
done

# Check SHA256 hash of vendor file
# Note: This requires shasum or sha256sum command
expected_hash="0786F9AF6780822FF29240259A73B07ED7BC479BC44966E49418DD38213B8064"
actual_hash=$(shasum -a 256 "$extension/vendor-mpegts.js" | cut -d' ' -f1 | tr '[:lower:]' '[:upper:]')
[[ "$actual_hash" == "$expected_hash" ]] || { echo "SHA256 hash mismatch"; exit 1; }

# Check mobile bridge content
mobile_bridge_content=$(cat "$root/mobile-shared/webview-bridge.js")
[[ "$mobile_bridge_content" == *"location.hostname !== \"www.tiktok.com\""* ]] || { echo "Hostname check missing"; exit 1; }
[[ "$mobile_bridge_content" != *"document.cookie"* ]] || { echo "document.cookie found"; exit 1; }
[[ "$mobile_bridge_content" == *"QUICK_RECOVER_RELOAD_COOLDOWN_MS = 400"* ]] || { echo "QUICK_RECOVER_RELOAD_COOLDOWN_MS missing"; exit 1; }
[[ "$mobile_bridge_content" == *"\"set-auto-reconnect\""* ]] || { echo "set-auto-reconnect missing"; exit 1; }
[[ "$mobile_bridge_content" == *"\"set-limiter\""* ]] || { echo "set-limiter missing"; exit 1; }

# Check manifest files exist
background_service_worker=$(echo "$manifest_content" | jq -r '.background.service_worker')
side_panel_default_path=$(echo "$manifest_content" | jq -r '.side_panel.default_path')
content_scripts_all=$(echo "$manifest_content" | jq -r '.content_scripts[].js[]')

files_to_check=("$background_service_worker" "$side_panel_default_path" $content_scripts_all)

for relative in "${files_to_check[@]}"; do
    [[ -f "$extension/$relative" ]] || { echo "Missing manifest file: $relative"; exit 1; }
done

# Check all .js files for forbidden patterns
script_files=()
while IFS= read -r -d '' file; do
    script_files+=("$file")
done < <(find "$extension" -maxdepth 1 -name "*.js" -print0)

for script in "${script_files[@]}"; do
    source=$(cat "$script")
    basename_script=$(basename "$script")
    
    # Check for eval
    [[ "$source" != *"eval("* ]] || { echo "$basename_script contains eval()"; exit 1; }
    
    # Check for Function constructor
    [[ "$source" != *"new Function("* ]] || { echo "$basename_script contains new Function()"; exit 1; }
    
    # Check for innerHTML assignment
    [[ "$source" != *".innerHTML ="* ]] || { echo "$basename_script assigns innerHTML"; exit 1; }
done

echo "PASS: Basic manifest checks, file existence, and security checks"

# Note: The rest of the JavaScript tests involve complex business logic that 
# would require implementing JavaScript functions in bash, which is beyond 
# the scope of this translation. In a real implementation, you would need to
# either reimplement the core logic in bash or call external tools/scripts.
