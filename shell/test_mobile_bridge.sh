#!/bin/bash
# test_mobile_bridge.cjs — portiert nach shell
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_bridge.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_mobile_bridge.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Function to get the directory of the script
get_script_dir() {
    local source="${BASH_SOURCE[0]}"
    while [[ -h "$source" ]]; do
        local dir="$(cd -P "$(dirname "$source")" && pwd)"
        source="$(readlink "$source")"
        [[ $source != /* ]] && source="$dir/$source"
    done
    cd -P "$(dirname "$source")" && pwd
}

# Get root directory (parent of script's directory)
SCRIPT_DIR=$(get_script_dir)
ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

# Path to the bridge file
BRIDGE_PATH="$ROOT/mobile-shared/webview-bridge.js"

# Check if bridge file exists
if [[ ! -f "$BRIDGE_PATH" ]]; then
    echo "FAIL: Bridge file not found at $BRIDGE_PATH" >&2
    exit 1
fi

# Read the source content
SOURCE=$(cat "$BRIDGE_PATH")

# Assertions using grep for pattern matching
echo "$SOURCE" | grep -q 'location\.hostname !== "www\.tiktok\.com"' || {
    echo "FAIL: location.hostname check not found" >&2
    exit 1
}

echo "$SOURCE" | grep -q 'root\.top === root' || {
    echo "FAIL: root.top check not found" >&2
    exit 1
}

echo "$SOURCE" | grep -q 'if (!isTop) return' || {
    echo "FAIL: isTop guard not found" >&2
    exit 1
}

echo "$SOURCE" | grep -q 'MAX_MESSAGE_BYTES = 64 \* 1024' || {
    echo "FAIL: MAX_MESSAGE_BYTES not found" >&2
    exit 1
}

echo "$SOURCE" | grep -q 'MAX_AUDIO_SECONDS = 12' || {
    echo "FAIL: MAX_AUDIO_SECONDS not found" >&2
    exit 1
}

echo "$SOURCE" | grep -q 'QUICK_RECOVER_RELOAD_COOLDOWN_MS = 400' || {
    echo "FAIL: QUICK_RECOVER_RELOAD_COOLDOWN_MS not found" >&2
    exit 1
}

echo "$SOURCE" | grep -q 'ALLOWED_COMMANDS' || {
    echo "FAIL: ALLOWED_COMMANDS not found" >&2
    exit 1
}

echo "$SOURCE" | grep -q '"set-auto-reconnect"' || {
    echo "FAIL: set-auto-reconnect command not found" >&2
    exit 1
}

echo "$SOURCE" | grep -q '"set-limiter"' || {
    echo "FAIL: set-limiter command not found" >&2
    exit 1
}

echo "$SOURCE" | grep -q '"scan-recommendations"' || {
    echo "FAIL: scan-recommendations command not found" >&2
    exit 1
}

echo "$SOURCE" | grep -q '"cancel-recommendation-scan"' || {
    echo "FAIL: cancel-recommendation-scan command not found" >&2
    exit 1
}

echo "$SOURCE" | grep -q 'MAX_MEDIA_URLS = 12' || {
    echo "FAIL: MAX_MEDIA_URLS not found" >&2
    exit 1
}

echo "$SOURCE" | grep -q 'const mediaUrls = new Map()' || {
    echo "FAIL: mediaUrls Map declaration not found" >&2
    exit 1
}

echo "$SOURCE" | grep -q 'emit("media-url"' || {
    echo "FAIL: emit media-url not found" >&2
    exit 1
}

echo "$SOURCE" | grep -q 'addEventListener("message"' || {
    echo "FAIL: addEventListener message not found" >&2
    exit 1
}

# Negative assertions (should NOT contain these patterns)
if echo "$SOURCE" | grep -q '\.send ='; then
    echo "FAIL: Found .send = which should not be present" >&2
    exit 1
fi

if echo "$SOURCE" | grep -q 'document\.cookie'; then
    echo "FAIL: Found document.cookie which should not be present" >&2
    exit 1
fi

if echo "$SOURCE" | grep -q 'localStorage'; then
    echo "FAIL: Found localStorage which should not be present" >&2
    exit 1
fi

echo "$SOURCE" | grep -q 'FORCE_RETURN_KEY = "tlc-force-return"' || {
    echo "FAIL: FORCE_RETURN_KEY not found" >&2
    exit 1
}

echo "$SOURCE" | grep -q 'sessionStorage\.getItem(FORCE_RETURN_KEY)' || {
    echo "FAIL: sessionStorage.getItem(FORCE_RETURN_KEY) not found" >&2
    exit 1
}

if echo "$SOURCE" | grep -q 'sessionStorage\.clear'; then
    echo "FAIL: Found sessionStorage.clear which should not be present" >&2
    exit 1
fi

if echo "$SOURCE" | grep -q 'innerHTML'; then
    echo "FAIL: Found innerHTML which should not be present" >&2
    exit 1
fi

# Check copies in iOS and Android directories
IOS_COPY="$ROOT/../mobile/ios/Resources/webview-bridge.js"
ANDROID_COPY="$ROOT/../mobile/android/app/src/main/res/raw/webview_bridge.js"

# Check if iOS copy exists and matches
if [[ ! -f "$IOS_COPY" ]]; then
    echo "FAIL: iOS bridge copy not found at $IOS_COPY" >&2
    exit 1
fi

IOS_CONTENT=$(cat "$IOS_COPY")
if [[ "$IOS_CONTENT" != "$SOURCE" ]]; then
    echo "FAIL: Bridge copy drifted: $IOS_COPY" >&2
    exit 1
fi

# Check if Android copy exists and matches
if [[ ! -f "$ANDROID_COPY" ]]; then
    echo "FAIL: Android bridge copy not found at $ANDROID_COPY" >&2
    exit 1
fi

ANDROID_CONTENT=$(cat "$ANDROID_COPY")
if [[ "$ANDROID_CONTENT" != "$SOURCE" ]]; then
    echo "FAIL: Bridge copy drifted: $ANDROID_COPY" >&2
    exit 1
fi

echo "PASS: mobile bridge origin, main-frame, size, command, audio-duration and storage guards"
