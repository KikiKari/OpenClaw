#!/usr/bin/env tclsh
# test_mobile_projects.py — portiert nach tcl
# Quelle: python, Projects@TikTok-Live-Companion:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_mobile_projects.py
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_mobile_projects.py
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

package require json
package require fileutil

# Define paths similar to Python's Path operations
set scriptDir [file normalize [file dirname [info script]]]
set ROOT [file dirname [file dirname $scriptDir]]
set IOS [file join $ROOT mobile ios]
set ANDROID [file join $ROOT mobile android]
set SHARED [file join $ROOT plugin-source mobile-shared webview-bridge.js]

# Procedure equivalent to Python's require function
proc require {condition message} {
    if {![uplevel expr $condition]} {
        error $message
    }
}

# Check Android project if it exists
if {[file exists $ANDROID]} {
    set manifestPath [file join $ANDROID app src main AndroidManifest.xml]
    set gradlePath [file join $ANDROID app build.gradle.kts]
    set androidWebviewPath [file join $ANDROID app src main java app tiktoklivecompanion CompanionWebView.kt]
    
    set manifest [readFile $manifestPath]
    set gradle [readFile $gradlePath]
    set android_webview [readFile $androidWebviewPath]
    
    require {[string match "*minSdk = 21*" $gradle] && [string match "*versionName = \"0.8.2\"*" $gradle]} "Android version contract"
    require {[string match "*usesCleartextTraffic=\"false\"*" $manifest]} "Android cleartext must be disabled"
    require {![string match "*addJavascriptInterface*" $android_webview]} "insecure Android JavaScript interface"
    require {[string match "*addWebMessageListener*" $android_webview] && [string match "*ALLOWED_ORIGIN*" $android_webview]} "origin-restricted Android bridge"
    
    # Check for .aar files in libs directory
    set aarFiles [glob -nocomplain -dir [file join $ANDROID app libs] *.aar]
    require {![llength $aarFiles]} "ShazamKit AAR must not be committed"
    
    # Compare shared file with Android resource
    set androidBridgePath [file join $ANDROID app src main res raw webview_bridge.js]
    require {[readBinaryFile $SHARED] eq [readBinaryFile $androidBridgePath]} "Android bridge copy drift"
}

# Check iOS project if it exists
if {[file exists $IOS]} {
    set iosWebviewPath [file join $IOS TikTokLiveCompanion CompanionWebView.swift]
    set pbxPath [file join $IOS TikTokLiveCompanion.xcodeproj project.pbxproj]
    
    set ios_webview [readFile $iosWebviewPath]
    set pbx [readFile $pbxPath]
    
    require {[string match "*forMainFrameOnly: false*" $ios_webview] && [string match "*securityOrigin.host == \"www.tiktok.com\"*" $ios_webview]} "origin-restricted iOS subframe bridge"
    require {[string match "*MARKETING_VERSION = 0.8.2*" $pbx] && [string match "*IPHONEOS_DEPLOYMENT_TARGET = 15.0*" $pbx]} "iOS version contract"
    
    # Check for required entries in pbx file
    set requiredNames {"StreamNameNormalizer.swift in Sources" "StreamNameNormalizerTests.swift in Sources" "MobileUIStructureTests.swift in Sources"}
    set allFound true
    foreach name $requiredNames {
        if {![string match "*$name*" $pbx]} {
            set allFound false
            break
        }
    }
    require {$allFound} "iOS source and XCTest membership"
    
    # Compare shared file with iOS resource
    set iosBridgePath [file join $IOS Resources webview-bridge.js]
    require {[readBinaryFile $SHARED] eq [readBinaryFile $iosBridgePath]} "iOS bridge copy drift"
    
    # Read Info.plist and check version
    set infoPlistPath [file join $IOS TikTokLiveCompanion Info.plist]
    set info [exec plutil -convert json -o - $infoPlistPath]
    set infoJson [json::json2dict $info]
    set cfBundleShortVersionString [dict get $infoJson CFBundleShortVersionString]
    require {$cfBundleShortVersionString eq "0.8.2"} "iOS plist version"
}

# Check for Apple private keys
set p8Files [glob -nocomplain -dir $ROOT -types f *.p8]
require {![llength $p8Files]} "Apple private key must not be committed"

# Check recognition result schema
set schemaPath [file join $ROOT plugin-source mobile-shared recognition-result.schema.json]
set schemaContent [readFile $schemaPath]
set schema [json::json2dict $schemaContent]
set sourceEnum [dict get [dict get $schema properties] source enum]
require {$sourceEnum eq {microphone webview}} "recognition source schema"

puts "PASS: available mobile platform versions, bridge boundaries, policies, schema, source sync and secret exclusions"

# Helper procedures
proc readFile {path} {
    set fh [open $path r]
    set content [read $fh]
    close $fh
    return $content
}

proc readBinaryFile {path} {
    set fh [open $path rb]
    set content [read $fh]
    close $fh
    return $content
}
