#!/usr/bin/env tclsh
# test_extension.cjs — portiert nach tcl
# Quelle: javascript, Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_extension.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

package require json
package require sha256

# Define helper functions to mimic JavaScript behavior
proc concat {args} {
    set result {}
    foreach chunk $args {
        append result $chunk
    }
    return $result
}

proc varint {value} {
    set bytes {}
    while {$value != 0 || [llength $bytes] == 0} {
        set byte [expr {$value & 0x7F}]
        set value [expr {$value >> 7}]
        if {$value != 0} {
            set byte [expr {$byte | 0x80}]
        }
        lappend bytes [format %c $byte]
    }
    return [concat {*}$bytes]
}

proc bytesField {number value} {
    set body $value
    if {[string is integer -strict $body]} {
        set body [binary format H* $body]
    }
    set header [varint [expr {($number << 3) | 2}]]
    set length [varint [string length $body]]
    return [concat $header $length $body]
}

proc intField {number value} {
    set header [varint [expr {$number << 3}]]
    set payload [varint $value]
    return [concat $header $payload]
}

# Set paths similar to the JS version
set root [file normalize [file dirname [info script]]/..]
set extension [file join $root browser-extension]
set manifestPath [file join $extension manifest.json]

# Read and parse manifest.json
if {![file exists $manifestPath]} {
    error "Manifest file does not exist: $manifestPath"
}
set manifestFile [open $manifestPath r]
set manifestData [read $manifestFile]
close $manifestFile
set manifest [::json::json2dict $manifestData]

# Load core and proto modules (simulated here as placeholders)
# In real implementation, these would be loaded from corresponding .js files converted to Tcl or implemented natively
source [file join $extension content-core.tcl]
source [file join $extension proto-main.tcl]

# Read mobile bridge content
set mobileBridgePath [file join $root mobile-shared webview-bridge.js]
if {![file exists $mobileBridgePath]} {
    error "Mobile bridge file does not exist: $mobileBridgePath"
}
set mobileBridgeFile [open $mobileBridgePath r]
set mobileBridge [read $mobileBridgeFile]
close $mobileBridgeFile

