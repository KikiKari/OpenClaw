#!/usr/bin/env pwsh
# test_mobile_projects.py — portiert nach powershell
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_mobile_projects.py
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

$ROOT = Resolve-Path "$PSScriptRoot/../../.."
$IOS = Join-Path $ROOT "mobile/ios"
$ANDROID = Join-Path $ROOT "mobile/android"
$SHARED = Join-Path $ROOT "plugin-source/mobile-shared/webview-bridge.js"

function Require {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

if (Test-Path $ANDROID) {
    $manifest = Get-Content (Join-Path $ANDROID "app/src/main/AndroidManifest.xml") -Raw -Encoding UTF8
    $gradle = Get-Content (Join-Path $ANDROID "app/build.gradle.kts") -Raw -Encoding UTF8
    $android_webview = Get-Content (Join-Path $ANDROID "app/src/main/java/app/tiktoklivecompanion/CompanionWebView.kt") -Raw -Encoding UTF8
    Require ('minSdk = 21' -in $gradle -and 'versionName = "0.8.2"' -in $gradle) "Android version contract"
    Require ('usesCleartextTraffic="false"' -in $manifest) "Android cleartext must be disabled"
    Require ("addJavascriptInterface" -notin $android_webview) "insecure Android JavaScript interface"
    Require (("addWebMessageListener" -in $android_webview) -and ("ALLOWED_ORIGIN" -in $android_webview)) "origin-restricted Android bridge"
    Require (-not (Get-ChildItem (Join-Path $ANDROID "app/libs") -Filter "*.aar")) "ShazamKit AAR must not be committed"
    Require ((Get-Content $SHARED -Raw -AsByteStream) -eq (Get-Content (Join-Path $ANDROID "app/src/main/res/raw/webview_bridge.js") -Raw -AsByteStream)) "Android bridge copy drift"
}

if (Test-Path $IOS) {
    $ios_webview = Get-Content (Join-Path $IOS "TikTokLiveCompanion/CompanionWebView.swift") -Raw -Encoding UTF8
    $pbx = Get-Content (Join-Path $IOS "TikTokLiveCompanion.xcodeproj/project.pbxproj") -Raw -Encoding UTF8
    Require (("forMainFrameOnly: false" -in $ios_webview) -and ("securityOrigin.host == `"www.tiktok.com`"" -in $ios_webview)) "origin-restricted iOS subframe bridge"
    Require (("MARKETING_VERSION = 0.8.2" -in $pbx) -and ("IPHONEOS_DEPLOYMENT_TARGET = 15.0" -in $pbx)) "iOS version contract"
    Require ((("StreamNameNormalizer.swift in Sources" -in $pbx) -and ("StreamNameNormalizerTests.swift in Sources" -in $pbx)) -and ("MobileUIStructureTests.swift in Sources" -in $pbx)) "iOS source and XCTest membership"
    Require ((Get-Content $SHARED -Raw -AsByteStream) -eq (Get-Content (Join-Path $IOS "Resources/webview-bridge.js") -Raw -AsByteStream)) "iOS bridge copy drift"
    
    $info = [System.Xml.XmlDocument]::new()
    $info.Load((Join-Path $IOS "TikTokLiveCompanion/Info.plist"))
    $version = $info.SelectSingleNode("//key[text()='CFBundleShortVersionString']/following-sibling::string[1]").InnerText
    Require ($version -eq "0.8.2") "iOS plist version"
}

Require (-not (Get-ChildItem $ROOT -Recurse -Filter "*.p8")) "Apple private key must not be committed"

$schema = Get-Content (Join-Path $ROOT "plugin-source/mobile-shared/recognition-result.schema.json") -Raw -Encoding UTF8 | ConvertFrom-Json
Require ($schema.properties.source.enum -eq @("microphone", "webview")) "recognition source schema"
Write-Output "PASS: available mobile platform versions, bridge boundaries, policies, schema, source sync and secret exclusions"
