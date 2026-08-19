#!/usr/bin/env tclsh
# frame.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:skills/video-frames/scripts/frame.sh
# auch in: OpenClaw@gateway2:skills/video-frames/scripts/frame.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

proc usage {} {
    puts stderr {Usage:
  frame.tcl <video-file> \[--time HH:MM:SS\] \[--index N\] --out /path/to/frame.jpg

Examples:
  frame.tcl video.mp4 --out /tmp/frame.jpg
  frame.tcl video.mp4 --time 00:00:10 --out /tmp/frame-10s.jpg
  frame.tcl video.mp4 --index 0 --out /tmp/frame0.png}
    exit 2
}

# Prüfe auf Hilfe-Parameter oder leeres erstes Argument
if {[llength $argv] == 0 || [lindex $argv 0] eq "-h" || [lindex $argv 0] eq "--help"} {
    usage
}

# Initialisiere Variablen
set in [lindex $argv 0]
set argv [lassign $argv _]  ;# Entferne das erste Element

set time ""
set index ""
set out ""

# Parse die Kommandozeilenargumente
while {[llength $argv] > 0} {
    set arg [lindex $argv 0]
    switch -- $arg {
        --time {
            if {[llength $argv] < 2} {
                puts stderr "Missing value for --time"
                usage
            }
            set time [lindex $argv 1]
            set argv [lassign $argv _ _]
        }
        --index {
            if {[llength $argv] < 2} {
                puts stderr "Missing value for --index"
                usage
            }
            set index [lindex $argv 1]
            set argv [lassign $argv _ _]
        }
        --out {
            if {[llength $argv] < 2} {
                puts stderr "Missing value for --out"
                usage
            }
            set out [lindex $argv 1]
            set argv [lassign $argv _ _]
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

# Prüfe ob Ausgabepfad angegeben wurde
if {$out eq ""} {
    puts stderr "Missing --out"
    usage
}

# Erstelle das Ausgabeverzeichnis
file mkdir [file dirname $out]

# Führe ffmpeg entsprechend den Parametern aus
if {$index ne ""} {
    # Extrahiere Frame an bestimmtem Index
    exec ffmpeg -hide_banner -loglevel error -y \
        -i $in \
        -vf "select=eq(n\\,$index)" \
        -vframes 1 \
        $out
} elseif {$time ne ""} {
    # Extrahiere Frame zu bestimmter Zeit
    exec ffmpeg -hide_banner -loglevel error -y \
        -ss $time \
        -i $in \
        -frames:v 1 \
        $out
} else {
    # Extrahiere ersten Frame (Standardfall)
    exec ffmpeg -hide_banner -loglevel error -y \
        -i $in \
        -vf "select=eq(n\\,0)" \
        -vframes 1 \
        $out
}

# Gebe den Ausgabepfad aus
puts $out
