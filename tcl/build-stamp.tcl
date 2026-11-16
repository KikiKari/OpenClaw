#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "a0a4cf2f9463b6c82f516ca0ddb259a863164b0d635611e7596cfd4d3e2cd94b", "source_sha256": "8537e4253cc6ca148bc7b8cee5f458bfd0843576263cad8e98ca2c46fa47f2f1", "target_language": "tcl"}
# build-stamp.mjs — portiert nach tcl
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-stamp.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package require fileutil
package require json

proc resolveGitHead {{params ""}} {
    # Standardverhalten simulieren: leeres Dict als Default
    if {$params eq ""} {
        set params [dict create]
    }

    # CWD bestimmen - entweder aus params oder aktuelles Verzeichnis
    set cwd [expr {[dict exists $params cwd] ? [dict get $params cwd] : [pwd]}]

    # Führe git rev-parse HEAD aus
    if {[catch {exec git -C $cwd rev-parse HEAD} result]} {
        return ""
    }

    set head [string trim $result]
    if {$head eq ""} {
        return ""
    }
    return $head
}

proc writeBuildStamp {{params ""}} {
    # Standardverhalten simulieren: leeres Dict als Default
    if {$params eq ""} {
        set params [dict create]
    }

    # CWD bestimmen - entweder aus params oder aktuelles Verzeichnis
    set cwd [expr {[dict exists $params cwd] ? [dict get $params cwd] : [pwd]}]

    # Zeitstempel ermitteln (Millisekunden seit Epoche)
    set now [expr {[clock milliseconds]}]

    # Pfade definieren
    set distRoot [file join $cwd "dist"]
    set buildStampPath [file join $distRoot ".buildstamp"]

    # Git-Head auflösen
    set head [resolveGitHead $params]

    # Zielverzeichnis erstellen
    file mkdir $distRoot

    # JSON-Inhalt erstellen
    set jsonContent [dict create builtAt $now]
    if {$head ne ""} {
        dict set jsonContent head $head
    }

    # Inhalt in Datei schreiben
    set fd [open $buildStampPath w]
    puts $fd [::json::write object {*}$jsonContent]
    close $fd

    return $buildStampPath
}

# Hauptausführung nur wenn das Skript direkt aufgerufen wird
# In Tcl gibt es keinen direkten Vergleich zu import.meta.url,
# daher prüfen wir einfach den Skriptnamen
if {[info script] eq $argv0} {
    if {[catch {writeBuildStamp} error]} {
        puts stderr $error
        exit 1
    }
}
