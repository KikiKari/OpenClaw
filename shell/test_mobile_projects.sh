#!/bin/bash
# test_mobile_projects.py — portiert nach shell
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_mobile_projects.py
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Bestimme das Stammverzeichnis relativ zu diesem Skript
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IOS="$ROOT/mobile/ios"
ANDROID="$ROOT/mobile/android"
SHARED="$ROOT/plugin-source/mobile-shared/webview-bridge.js"

# Funktion zur Überprüfung einer Bedingung (ähnlich zu assert in Python)
require() {
    local condition=$1
    local message=$2
    if [[ "$condition" != "true" ]]; then
        echo "AssertionError: $message" >&2
        exit 1
    fi
}

# Prüfe Android-Projekt, falls vorhanden
if [[ -d "$ANDROID" ]]; then
    MANIFEST="$ANDROID/app/src/main/AndroidManifest.xml"
    GRADLE="$ANDROID/app/build.gradle.kts"
    ANDROID_WEBVIEW="$ANDROID/app/src/main/java/app/tiktoklivecompanion/CompanionWebView.kt"
    BRIDGE_JS_ANDROID="$ANDROID/app/src/main/res/raw/webview_bridge.js"

    # Lese Dateien ein
    manifest_content=$(<"$MANIFEST")
    gradle_content=$(<"$GRADLE")
    android_webview_content=$(<"$ANDROID_WEBVIEW")

    # Version und SDK-Prüfung
    require $(echo "$gradle_content" | grep -q 'minSdk = 21' && echo "$gradle_content" | grep -q 'versionName = "0.8.2"' && echo true || echo false) "Android version contract"

    # Cleartext Traffic deaktiviert
    require $(echo "$manifest_content" | grep -q 'usesCleartextTraffic="false"' && echo true || echo false) "Android cleartext must be disabled"

    # Unsichere JS-Schnittstelle nicht erlaubt
    require $(echo "$android_webview_content" | grep -q 'addJavascriptInterface' && echo false || echo true) "insecure Android JavaScript interface"

    # Origin-beschränkte Bridge
    require $(echo "$android_webview_content" | grep -q 'addWebMessageListener' && echo "$android_webview_content" | grep -q 'ALLOWED_ORIGIN' && echo true || echo false) "origin-restricted Android bridge"

    # Prüfe, ob .aar-Dateien im libs-Ordner vorhanden sind
    aar_files=("$ANDROID"/app/libs/*.aar)
    if [[ -e "${aar_files[0]}" ]]; then
        require false "ShazamKit AAR must not be committed"
    fi

    # Vergleiche webview-bridge.js mit der Kopie
    if ! cmp -s "$SHARED" "$BRIDGE_JS_ANDROID"; then
        require false "Android bridge copy drift"
    fi
fi

# Prüfe iOS-Projekt, falls vorhanden
if [[ -d "$IOS" ]]; then
    IOS_WEBVIEW="$IOS/TikTokLiveCompanion/CompanionWebView.swift"
    PBX="$IOS/TikTokLiveCompanion.xcodeproj/project.pbxproj"
    INFO_PLIST="$IOS/TikTokLiveCompanion/Info.plist"
    BRIDGE_JS_IOS="$IOS/Resources/webview-bridge.js"

    ios_webview_content=$(<"$IOS_WEBVIEW")
    pbx_content=$(<"$PBX")

    # Origin-beschränkte Subframe-Bridge
    require $(echo "$ios_webview_content" | grep -q 'forMainFrameOnly: false' && echo "$ios_webview_content" | grep -q 'securityOrigin.host == "www.tiktok.com"' && echo true || echo false) "origin-restricted iOS subframe bridge"

    # Versions- und Deployment-Ziel-Prüfung
    require $(echo "$pbx_content" | grep -q 'MARKETING_VERSION = 0.8.2' && echo "$pbx_content" | grep -q 'IPHONEOS_DEPLOYMENT_TARGET = 15.0' && echo true || echo false) "iOS version contract"

    # Prüfung der Source-Membership
    require $(echo "$pbx_content" | grep -q 'StreamNameNormalizer.swift in Sources' && \
             echo "$pbx_content" | grep -q 'StreamNameNormalizerTests.swift in Sources' && \
             echo "$pbx_content" | grep -q 'MobileUIStructureTests.swift in Sources' && echo true || echo false) "iOS source and XCTest membership"

    # Vergleiche webview-bridge.js mit der Kopie
    if ! cmp -s "$SHARED" "$BRIDGE_JS_IOS"; then
        require false "iOS bridge copy drift"
    fi

    # Prüfung der Info.plist-Version
    plist_version=$(plutil -extract CFBundleShortVersionString raw "$INFO_PLIST" 2>/dev/null)
    require [[ "$plist_version" == "0.8.2" ]] "iOS plist version"
fi

# Prüfung auf Apple Private Keys
private_keys=( $(find "$ROOT" -type f -name "*.p8") )
if [[ ${#private_keys[@]} -gt 0 ]]; then
    require false "Apple private key must not be committed"
fi

# Schema-Prüfung
SCHEMA_FILE="$ROOT/plugin-source/mobile-shared/recognition-result.schema.json"
schema_json=$(<"$SCHEMA_FILE")
source_enum=$(echo "$schema_json" | jq -r '.properties.source.enum | join(",")')
require [[ "$source_enum" == "microphone,webview" ]] "recognition source schema"

echo "PASS: available mobile platform versions, bridge boundaries, policies, schema, source sync and secret exclusions"
