#!/usr/bin/env tclsh
# collect_compare_bundle.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/collect_compare_bundle.sh
# auch in: OpenClaw@gateway2:scripts/collect_compare_bundle.sh
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

package require Tcl 8.6

set ROOT "/home/openclaw/.openclaw"
set OUT_DIR "${ROOT}/workspace/vscode/compare"
set TRANSFER_DIR "${OUT_DIR}/transfer"
set MD_FILE "${OUT_DIR}/local-gateway-config.md"
set TREE_FILE "${OUT_DIR}/tree.txt"
set BACKUP_FILE "/home/openclaw/openclaw-backup.tar.gz"

# Zeitstempel und Hostname ermitteln
set NOW_LOCAL [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S %Z"]
set NOW_UTC [clock format [clock seconds] -gmt true -format "%Y-%m-%dT%H:%M:%SZ"]
if {[catch {exec hostname -f} HOST]} {
    set HOST [exec hostname]
}

set OPENCLAW_JSON "${ROOT}/openclaw.json"
set EXEC_APPROVALS_JSON "${ROOT}/exec-approvals.json"
set GATEWAY_SYSTEMD_ENV "${ROOT}/gateway.systemd.env"
set DOT_ENV "${ROOT}/.env"
set CONFIG_DIR "${ROOT}/.config"
set AGENTS_DIR "${ROOT}/agents"

# Ausgabeverzeichnisse erstellen
file mkdir $OUT_DIR
file mkdir $TRANSFER_DIR

# Prüfen ob 'tree' verfügbar ist
if {[catch {exec which tree}]} {
    puts "Fehler: 'tree' ist nicht installiert."
    exit 1
}

# Hilfsfunktion zum Anhängen von Dateiinhalten
proc append_file_verbatim {label path lang md_file} {
    set content ""
    if {[file exists $path] && [file readable $path]} {
        set fh [open $path r]
        set content [read $fh]
        close $fh
    } else {
        set content "\\[FEHLT\\] $path"
    }
    
    set fh [open $md_file a]
    puts $fh ""
    puts $fh "## $label"
    puts $fh ""
    puts $fh "Pfad: \\`$path\\`"
    puts $fh ""
    puts $fh "\\`\\`\\`$lang"
    puts $fh $content
    puts $fh ""
    puts $fh "\\`\\`\\`"
    close $fh
}

# Hilfsfunktion zum Anhängen der Umgebungsvariablen
proc append_env_verbatim {md_file} {
    set fh [open $md_file a]
    puts $fh ""
    puts $fh "## Umgebungsvariablen (env)"
    puts $fh ""
    puts $fh "\\`\\`\\`text"
    foreach {key value} [array get env] {
        puts $fh "$key=$value"
    }
    puts $fh "\\`\\`\\`"
    close $fh
}

# Hilfsfunktion zum Anhängen von Verzeichnisinhalten
proc append_dir_files_verbatim {section dir md_file} {
    set fh [open $md_file a]
    puts $fh ""
    puts $fh "## $section"
    puts $fh ""
    if {![file isdirectory $dir]} {
        puts $fh "\\[FEHLT\\] $dir"
        close $fh
        return
    }
    puts $fh "Basisverzeichnis: \\`$dir\\`"
    close $fh
    
    # Alle Dateien im Verzeichnis finden und sortieren
    if {[catch {glob -nocomplain -dir $dir -types f - recurse *} files]} {
        set files {}
    }
    set files [lsort $files]
    
    foreach f $files {
        set fh [open $md_file a]
        puts $fh ""
        puts $fh "### Datei: \\`$f\\`"
        puts $fh ""
        puts $fh "\\`\\`\\`text"
        if {[file exists $f] && [file readable $f]} {
            set file_fh [open $f r]
            set content [read $file_fh]
            close $file_fh
            puts $fh $content
        }
        puts $fh ""
        puts $fh "\\`\\`\\`"
        close $fh
    }
}

# Markdown-Datei initial erstellen
set fh [open $MD_FILE w]
puts $fh "# Lokaler Gateway-Konfigurationsstand"
puts $fh ""
puts $fh "Generiert: $NOW_LOCAL"
puts $fh "UTC: $NOW_UTC"
puts $fh "Host: $HOST"
puts $fh ""
puts $fh "Diese Datei enthaelt den lokalen Stand mit unveraenderten Inhalten."
close $fh

# Dateien anhängen
append_file_verbatim "openclaw.json" $OPENCLAW_JSON "json" $MD_FILE
append_file_verbatim "exec-approvals.json" $EXEC_APPROVALS_JSON "json" $MD_FILE
append_file_verbatim "gateway.systemd.env" $GATEWAY_SYSTEMD_ENV "dotenv" $MD_FILE
append_file_verbatim ".env" $DOT_ENV "dotenv" $MD_FILE
append_env_verbatim $MD_FILE
append_dir_files_verbatim ".config (alle Dateien rekursiv)" $CONFIG_DIR $MD_FILE
append_dir_files_verbatim "agents (alle Dateien rekursiv)" $AGENTS_DIR $MD_FILE

# Baumstruktur generieren
exec tree -a -L 6 $ROOT > $TREE_FILE

# Backup erstellen
exec openclaw backup create --output $BACKUP_FILE --verify
file copy -force $BACKUP_FILE $OUT_DIR

puts "OK"
puts "Erzeugt:"
puts "- $MD_FILE"
puts "- $TREE_FILE"
puts "- $BACKUP_FILE"
puts "- $TRANSFER_DIR (leer)"
