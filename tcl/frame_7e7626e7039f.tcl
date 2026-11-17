#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "cebc5af73d58ac0b2cd29f0d87dc36e7c4c233da8b402dcc766031de6988e5ba", "source_sha256": "b339455e9e618c836ccf2e3732e4fec9897f079730d8814eadb716e2459df453", "target_language": "tcl"}
# frame.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:skills/video-frames/scripts/frame.sh
# auch in: OpenClaw@gateway2:skills/video-frames/scripts/frame.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

proc usage {} {
    puts stderr {Usage:
  frame.tcl <video-file> \[--time HH:MM:SS\] \[--index N\] --out /path/to/frame.jpg

Examples:
  frame.tcl video.mp4 --out /tmp/frame.jpg
  frame.tcl video.mp4 --time 00:00:10 --out /tmp/frame-10s.jpg
  frame.tcl video.mp4 --index 0 --out /tmp/frame0.png}
    exit 2
}

# Prüfe auf Hilfe-Optionen oder fehlende Argumente
if {[llength $argv] == 0 || [lindex $argv 0] eq "-h" || [lindex $argv 0] eq "--help"} {
    usage
}

set in [lindex $argv 0]
set argv [lrange $argv 1 end]

set time ""
set index ""
set out ""

# Parse Kommandozeilenargumente
while {[llength $argv] > 0} {
    set arg [lindex $argv 0]
    switch -- $arg {
        --time {
            if {[llength $argv] < 2} {
                puts stderr "Missing value for --time"
                usage
            }
            set time [lindex $argv 1]
            set argv [lrange $argv 2 end]
        }
        --index {
            if {[llength $argv] < 2} {
                puts stderr "Missing value for --index"
                usage
            }
            set index [lindex $argv 1]
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

# Erstelle Zielverzeichnis falls nötig
set out_dir [file dirname $out]
if {![file exists $out_dir]} {
    file mkdir $out_dir
}

# Führe ffmpeg-Befehl entsprechend den Optionen aus
if {$index ne ""} {
    # Extrahiere Frame an spezifischem Index
    exec ffmpeg -hide_banner -loglevel error -y \
        -i $in \
        -vf "select=eq(n\\,$index)" \
        -vframes 1 \
        $out
} elseif {$time ne ""} {
    # Extrahiere Frame zu spezifischer Zeit
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

# Gebe Ausgabepfad aus
puts $out
