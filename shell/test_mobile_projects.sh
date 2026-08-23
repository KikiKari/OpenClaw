#!/bin/bash
# test_mobile_projects.py — portiert nach shell
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_projects.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Define paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(realpath "$SCRIPT_DIR/../..")"
IOS="$ROOT/mobile/ios"
ANDROID="$ROOT/mobile/android"
SHARED="$ROOT/plugin-source/mobile-shared/webview-bridge.js"

# Function to check condition or fail with message
require() {
    local condition="$1"
    local message="$2"
    if [[ "$condition" != "true" ]]; then
        echo "Assertion failed: $message" >&2
        exit 1
    fi
}

# Android checks
if [[ -d "$ANDROID" ]]; then
    MANIFEST="$ANDROID/app/src/main/AndroidManifest.xml"
    GRADLE="$ANDROID/app/build.gradle.kts"
    ANDROID_WEBVIEW="$ANDROID/app/src/main/java/app/tiktoklivecompanion/CompanionWebView.kt"
    
    # Check Gradle file contents
    require "$(grep -q 'minSdk = 21' "$GRADLE" && grep -q 'versionName = "0.8.0"' "$GRADLE" && echo true || echo false)" "Android version contract"
    
    # Check manifest settings
    require "$(grep -q 'usesCleartextTraffic="false"' "$MANIFEST" && echo true || echo false)" "Android cleartext must be disabled"
    
    # Check WebView security
    require "$(grep -q "addJavascriptInterface" "$ANDROID_WEBVIEW" && echo false || echo true)" "insecure Android JavaScript interface"
    require "$(grep -q "addWebMessageListener" "$ANDROID_WEBVIEW" && grep -q "ALLOWED_ORIGIN" "$ANDROID_WEBVIEW" && echo true || echo false)" "origin-restricted Android bridge"
    
    # Check for forbidden .aar files
    require "$([[ ! -n "$(find "$ANDROID/app/libs" -name "*.aar" -print -quit)" ]] && echo true || echo false)" "ShazamKit AAR must not be committed"
    
    # Compare shared JS file with Android resource
    require "$(cmp -s "$SHARED" "$ANDROID/app/src/main/res/raw/webview_bridge.js" && echo true || echo false)" "Android bridge copy drift"
fi

# iOS checks
if [[ -d "$IOS" ]]; then
    IOS_WEBVIEW="$IOS/TikTokLiveCompanion/CompanionWebView.swift"
    PBX="$IOS/TikTokLiveCompanion.xcodeproj/project.pbxproj"
    INFO_PLIST="$IOS/TikTokLiveCompanion/Info.plist"
    
    # Check iOS WebView restrictions
    require "$(grep -q "forMainFrameOnly: false" "$IOS_WEBVIEW" && grep -q "securityOrigin.host == \"www.tiktok.com\"" "$IOS_WEBVIEW" && echo true || echo false)" "origin-restricted iOS subframe bridge"
    
    # Check project settings
    require "$(grep -q "MARKETING_VERSION = 0.8.0" "$PBX" && grep -q "IPHONEOS_DEPLOYMENT_TARGET = 15.0" "$PBX" && echo true || echo false)" "iOS version contract"
    
    # Check source memberships
    require "$(
        grep -q "StreamNameNormalizer.swift in Sources" "$PBX" &&
        grep -q "StreamNameNormalizerTests.swift in Sources" "$PBX" &&
        grep -q "MobileUIStructureTests.swift in Sources" "$PBX" &&
        echo true || echo false
    )" "iOS source and XCTest membership"
    
    # Compare shared JS file with iOS resource
    require "$(cmp -s "$SHARED" "$IOS/Resources/webview-bridge.js" && echo true || echo false)" "iOS bridge copy drift"
    
    # Check Info.plist version
    PLIST_VERSION=$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST")
    require "[[ \"$PLIST_VERSION\" == \"0.8.0\" ]]" "iOS plist version"
fi

# Check for forbidden Apple private keys
require "$([[ ! -n "$(find "$ROOT" -name "*.p8" -print -quit)" ]] && echo true || echo false)" "Apple private key must not be committed"

# Check JSON schema
SCHEMA_FILE="$ROOT/plugin-source/mobile-shared/recognition-result.schema.json"
SOURCE_ENUM=$(jq -r '.properties.source.enum | join(",")' "$SCHEMA_FILE")
require "[[ \"$SOURCE_ENUM\" == \"microphone,webview\" ]]" "recognition source schema"

echo "PASS: available mobile platform versions, bridge boundaries, policies, schema, source sync and secret exclusions"
