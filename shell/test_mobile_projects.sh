#!/bin/bash
# test_mobile_projects.py — portiert nach shell
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_mobile_projects.py
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Bestimme das Stammverzeichnis relativ zu diesem Skript (zwei Ebenen höher)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IOS="$ROOT/mobile/ios"
ANDROID="$ROOT/mobile/android"
SHARED="$ROOT/plugin-source/mobile-shared/webview-bridge.js"

# Funktion zur Fehlerausgabe und Beenden
require() {
  local condition=$1
  local message=$2
  if [[ "$condition" != "true" ]]; then
    echo "AssertionError: $message" >&2
    exit 1
  fi
}

# Android-Prüfungen, falls das Verzeichnis existiert
if [[ -d "$ANDROID" ]]; then
  MANIFEST="$ANDROID/app/src/main/AndroidManifest.xml"
  GRADLE="$ANDROID/app/build.gradle.kts"
  ANDROID_WEBVIEW="$ANDROID/app/src/main/java/app/tiktoklivecompanion/CompanionWebView.kt"
  BRIDGE_JS="$ANDROID/app/src/main/res/raw/webview_bridge.js"
  AAR_LIBS_DIR="$ANDROID/app/libs"

  # Lese Dateien
  manifest_content=$(cat "$MANIFEST")
  gradle_content=$(cat "$GRADLE")
  android_webview_content=$(cat "$ANDROID_WEBVIEW")

  # Prüfe Gradle-Einstellungen
  require $(echo "$gradle_content" | grep -q 'minSdk = 21' && echo "$gradle_content" | grep -q 'versionName = "0.8.2"' && echo true || echo false) "Android version contract"

  # Prüfe Manifest-Einstellung
  require $(echo "$manifest_content" | grep -q 'usesCleartextTraffic="false"' && echo true || echo false) "Android cleartext must be disabled"

  # Prüfe WebView-Sicherheitseinstellungen
  require $(echo "$android_webview_content" | grep -q "addJavascriptInterface" && echo false || echo true) "insecure Android JavaScript interface"
  require $(echo "$android_webview_content" | grep -q "addWebMessageListener" && echo "$android_webview_content" | grep -q "ALLOWED_ORIGIN" && echo true || echo false) "origin-restricted Android bridge"

  # Prüfe auf nicht eingecheckte .aar-Dateien
  aar_files=$(find "$AAR_LIBS_DIR" -name "*.aar" 2>/dev/null | wc -l)
  require [[ "$aar_files" -eq 0 ]] "ShazamKit AAR must not be committed"

  # Prüfe Übereinstimmung der Bridge-JS-Dateien
  diff -q "$SHARED" "$BRIDGE_JS" >/dev/null 2>&1 || require false "Android bridge copy drift"
fi

# iOS-Prüfungen, falls das Verzeichnis existiert
if [[ -d "$IOS" ]]; then
  IOS_WEBVIEW="$IOS/TikTokLiveCompanion/CompanionWebView.swift"
  PBX="$IOS/TikTokLiveCompanion.xcodeproj/project.pbxproj"
  PLIST="$IOS/TikTokLiveCompanion/Info.plist"
  IOS_BRIDGE_JS="$IOS/Resources/webview-bridge.js"

  ios_webview_content=$(cat "$IOS_WEBVIEW")
  pbx_content=$(cat "$PBX")

  # Prüfe WebView-Bridge für Subframes
  require $(echo "$ios_webview_content" | grep -q "forMainFrameOnly: false" && echo "$ios_webview_content" | grep -q "securityOrigin.host == \"www.tiktok.com\"" && echo true || echo false) "origin-restricted iOS subframe bridge"

  # Prüfe Version und Deployment Target
  require $(echo "$pbx_content" | grep -q "MARKETING_VERSION = 0.8.2" && echo "$pbx_content" | grep -q "IPHONEOS_DEPLOYMENT_TARGET = 15.0" && echo true || echo false) "iOS version contract"

  # Prüfe Source-Membership in Xcode-Projekt
  require $(echo "$pbx_content" | grep -q "StreamNameNormalizer.swift in Sources" && echo "$pbx_content" | grep -q "StreamNameNormalizerTests.swift in Sources" && echo "$pbx_content" | grep -q "MobileUIStructureTests.swift in Sources" && echo true || echo false) "iOS source and XCTest membership"

  # Prüfe Übereinstimmung der Bridge-JS-Dateien
  diff -q "$SHARED" "$IOS_BRIDGE_JS" >/dev/null 2>&1 || require false "iOS bridge copy drift"

  # Prüfe Info.plist-Version
  plist_version=$(plutil -extract CFBundleShortVersionString raw "$PLIST" 2>/dev/null)
  require [[ "$plist_version" == "0.8.2" ]] "iOS plist version"
fi

# Prüfe, dass keine .p8-Dateien im Repository vorhanden sind
p8_files=$(find "$ROOT" -type f -name "*.p8" 2>/dev/null | wc -l)
require [[ "$p8_files" -eq 0 ]] "Apple private key must not be committed"

# Prüfe JSON-Schema für Recognition Source
SCHEMA_FILE="$ROOT/plugin-source/mobile-shared/recognition-result.schema.json"
schema_source_enum=$(jq -r '.properties.source.enum | join(",")' "$SCHEMA_FILE")
require [[ "$schema_source_enum" == "microphone,webview" ]] "recognition source schema"

echo "PASS: available mobile platform versions, bridge boundaries, policies, schema, source sync and secret exclusions"
