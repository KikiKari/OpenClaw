#!/usr/bin/env pwsh
# test_mobile_projects.py — portiert nach powershell
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_projects.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

$ErrorActionPreference = "Stop"

# Define paths
$ScriptPath = $MyInvocation.MyCommand.Definition
$ROOT = Split-Path (Split-Path (Resolve-Path $ScriptPath).Path -Parent) -Parent
$IOS = Join-Path $ROOT "mobile" "ios"
$ANDROID = Join-Path $ROOT "mobile" "android"
$SHARED = Join-Path $ROOT "plugin-source" "mobile-shared" "webview-bridge.js"

function Require {
    param (
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

# Android checks
if (Test-Path $ANDROID) {
    $manifestPath = Join-Path $ANDROID "app" "src" "main" "AndroidManifest.xml"
    $gradlePath = Join-Path $ANDROID "app" "build.gradle.kts"
    $androidWebviewPath = Join-Path $ANDROID "app" "src" "main" "java" "app" "tiktoklivecompanion" "CompanionWebView.kt"
    $libsPath = Join-Path $ANDROID "app" "libs"
    $resBridgePath = Join-Path $ANDROID "app" "src" "main" "res" "raw" "webview_bridge.js"

    $manifest = Get-Content $manifestPath -Encoding UTF8
    $gradle = Get-Content $gradlePath -Encoding UTF8
    $android_webview = Get-Content $androidWebviewPath -Encoding UTF8

    Require ('minSdk = 21' -in $gradle -and 'versionName = "0.8.0"' -in $gradle) "Android version contract"
    Require ('usesCleartextTraffic="false"' -in $manifest) "Android cleartext must be disabled"
    Require ("addJavascriptInterface" -notin $android_webview) "insecure Android JavaScript interface"
    Require (("addWebMessageListener" -in $android_webview) -and ("ALLOWED_ORIGIN" -in $android_webview)) "origin-restricted Android bridge"
    
    $aarFiles = Get-ChildItem -Path $libsPath -Filter "*.aar" -Recurse
    Require ($aarFiles.Count -eq 0) "ShazamKit AAR must not be committed"

    $sharedBytes = Get-Content $SHARED -Raw -Encoding Byte
    $resBridgeBytes = Get-Content $resBridgePath -Raw -Encoding Byte
    Require ([System.Linq.Enumerable]::SequenceEqual($sharedBytes, $resBridgeBytes)) "Android bridge copy drift"
}

# iOS checks
if (Test-Path $IOS) {
    $iosWebviewPath = Join-Path $IOS "TikTokLiveCompanion" "CompanionWebView.swift"
    $pbxPath = Join-Path $IOS "TikTokLiveCompanion.xcodeproj" "project.pbxproj"
    $infoPlistPath = Join-Path $IOS "TikTokLiveCompanion" "Info.plist"
    $resourcesBridgePath = Join-Path $IOS "Resources" "webview-bridge.js"

    $ios_webview = Get-Content $iosWebviewPath -Encoding UTF8
    $pbx = Get-Content $pbxPath -Encoding UTF8

    Require (("forMainFrameOnly: false" -in $ios_webview) -and ("securityOrigin.host == `"www.tiktok.com`"" -in $ios_webview)) "origin-restricted iOS subframe bridge"
    Require (("MARKETING_VERSION = 0.8.0" -in $pbx) -and ("IPHONEOS_DEPLOYMENT_TARGET = 15.0" -in $pbx)) "iOS version contract"

    $requiredSources = @(
        "StreamNameNormalizer.swift in Sources",
        "StreamNameNormalizerTests.swift in Sources", 
        "MobileUIStructureTests.swift in Sources"
    )
    $allFound = $true
    foreach ($source in $requiredSources) {
        if ($source -notin $pbx) {
            $allFound = $false
            break
        }
    }
    Require $allFound "iOS source and XCTest membership"

    $sharedBytes = Get-Content $SHARED -Raw -Encoding Byte
    $resourcesBridgeBytes = Get-Content $resourcesBridgePath -Raw -Encoding Byte
    Require ([System.Linq.Enumerable]::SequenceEqual($sharedBytes, $resourcesBridgeBytes)) "iOS bridge copy drift"

    # Load Info.plist as XML
    $info = [xml](Get-Content $infoPlistPath)
    $version = ($info.plist.dict | Where-Object { $_.key -eq "CFBundleShortVersionString" })."#text"
    Require ($version -eq "0.8.0") "iOS plist version"
}

# Check for .p8 files (Apple private keys)
$p8Files = Get-ChildItem -Path $ROOT -Recurse -Include "*.p8"
Require ($p8Files.Count -eq 0) "Apple private key must not be committed"

# Schema validation
$schemaPath = Join-Path $ROOT "plugin-source" "mobile-shared" "recognition-result.schema.json"
$schemaJson = Get-Content $schemaPath -Raw -Encoding UTF8 | ConvertFrom-Json
$expectedEnum = @("microphone", "webview")
$actualEnum = $schemaJson.properties.source.enum
Require (@(Compare-Object $expectedEnum $actualEnum -SyncWindow 0).Length -eq 0) "recognition source schema"

Write-Host "PASS: available mobile platform versions, bridge boundaries, policies, schema, source sync and secret exclusions"
