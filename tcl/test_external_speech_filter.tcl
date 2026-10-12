#!/usr/bin/env tclsh
# test_external_speech_filter.cjs — portiert nach tcl
# Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/scripts/test_external_speech_filter.cjs
# auch in: Projects@codex/0pe-177-peak-protection:plugin-source/scripts/test_external_speech_filter.cjs
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

# Paketimporte und Setup
package require Tcl 8.6

# Funktion zur Überprüfung, ob externer Sprachauslöser gefiltert werden soll
proc shouldFilterExternalSpeechTrigger {text enabled} {
    if {!$enabled} {
        return false
    }
    # Entferne führende Leerzeichen und prüfe, ob der Text mit '.' beginnt
    set trimmed [string trimleft $text]
    if {[string length $trimmed] > 0 && [string index $trimmed 0] eq "."} {
        return true
    }
    return false
}

# Testfälle definieren
set testCases [list]
foreach enabled [list false true] {
    foreach text [list ".Text" ". Text" "  .Text" "\t\n. Text" "Normal" "Ein Satz. Noch einer" ""] {
        lappend testCases [list $text $enabled]
    }
}

# Testfunktion
proc runTest {text enabled} {
    set result [shouldFilterExternalSpeechTrigger $text $enabled]
    set expected [expr {$enabled && [string match .* [string trimleft $text]]}]
    if {$result != $expected} {
        puts "FAIL: text='$text', enabled=$enabled -> got $result, expected $expected"
        exit 1
    }
}

# Tests ausführen
foreach case $testCases {
    foreach {text enabled} $case break
    runTest $text $enabled
}

puts "All tests passed."