# Assertions based on manifest values
if {[dict get $manifest manifest_version] != 3} {
    error "Manifest version mismatch"
}
if {[dict get $manifest version] != "0.8.2"} {
    error "Version mismatch"
}
set permissions [dict get $manifest permissions]
if {![lsearch -exact $permissions sidePanel] >= 0} {
    error "Missing permission: sidePanel"
}
if {![lsearch -exact $permissions webRequest] >= 0} {
    error "Missing permission: webRequest"
}
if {![lsearch -exact $permissions tabCapture] >= 0} {
    error "Missing permission: tabCapture"
}
set hostPermissions [dict get $manifest host_permissions]
if {![lsearch -exact $hostPermissions http://127.0.0.1/*] >= 0} {
    error "Missing host permission: http://127.0.0.1/*"
}
if {![lsearch -exact $hostPermissions http://localhost/*] >= 0} {
    error "Missing host permission: http://localhost/*"
}
if {[lsearch -exact $permissions cookies] >= 0} {
    error "Unexpected permission: cookies"
}
if {[lsearch -exact $permissions webRequestBlocking] >= 0} {
    error "Unexpected permission: webRequestBlocking"
}
if {[lsearch -exact $permissions nativeMessaging] >= 0} {
    error "Unexpected permission: nativeMessaging"
}
set contentScripts [dict get $manifest content_scripts]
set firstScriptJs [dict get [lindex $contentScripts 0] js]
if {[lindex $firstScriptJs 0] ne "vendor-mpegts.js"} {
    error "First script JS mismatch"
}
set mpegtsVendorPath [file join $extension vendor-mpegts.js]
set mpegtsLicensePath [file join $extension vendor-mpegts.LICENSE.txt]
set mpegtsNoticePath [file join $extension vendor-mpegts.NOTICE.md]
if {![file exists $mpegtsVendorPath]} {
    error "MPEG-TS vendor path missing"
}
if {![file exists $mpegtsLicensePath]} {
    error "MPEG-TS license path missing"
}
if {![file exists $mpegtsNoticePath]} {
    error "MPEG-TS notice path missing"
}
set mpegtsFile [open $mpegtsVendorPath r]
set mpegtsContent [read $mpegtsFile]
close $mpegtsFile
set hash [sha2::sha256 -hex $mpegtsContent]
if {[string toupper $hash] ne "0786F9AF6780822FF29240259A73B07ED7BC479BC44966E49418DD38213B8064"} {
    error "SHA256 hash mismatch for MPEG-TS vendor file"
}
if {![string match "*location.hostname !== \"www.tiktok.com\"*" $mobileBridge]} {
    error "Mobile bridge missing hostname check"
}
if {[string match "*document.cookie*" $mobileBridge]} {
    error "Mobile bridge should not contain document.cookie"
}
if {![string match "*QUICK_RECOVER_RELOAD_COOLDOWN_MS = 400*" $mobileBridge]} {
    error "Mobile bridge missing quick recover cooldown constant"
}
if {![string match "*\"set-auto-reconnect\"*" $mobileBridge]} {
    error "Mobile bridge missing auto reconnect command"
}
if {![string match "*\"set-limiter\"*" $mobileBridge]} {
    error "Mobile bridge missing limiter command"
}

# Check existence of all referenced files in manifest
foreach relative [list \
    [dict get $manifest background service_worker] \
    [dict get $manifest side_panel default_path] \
    {*}[join [lmap item $contentScripts {dict get $item js}]]] {
    set fullPath [file join $extension $relative]
    if {![file exists $fullPath]} {
        error "Missing manifest file: $relative"
    }
}

# Validate each script file
set scripts [glob -directory $extension *.js]
foreach name $scripts {
    set sourceFile [open $name r]
    set source [read $sourceFile]
    close $sourceFile
    # Basic syntax validation placeholder
    if {[regexp {\beval\s*\()} $source]} {
        error "$name contains eval()"
    }
    if {[regexp {new\s+Function\s*\()} $source]} {
        error "$name contains new Function()"
    }
    if {[regexp {\.innerHTML\s*=} $source]} {
        error "$name assigns innerHTML"
    }
}

# Metadata inspection tests
set metadata(room,caption_info,open) true
set metadata(room,caption_info,support_lang) {de en}
set metadata(room,caption_info,show_type) 1
set metadata(room,stream_data) "{\"pull\":\"https:\\/\\/pull-flv-f77.example.tiktokcdn.com\\/stage\\/stream_hd.flv?expire=1\\u0026sign=abc\",\"hls\":\"https:\\/\\/pull-hls.example.tiktokcdn-eu.com\\/stage\\/stream_720p.m3u8?sign=xyz\"}"

set inspected [inspectMetadata metadata]
if {[dict get $inspected captionInfo present] ne true} {
    error "Caption info present assertion failed"
}
if {[dict get $inspected captionInfo open] ne true} {
    error "Caption info open assertion failed"
}
if {[dict get $inspected captionInfo supportLang] ne {de en}} {
    error "Support lang assertion failed"
}
if {[llength [dict get $inspected media]] ne 2} {
    error "Media count assertion failed"
}
set foundFlvHd false
set foundHls720p false
foreach item [dict get $inspected media] {
    if {[dict get $item protocol] eq "FLV" && [dict get $item quality] eq "HD"} {
        set foundFlvHd true
    }
    if {[dict get $item protocol] eq "HLS" && [dict get $item quality] eq "720p"} {
        set foundHls720p true
    }
}
if {!$foundFlvHd || !$foundHls720p} {
    error "Media protocols/qualities assertion failed"
}
if {[classifyMediaUrl "https://evil.example/stream.flv"] ne ""} {
    error "Classify media URL returned non-null for evil URL"
}
if {[dict get [sanitizeChatText "Hallo 😊 Welt ❤️"] text] ne "Hallo Welt"} {
    error "Sanitize chat text failed"
}
if {[wordCount "Hallo 😊 schöne Welt"] ne 3} {
    error "Word count assertion failed"
}
if {[teamSuffixCandidate "Miimii tmm"] ne "tmm"} {
    error "Team suffix candidate assertion failed"
}
if {[stripTeamTag "@Honey tmm wo is mein Tee?" "tmm"] ne "@Honey wo is mein Tee?"} {
    error "Strip team tag assertion failed"
}
if {[shortenNickname "Anja Schaarschmidt89"] ne "Anja"} {
    error "Shorten nickname assertion failed"
}
if {[spokenNickname "user572838499281727393816181"] ne "user572"} {
    error "Spoken nickname assertion failed"
}
if {[collapseLaughter "hahahahahahhhhahhhaaaa Gott du Plemmi"] ne "haha Gott du Plemmi"} {
    error "Collapse laughter assertion failed"
}
if {[resolveSpeechLanguage "auto" "de"] ne "de-DE"} {
    error "Resolve speech language assertion failed"
}
if {[limiterStrengthToDbfs 0] ne -4} {
    error "Limiter strength to dBFS assertion failed"
}
if {[limiterDbfsToStrength -30] ne 100} {
    error "Limiter dBFS to strength assertion failed"
}
set makeupLow [limiterMakeupCompensation -30 20]
set makeupHigh [limiterMakeupCompensation -10 20]
if {$makeupLow >= $makeupHigh} {
    error "Limiter makeup compensation assertion failed"
}
set composedText [composeSpeechText [dict create author "Miimii tmm" content "@Stivinho danke"] [dict create teamTag "tmm"]]
if {$composedText ne "Miimii sagt zu Stivinho danke"} {
    error "Compose speech text assertion failed"
}
set teamEvidence [accumulateTeamEvidence {} "Miimii tmm" "Teilt den Stream" {}]
if {[dict get $teamEvidence teamTag] ne ""} {
    error "Initial team evidence assertion failed"
}
set teamEvidence [accumulateTeamEvidence [dict get $teamEvidence evidence] "Honey tmm" "wo ist mein Tee?" {"Teilt den Stream"}]
if {[dict get $teamEvidence teamTag] ne "tmm"} {
    error "Accumulate team evidence assertion failed"
}
if {[streamIdentityChanged [dict create handle "demo" roomId "1"] [dict create handle "demo" roomId "1"]] ne false} {
    error "Stream identity changed assertion failed"
}
if {[liveHandleFromUrl "https://www.tiktok.com/@Demo/live"] ne "demo"} {
    error "Live handle from URL assertion failed"
}
if {[parseCompactCount "3,231"] ne 3231} {
    error "Parse compact count assertion failed"
}
set recommendationItems [dedupeRecommendations [list \
    [dict create handle "@Alpha" displayName "" title "Erster Stream" viewerCount null url "https://www.tiktok.com/@alpha/live" position 1] \
    [dict create handle "alpha" displayName "Alpha Live" viewerCount 123 viewerLabel "123" position 2] \
    [dict create handle "Beta" displayName "Beta" viewerCount 500 url "https://www.tiktok.com/@beta/live" position 3] \
    [dict create handle "gamma" displayName "Gamma" viewerCount null url "https://www.tiktok.com/@gamma/live" position 2]]]
if {[llength $recommendationItems] ne 3} {
    error "Dedupe recommendations count assertion failed"
}
set sortedHandles [lmap item [sortRecommendations $recommendationItems] {dict get $item handle}]
if {$sortedHandles ne {alpha gamma beta}} {
    error "Sort recommendations assertion failed"
}
set profileAndSummary [inspectMetadata [dict create \
    live_ai_summary_ui [dict create vid "v2"] \
    userInfo [dict create uniqueId "demo" nickname "Demo" signature "Eine Bio" stats [dict create followingCount 12 followerCount 345 heartCount 678]]]]
if {[dict get $profileAndSummary profileInfo present] ne true} {
    error "Profile info present assertion failed"
}
if {[dict get $profileAndSummary aiSummaryInfo featureFlagPresent] ne true} {
    error "AI summary info feature flag present assertion failed"
}
set actualSummary [inspectMetadata [dict create live_summary_text "Eine tatsächlich gelieferte Zusammenfassung."]]
if {[dict get $actualSummary aiSummaryInfo text] ne "Eine tatsächlich gelieferte Zusammenfassung."} {
    error "Actual summary text assertion failed"
}
set pullData(options,qualities) [list \
    [dict create sdk_key "origin" name "Original"] \
    [dict create sdk_key "hd" name "720p"] \
    [dict create sdk_key "sd" name "540p"] \
    [dict create sdk_key "ld" name "360p"]]
set pullData(stream_data) [::json::dict2json [dict create data [dict create \
    origin [dict create main [dict create flv "https://pull.example.tiktokcdn.com/live/stream_origin.flv" sdk_params [::json::dict2json [dict create VCodec "h265" vbitrate 2600000 width 1920 height 1080 fps 60]]]] \
    hd [dict create main [dict create flv "https://pull.example.tiktokcdn.com/live/stream_hd.flv" hls "https://pull.example.tiktokcdn.com/live/stream_hd.m3u8" sdk_params [::json::dict2json [dict create VCodec "h264" vbitrate 1800000 width 1280 height 720 fps 30]]]] \
    sd [dict create main [dict create flv "https://pull.example.tiktokcdn.com/live/stream_sd.flv" sdk_params [::json::dict2json [dict create VCodec "h264" vbitrate 900000 width 960 height 540 fps 30]]]] \
    ld [dict create main [dict create flv "https://pull.example.tiktokcdn.com/live/stream_ld.flv" sdk_params [::json::dict2json [dict create VCodec "h264" vbitrate 600000 width 640 height 360 fps 30]]]]]]]
set variants [extractStreamVariants pullData]
if {[llength $variants] ne 5} {
    error "Extract stream variants count assertion failed"
}
set foundOrigin false
set foundHd false
set foundSd false
set foundLd false
foreach variant $variants {
    switch [dict get $variant sdkKey] {
        "origin" {set foundOrigin true}
        "hd" {set foundHd true}
        "sd" {set foundSd true}
        "ld" {set foundLd true}
    }
}
if {!$foundOrigin || !$foundHd || !$foundSd || !$foundLd} {
    error "Extract stream variants details assertion failed"
}

# Proto decoding tests
set captionContent [concat [bytesField 1 "de"] [bytesField 2 "Guten Abend"]]
set captionPayload [concat \
    [intField 2 123456] \
    [intField 3 1500] \
    [bytesField 4 $captionContent] \
    [intField 5 77] \
    [intField 6 3] \
    [intField 7 1]]
set baseMessage [concat [bytesField 1 "WebcastCaptionMessage"] [bytesField 2 $captionPayload]]
set fetchResult [bytesField 1 $baseMessage]
set decoded [decodeFetchResult $fetchResult]
if {[llength [dict get $decoded captions]] ne 1} {
    error "Decode fetch result captions count assertion failed"
}
set caption [lindex [dict get $decoded captions] 0]
if {[dict get $caption contents 0 lang] ne "de"} {
    error "Caption language assertion failed"
}
if {[dict get $caption contents 0 text] ne "Guten Abend"} {
    error "Caption text assertion failed"
}
if {[dict get $caption sentenceId] ne "77"} {
    error "Sentence ID assertion failed"
}
if {[dict get $caption definite] ne true} {
    error "Definite assertion failed"
}

# Chat message decoding test
set chatUser [concat [intField 1 123] [bytesField 3 "Demo 😊"] [bytesField 38 "demo_user"]]
set chatPayload [concat \
    [bytesField 1 [concat [intField 2 9010]]] \
    [bytesField 2 $chatUser] \
    [bytesField 3 "Guten Abend ❤️"] \
    [bytesField 14 "de"]]
set chatFetch [bytesField 1 [concat [bytesField 1 "WebcastChatMessage"] [bytesField 2 $chatPayload]]]
set chatDecoded [dict get [decodeFetchResult $chatFetch] chatMessages]
if {[llength $chatDecoded] ne 1} {
    error "Chat messages count assertion failed"
}
set chatMsg [lindex $chatDecoded 0]
if {[dict get $chatMsg messageId] ne "9010"} {
    error "Chat message ID assertion failed"
}
if {[dict get $chatMsg nickname] ne "Demo 😊"} {
    error "Chat nickname assertion failed"
}
if {[dict get $chatMsg displayId] ne "demo_user"} {
    error "Chat display ID assertion failed"
}
if {[dict get $chatMsg content] ne "Guten Abend ❤️"} {
    error "Chat content assertion failed"
}
if {[dict get $chatMsg contentLanguage] ne "de"} {
    error "Chat content language assertion failed"
}

# Gift message decoding test
set giftPayload [concat \
    [bytesField 1 [concat [intField 2 9020]]] \
    [intField 2 777] \
    [intField 5 23] \
    [bytesField 7 $chatUser] \
    [intField 9 1]]
set giftFetch [bytesField 1 [concat [bytesField 1 "WebcastGiftMessage"] [bytesField 2 $giftPayload]]]
set giftDecoded [dict get [decodeFetchResult $giftFetch] giftMessages]
if {[llength $giftDecoded] ne 1} {
    error "Gift messages count assertion failed"
}
set giftMsg [lindex $giftDecoded 0]
if {[dict get $giftMsg nickname] ne "Demo 😊"} {
    error "Gift nickname assertion failed"
}
if {[dict get $giftMsg repeatCount] ne "23"} {
    error "Gift repeat count assertion failed"
}

# Live events decoding test
set common [concat [intField 2 9001] [bytesField 8 [bytesField 1 "pm_mt_msg_viewer"]]]
set roomUsers [concat [bytesField 1 $common] [intField 3 143] [intField 7 15842]]
set likes [concat [bytesField 1 $common] [intField 2 10] [intField 3 430200]]
set socialCommon [concat [intField 2 9002] [bytesField 8 [bytesField 1 "pm_main_follow_message_viewer_2"]]]
set social [concat [bytesField 1 $socialCommon] [intField 6 238800]]
set liveFetch [concat \
    [bytesField 1 [concat [bytesField 1 "WebcastRoomUserSeqMessage"] [bytesField 2 $roomUsers]]] \
    [bytesField 1 [concat [bytesField 1 "WebcastLikeMessage"] [bytesField 2 $likes]]] \
    [bytesField 1 [concat [bytesField 1 "WebcastSocialMessage"] [bytesField 2 $social]]]]
set liveDecoded [dict get [decodeFetchResult $liveFetch] liveEvents]
if {[llength $liveDecoded] ne 3} {
    error "Live events count assertion failed"
}
set event1 [lindex $liveDecoded 0]
set event2 [lindex $liveDecoded 1]
set event3 [lindex $liveDecoded 2]
if {[dict get $event1 viewerCount] ne "143"} {
    error "Viewer count assertion failed"
}
if {[dict get $event1 totalViewers] ne "15842"} {
    error "Total viewers assertion failed"
}
if {[dict get $event2 likeCount] ne "430200"} {
    error "Like count assertion failed"
}
if {[dict get $event3 kind] ne "follow"} {
    error "Kind assertion failed"
}
if {[dict get $event3 followerCount] ne "238800"} {
    error "Follower count assertion failed"
}

puts "PASS: manifest 0.8.2, [llength $scripts] scripts, chat speech composition, gifts, audience statistics, service controls and security guards"
