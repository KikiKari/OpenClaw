#!/usr/bin/env tclsh
# test_mobile_projects.py — portiert nach tcl
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_mobile_projects.py
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

package require json
package require fileutil

# Define paths similar to Python's Path operations
set scriptDir [file normalize [file dirname [info script]]]
set ROOT [file normalize "$scriptDir/../.."]
set IOS [file join $ROOT "mobile" "ios"]
set ANDROID [file join $ROOT "mobile" "android"]
set SHARED [file join $ROOT "plugin-source" "mobile-shared" "webview-bridge.js"]

proc require {condition message} {
    if {![uplevel #0 expr $condition]} {
        error $message
    }
}

# Android checks
if {[file exists $ANDROID]} {
    set manifestPath [file join $ANDROID "app" "src" "main" "AndroidManifest.xml"]
    set gradlePath [file join $ANDROID "app" "build.gradle.kts"]
    set webviewPath [file join $ANDROID "app" "src" "main" "java" "app" "tiktoklivecompanion" "CompanionWebView.kt"]
    
    set manifest [::fileutil::cat -encoding utf-8 $manifestPath]
    set gradle [::fileutil::cat -encoding utf-8 $gradlePath]
    set android_webview [::fileutil::cat -encoding utf-8 $webviewPath]
    
    require {[string first {minSdk = 21} $gradle] != -1 && [string first {versionName = "0.8.2"} $gradle] != -1} "Android version contract"
    require {[string first {usesCleartextTraffic="false"} $manifest] != -1} "Android cleartext must be disabled"
    require {[string first addJavascriptInterface $android_webview] == -1} "insecure Android JavaScript interface"
    require {[string first addWebMessageListener $android_webview] != -1 && [string first ALLOWED_ORIGIN $android_webview] != -1} "origin-restricted Android bridge"
    
    # Check for .aar files in libs directory
    set aarFiles [glob -nocomplain -dir [file join $ANDROID "app" "libs"] *.aar]
    require {[llength $aarFiles] == 0} "ShazamKit AAR must not be committed"
    
    # Compare file contents
    set sharedContent [::fileutil::cat -binary $SHARED]
    set androidBridgePath [file join $ANDROID "app" "src" "main" "res" "raw" "webview-bridge.js"]
    set androidBridgeContent [::fileutil::cat -binary $androidBridgePath]
    require {$sharedContent eq $androidBridgeContent} "Android bridge copy drift"
}

# iOS checks
if {[file exists $IOS]} {
    set iosWebviewPath [file join $IOS "TikTokLiveCompanion" "CompanionWebView.swift"]
    set pbxPath [file join $IOS "TikTokLiveCompanion.xcodeproj" "project.pbxproj"]
    set infoPlistPath [file join $IOS "TikTokLiveCompanion" "Info.plist"]
    
    set ios_webview [::fileutil::cat -encoding utf-8 $iosWebviewPath]
    set pbx [::fileutil::cat -encoding utf-8 $pbxPath]
    
    require {[string first {forMainFrameOnly: false} $ios_webview] != -1 && [string first {securityOrigin.host == "www.tiktok.com"} $ios_webview] != -1} "origin-restricted iOS subframe bridge"
    require {[string first {MARKETING_VERSION = 0.8.2} $pbx] != -1 && [string first {IPHONEOS_DEPLOYMENT_TARGET = 15.0} $pbx] != -1} "iOS version contract"
    
    # Check source membership
    set requiredNames [list "StreamNameNormalizer.swift in Sources" "StreamNameNormalizerTests.swift in Sources" "MobileUIStructureTests.swift in Sources"]
    set allFound 1
    foreach name $requiredNames {
        if {[string first $name $pbx] == -1} {
            set allFound 0
            break
        }
    }
    require {$allFound} "iOS source and XCTest membership"
    
    # Compare file contents
    set sharedContent [::fileutil::cat -binary $SHARED]
    set iosBridgePath [file join $IOS "Resources" "webview-bridge.js"]
    set iosBridgeContent [::fileutil::cat -binary $iosBridgePath]
    require {$sharedContent eq $iosBridgeContent} "iOS bridge copy drift"
    
    # Parse Info.plist
    if {[catch {exec plutil -convert json -o - $infoPlistPath} plistJson]} {
        error "Failed to parse Info.plist"
    }
    set info [::json::json2dict $plistJson]
    require {[dict get $info CFBundleShortVersionString] eq "0.8.2"} "iOS plist version"
}

# Check for .p8 files
set p8Files [glob -nocomplain -dir $ROOT -types f *.p8]
require {[llength $p8Files] == 0} "Apple private key must not be committed"

# Schema validation
set schemaPath [file join $ROOT "plugin-source" "mobile-shared" "recognition-result.schema.json"]
set schemaContent [::fileutil::cat -encoding utf-8 $schemaPath]
set schema [::json::json2dict $schemaContent]
set sourceEnum [dict get [dict get $schema properties] source enum]
require {$sourceEnum eq [list microphone webview]} "recognition source schema"

puts "PASS: available mobile platform versions, bridge boundaries, policies, schema, source sync and secret exclusions"
