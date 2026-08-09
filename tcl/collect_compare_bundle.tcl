#!/usr/bin/env tclsh8.6
# collect_compare_bundle.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/collect_compare_bundle.sh
# auch in: OpenClaw@gateway2:scripts/collect_compare_bundle.sh
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

set ROOT "/home/openclaw/.openclaw"
set OUT_DIR "${ROOT}/workspace/vscode/compare"
set TRANSFER_DIR "${OUT_DIR}/transfer"
set MD_FILE "${OUT_DIR}/local-gateway-config.md"
set TREE_FILE "${OUT_DIR}/tree.txt"
set BACKUP_FILE "/home/openclaw/openclaw-backup.tar.gz"

# Zeitstempel und Hostname ermitteln
set NOW_LOCAL [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S %Z"]
set NOW_UTC [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%SZ" -timezone :UTC]
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
    puts stderr "Fehler: 'tree' ist nicht installiert."
    exit 1
}

# Hilfsfunktion zum Anhängen einer Datei im Markdown-Format
proc append_file_verbatim {label path lang} {
    global MD_FILE
    set fp [open $MD_FILE a]
    puts $fp ""
    puts $fp "## $label"
    puts $fp ""
    puts $fp "Pfad: \`$path\`"
    puts $fp ""
    puts $fp "```$lang"
    if {[file exists $path]} {
        set infile [open $path r]
        while {[gets $infile line] >= 0} {
            puts $fp $line
        }
        close $infile
    } else {
        puts $fp "\[FEHLT\] $path"
    }
    puts $fp ""
    puts $fp "```"
    close $fp
}

# Hilfsfunktion zum Anhängen der Umgebungsvariablen
proc append_env_verbatim {} {
    global MD_FILE
    set fp [open $MD_FILE a]
    puts $fp ""
    puts $fp "## Umgebungsvariablen (env)"
    puts $fp ""
    puts $fp "```text"
    foreach envvar [lsort [array names ::env]] {
        puts $fp "$envvar=$::env($envvar)"
    }
    puts $fp "```"
    close $fp
}

# Hilfsfunktion zum Anhängen aller Dateien eines Verzeichnisses
proc append_dir_files_verbatim {section dir} {
    global MD_FILE
    set fp [open $MD_FILE a]
    puts $fp ""
    puts $fp "## $section"
    puts $fp ""
    if {![file isdirectory $dir]} {
        puts $fp "\[FEHLT\] $dir"
        close $fp
        return
    }
    puts $fp "Basisverzeichnis: \`$dir\`"
    close $fp

    # Alle Dateien im Verzeichnis finden und sortieren
    set files [lsort [find_files_recursive $dir]]
    foreach f $files {
        set fp [open $MD_FILE a]
        puts $fp ""
        puts $fp "### Datei: \`$f\`"
        puts $fp ""
        puts $fp "```text"
        if {[file exists $f]} {
            set infile [open $f r]
            while {[gets $infile line] >= 0} {
                puts $fp $line
            }
            close $infile
        }
        puts $fp ""
        puts $fp "```"
        close $fp
    }
}

# Rekursive Suche nach Dateien
proc find_files_recursive {dir} {
    set result {}
    if {[file isdirectory $dir]} {
        foreach item [glob -nocomplain -dir $dir *] {
            if {[file isdirectory $item]} {
                lappend result {*}[find_files_recursive $item]
            } elseif {[file isfile $item]} {
                lappend result $item
            }
        }
    }
    return $result
}

# Markdown-Datei initial erstellen
set fp [open $MD_FILE w]
puts $fp "# Lokaler Gateway-Konfigurationsstand"
puts $fp ""
puts $fp "Generiert: $NOW_LOCAL"
puts $fp "UTC: $NOW_UTC"
puts $fp "Host: $HOST"
puts $fp ""
puts $fp "Diese Datei enthaelt den lokalen Stand mit unveraenderten Inhalten."
close $fp

# Dateien nacheinander anhängen
append_file_verbatim "openclaw.json" $OPENCLAW_JSON "json"
append_file_verbatim "exec-approvals.json" $EXEC_APPROVALS_JSON "json"
append_file_verbatim "gateway.systemd.env" $GATEWAY_SYSTEMD_ENV "dotenv"
append_file_verbatim ".env" $DOT_ENV "dotenv"
append_env_verbatim
append_dir_files_verbatim ".config (alle Dateien rekursiv)" $CONFIG_DIR
append_dir_files_verbatim "agents (alle Dateien rekursiv)" $AGENTS_DIR

# Baumstruktur ausgeben
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
