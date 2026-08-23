#!/bin/bash
# test_mobile_bridge.cjs — portiert nach shell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_bridge.cjs
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Function to check if a string contains a substring
contains() {
    local haystack="$1"
    local needle="$2"
    [[ "$haystack" == *"$needle"* ]]
}

# Function to check if a string does not contain a substring
not_contains() {
    local haystack="$1"
    local needle="$2"
    ! contains "$haystack" "$needle"
}

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(realpath "$SCRIPT_DIR/..")"
BRIDGE_PATH="$ROOT/mobile-shared/webview-bridge.js"

# Check if files exist
if [[ ! -f "$BRIDGE_PATH" ]]; then
    echo "FAIL: Bridge file not found at $BRIDGE_PATH"
    exit 1
fi

# Read the source file
SOURCE=$(cat "$BRIDGE_PATH")

# Syntax check using node (similar to vm.Script)
if ! node -c "$BRIDGE_PATH" 2>/dev/null; then
    echo "FAIL: Syntax error in bridge file"
    exit 1
fi

# Assertions - all must be true
contains "$SOURCE" 'location.hostname !== "www.tiktok.com"' || { echo "FAIL: location check missing"; exit 1; }
contains "$SOURCE" "root.top === root" || { echo "FAIL: top frame check missing"; exit 1; }
contains "$SOURCE" "if (!isTop) return" || { echo "FAIL: early return for non-top missing"; exit 1; }
contains "$SOURCE" "MAX_MESSAGE_BYTES = 64 * 1024" || { echo "FAIL: message size limit missing"; exit 1; }
contains "$SOURCE" "MAX_AUDIO_SECONDS = 12" || { echo "FAIL: audio duration limit missing"; exit 1; }
contains "$SOURCE" "QUICK_RECOVER_RELOAD_COOLDOWN_MS = 400" || { echo "FAIL: reload cooldown missing"; exit 1; }
contains "$SOURCE" "ALLOWED_COMMANDS" || { echo "FAIL: allowed commands missing"; exit 1; }
contains "$SOURCE" '"set-auto-reconnect"' || { echo "FAIL: set-auto-reconnect command missing"; exit 1; }
contains "$SOURCE" '"set-limiter"' || { echo "FAIL: set-limiter command missing"; exit 1; }
contains "$SOURCE" '"scan-recommendations"' || { echo "FAIL: scan-recommendations command missing"; exit 1; }
contains "$SOURCE" '"cancel-recommendation-scan"' || { echo "FAIL: cancel-recommendation-scan command missing"; exit 1; }
contains "$SOURCE" "MAX_MEDIA_URLS = 12" || { echo "FAIL: media urls limit missing"; exit 1; }
contains "$SOURCE" "const mediaUrls = new Map()" || { echo "FAIL: media urls map missing"; exit 1; }
contains "$SOURCE" 'emit("media-url"' || { echo "FAIL: media-url emit missing"; exit 1; }
contains "$SOURCE" "addEventListener(\"message\"" || { echo "FAIL: message listener missing"; exit 1; }
not_contains "$SOURCE" ".send =" || { echo "FAIL: .send method found"; exit 1; }
not_contains "$SOURCE" "document.cookie" || { echo "FAIL: document.cookie found"; exit 1; }
not_contains "$SOURCE" "localStorage" || { echo "FAIL: localStorage found"; exit 1; }
contains "$SOURCE" 'FORCE_RETURN_KEY = "tlc-force-return"' || { echo "FAIL: force return key missing"; exit 1; }
contains "$SOURCE" "sessionStorage.getItem(FORCE_RETURN_KEY)" || { echo "FAIL: sessionStorage getItem missing"; exit 1; }
not_contains "$SOURCE" "sessionStorage.clear" || { echo "FAIL: sessionStorage.clear found"; exit 1; }
not_contains "$SOURCE" "innerHTML" || { echo "FAIL: innerHTML found"; exit 1; }

# Check copies
COPY_PATHS=(
    "$ROOT/../mobile/ios/Resources/webview-bridge.js"
    "$ROOT/../mobile/android/app/src/main/res/raw/webview_bridge.js"
)

for COPY in "${COPY_PATHS[@]}"; do
    if [[ ! -f "$COPY" ]]; then
        echo "FAIL: Bridge copy not found at $COPY"
        exit 1
    fi
    
    COPY_CONTENT=$(cat "$COPY")
    if [[ "$SOURCE" != "$COPY_CONTENT" ]]; then
        echo "FAIL: Bridge copy drifted: $COPY"
        exit 1
    fi
done

echo "PASS: mobile bridge origin, main-frame, size, command, audio-duration and storage guards"
