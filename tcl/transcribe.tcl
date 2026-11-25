#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "cd514dc57bdab996276c84920dea5c042bc6f55d49d954c52e2de1060ccea5f3", "source_sha256": "9c8abc93c198b77f804a6837db7baf1e85c902dc35a853c8086222a89f83fc89", "target_language": "tcl"}
# transcribe.sh — portiert nach tcl
# Quelle: shell, workspace@local:skills/github-clones/openclaw/skills/openai-whisper-api/scripts/transcribe.sh
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

proc usage {} {
    puts stderr {Usage:
  transcribe.tcl <audio-file> \[--model whisper-1\] \[--out /path/to/out.txt\] \[--language en\] \[--prompt "hint"\] \[--json\]}
    exit 2
}

# Prüfe Kommandozeilenargumente
if {$argc == 0 || [lindex $argv 0] eq "-h" || [lindex $argv 0] eq "--help"} {
    usage
}

set in [lindex $argv 0]
set argv [lrange $argv 1 end]

set model "whisper-1"
set out ""
set language ""
set prompt ""
set response_format "text"

# Parse Argumente
while {[llength $argv] > 0} {
    set arg [lindex $argv 0]
    switch -- $arg {
        --model {
            if {[llength $argv] < 2} {
                puts stderr "Missing value for --model"
                usage
            }
            set model [lindex $argv 1]
            set argv [lrange $argv 2 end]
        }
        --out {
            if {[llength $argv] < 2} {
                puts stderr "Missing value for --out"
                usage
            }
            set out [lindex $argv 1]
            set argv [lrange $argv 2 end]
        }
        --language {
            if {[llength $argv] < 2} {
                puts stderr "Missing value for --language"
                usage
            }
            set language [lindex $argv 1]
            set argv [lrange $argv 2 end]
        }
        --prompt {
            if {[llength $argv] < 2} {
                puts stderr "Missing value for --prompt"
                usage
            }
            set prompt [lindex $argv 1]
            set argv [lrange $argv 2 end]
        }
        --json {
            set response_format "json"
            set argv [lrange $argv 1 end]
        }
        default {
            puts stderr "Unknown arg: $arg"
            usage
        }
    }
}

# Prüfe ob Eingabedatei existiert
if {![file exists $in]} {
    puts stderr "File not found: $in"
    exit 1
}

# Prüfe API-Key
if {![info exists ::env(OPENAI_API_KEY)] || $::env(OPENAI_API_KEY) eq ""} {
    puts stderr "Missing OPENAI_API_KEY"
    exit 1
}

# Bestimme Ausgabedatei wenn nicht angegeben
if {$out eq ""} {
    set base [file rootname $in]
    if {$response_format eq "json"} {
        set out "${base}.json"
    } else {
        set out "${base}.txt"
    }
}

# Erstelle Zielverzeichnis
file mkdir [file dirname $out]

# Setze API-Basis-URL
set api_base "https://api.openai.com/v1"
if {[info exists ::env(OPENAI_BASE_URL)] && $::env(OPENAI_BASE_URL) ne ""} {
    set api_base $::env(OPENAI_BASE_URL)
}
set api_base [string trimright $api_base "/"]

# Baue curl-Kommando zusammen
set cmd [list exec curl -sS "${api_base}/audio/transcriptions"]
lappend cmd -H "Authorization: Bearer $::env(OPENAI_API_KEY)"
lappend cmd -H "Accept: application/json"
lappend cmd -F "file=@$in"
lappend cmd -F "model=$model"
lappend cmd -F "response_format=$response_format"
if {$language ne ""} {
    lappend cmd -F "language=$language"
}
if {$prompt ne ""} {
    lappend cmd -F "prompt=$prompt"
}
lappend cmd ">$out"

# Führe curl aus
if {[catch {eval $cmd} result]} {
    puts stderr "curl failed: $result"
    exit 1
}

puts $out
