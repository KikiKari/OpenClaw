#!/usr/bin/env tclsh
# test_external_speech_filter.cjs — portiert nach tcl
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/scripts/test_external_speech_filter.cjs
# Erzeugt: 2026-10-23 durch ABSTRACTIONS_MANAGER.py

# Tcl-Portierung der Tests für den externen Sprachfilter

# Hilfsfunktionen zur Emulation der JavaScript-Funktionalität
proc shouldFilterExternalSpeechTrigger {text enabled {prefixes "."}} {
    if {!$enabled} {
        return false
    }
    
    # trimStart() emulieren
    set trimmedText [string trimleft $text]
    
    # startsWith() emulieren
    foreach prefix [split $prefixes ""] {
        if {[string first $prefix $trimmedText] == 0 && [string length $prefix] > 0} {
            return true
        }
    }
    return false
}

proc normalizeExternalSpeechTriggerCharacters {text} {
    if {$text eq "" || $text eq "undefined"} {
        return "."
    }
    
    # Entferne führende/trailing Leerzeichen
    set cleaned [string trim $text]
    
    # Behalte nur gültige Trigger-Zeichen
    set validChars ""
    set allowed ".,"
    
    for {set i 0} {$i < [string length $cleaned]} {incr i} {
        set char [string index $cleaned $i]
        if {[string first $char $allowed] != -1 || [regexp {[!;:]|\p{Emoji}] $char]} {
            append validChars $char
        }
    }
    
    # Begrenze auf maximal 5 Zeichen
    if {[string length $validChars] > 5} {
        set validChars [string range $validChars 0 4]
    }
    
    return $validChars
}

# Test-Framework in Tcl
proc run_test {name expected actual} {
    if {$expected ne $actual && ($expected ne "true" || $actual ne "1") && ($expected ne "false" || $actual ne "0")} {
        puts "FAIL: $name - Expected '$expected', got '$actual'"
    } else {
        puts "PASS: $name"
    }
}

# Haupttests
foreach enabled {false true} {
    foreach text {.Text {. Text} {  .Text} {\t\n. Text} Normal {Ein Satz. Noch einer} {}} {
        set json_repr "\\{\"enabled\":$enabled,\"text\":\"[string map {{ } {\\ }} $text]\"\\}"
        set result [shouldFilterExternalSpeechTrigger $text $enabled]
        set expected [expr {$enabled && ([string trimleft $text] ne "") && [string first "." [string trimleft $text]] == 0}]
        run_test $json_repr $expected $result
    }
}

# 0PE-187: individuelle Präfixe
foreach enabled {false true} {
    foreach text {.Hallo ,Hallo {- Hallo} {  , Hallo}} {
        set result [shouldFilterExternalSpeechTrigger $text $enabled .,-]
        set expected [expr {$enabled}]
        run_test "individual_prefixes_1_$enabled-[string map {{ } {_} \\  {}} $text]" $expected $result
    }
    
    foreach text {{Hallo, zusammen.} {Normal-Text} Hallo .} {
        set result [shouldFilterExternalSpeechTrigger $text $enabled ,\-]
        set expected false
        run_test "individual_prefixes_2_$enabled-[string map {{ } {_}} $text]" $expected $result
    }
    
    set result [shouldFilterExternalSpeechTrigger {;Hallo} $enabled \;]
    set expected [expr {$enabled}]
    run_test "semicolon_$enabled" $expected $result
    
    set result [shouldFilterExternalSpeechTrigger {\[Hallo} $enabled \[]
    set expected [expr {$enabled}]
    run_test "bracket_open_$enabled" $expected $result
    
    set result [shouldFilterExternalSpeechTrigger Hallo $enabled \[]
    set expected false
    run_test "no_bracket_$enabled" $expected $result
}

# 0PE-187: Unicode-Triggers und Normalisierung
set result [normalizeExternalSpeechTriggerCharacters undefined]
run_test "normalize_undefined" "." $result

set result [normalizeExternalSpeechTriggerCharacters ""]
run_test "normalize_empty" "" $result

set result [normalizeExternalSpeechTriggerCharacters ".,-;:!" ]
run_test "normalize_punctuation" ".,-;:" $result

set result [normalizeExternalSpeechTriggerCharacters " a1 \"'.,- "]
run_test "normalize_spaces_and_quotes" ".,-" $result

set result [normalizeExternalSpeechTriggerCharacters "😀😁😂😃😄😅"]
run_test "normalize_emoji" "😀😁😂😃😄" $result

set result [shouldFilterExternalSpeechTrigger {😀Hallo} true 😀]
run_test "filter_emoji_true" true $result

set result [shouldFilterExternalSpeechTrigger {.Hallo} true {}]
run_test "filter_dot_empty_prefixes" false $result

set result [shouldFilterExternalSpeechTrigger {.Hallo} true ,]
run_test "filter_dot_comma_prefixes" false $result
