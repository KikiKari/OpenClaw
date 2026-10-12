#!/usr/bin/env pwsh
# test_mobile_projects.py — portiert nach powershell
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_mobile_projects.py
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

$ROOT = Resolve-Path "$PSScriptRoot/../.."
$IOS = Join-Path $ROOT "mobile/ios"
$ANDROID = Join-Path $ROOT "mobile/android"
$SHARED = Join-Path $ROOT "plugin-source/mobile-shared/webview-bridge.js"

function Require([bool]$condition, [string]$message) {
    if (-not $condition) {
        throw $message
    }
}

if (Test-Path $ANDROID) {
    $manifest = Get-Content -Path (Join-Path $ANDROID "app/src/main/AndroidManifest.xml") -Encoding Utf8 -Raw
    $gradle = Get-Content -Path (Join-Path $ANDROID "app/build.gradle.kts") -Encoding Utf8 -Raw
    $android_webview = Get-Content -Path (Join-Path $ANDROID "app/src/main/java/app/tiktoklivecompanion/CompanionWebView.kt") -Encoding Utf8 -Raw
    Require ('minSdk = 21' -in $gradle -and 'versionName = "0.8.2"' -in $gradle) "Android version contract"
    Require ('usesCleartextTraffic="false"' -in $manifest) "Android cleartext must be disabled"
    Require ("addJavascriptInterface" -notin $android_webview) "insecure Android JavaScript interface"
    Require (("addWebMessageListener" -in $android_webview) -and ("ALLOWED_ORIGIN" -in $android_webview)) "origin-restricted Android bridge"
    Require (-not (Get-ChildItem -Path (Join-Path $ANDROID "app/libs") -Filter "*.aar")) "ShazamKit AAR must not be committed"
    Require ((Get-Content -Path $SHARED -Encoding Byte) -eq (Get-Content -Path (Join-Path $ANDROID "app/src/main/res/raw/webview_bridge.js") -Encoding Byte)) "Android bridge copy drift"
}

if (Test-Path $IOS) {
    $ios_webview = Get-Content -Path (Join-Path $IOS "TikTokLiveCompanion/CompanionWebView.swift") -Encoding Utf8 -Raw
    $pbx = Get-Content -Path (Join-Path $IOS "TikTokLiveCompanion.xcodeproj/project.pbxproj") -Encoding Utf8 -Raw
    Require (("forMainFrameOnly: false" -in $ios_webview) -and ("securityOrigin.host == `"www.tiktok.com`"" -in $ios_webview)) "origin-restricted iOS subframe bridge"
    Require (("MARKETING_VERSION = 0.8.2" -in $pbx) -and ("IPHONEOS_DEPLOYMENT_TARGET = 15.0" -in $pbx)) "iOS version contract"
    Require ((("StreamNameNormalizer.swift in Sources" -in $pbx) -and ("StreamNameNormalizerTests.swift in Sources" -in $pbx)) -and ("MobileUIStructureTests.swift in Sources" -in $pbx)) "iOS source and XCTest membership"
    Require ((Get-Content -Path $SHARED -Encoding Byte) -eq (Get-Content -Path (Join-Path $IOS "Resources/webview-bridge.js") -Encoding Byte)) "iOS bridge copy drift"
    $info = [System.IO.File]::OpenRead((Join-Path $IOS "TikTokLiveCompanion/Info.plist"))
    try {
        $plist = [System.Xml.XmlDocument](Get-Content -Path $info.FullName -Raw)
        $versionNode = $plist.SelectSingleNode("//key[text()='CFBundleShortVersionString']/following-sibling::*[1]")
        Require ($versionNode.InnerText -eq "0.8.2") "iOS plist version"
    } finally {
        $info.Close()
    }
}

Require (-not (Get-ChildItem -Recurse -Path $ROOT -Include "*.p8")) "Apple private key must not be committed"

$schemaFile = Join-Path $ROOT "plugin-source/mobile-shared/recognition-result.schema.json"
$schemaJson = Get-Content -Path $schemaFile -Encoding Utf8 -Raw | ConvertFrom-Json
Require (($schemaJson.properties.source.enum | ForEach-Object { $_ }) -eq @("microphone", "webview")) "recognition source schema"
Write-Host "PASS: available mobile platform versions, bridge boundaries, policies, schema, source sync and secret exclusions"
