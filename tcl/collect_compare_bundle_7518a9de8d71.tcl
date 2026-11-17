#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "965d6372d2c4c5961184e746fd2749b6b1e4ee8fea5080539a2d885cea35023f", "source_sha256": "5aa602a80e57cbc63f54485d4cd66e205c54bd9f32bc03434218ff9bd388b3ab", "target_language": "tcl"}
# collect_compare_bundle.sh — portiert nach tcl
# Quelle: shell, OpenClaw@gateway1:scripts/collect_compare_bundle.sh
# auch in: OpenClaw@gateway2:scripts/collect_compare_bundle.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package require fileutil
package require cmdline

set ROOT "/home/openclaw/.openclaw"
set OUT_DIR "${ROOT}/workspace/vscode/compare"
set TRANSFER_DIR "${OUT_DIR}/transfer"
set MD_FILE "${OUT_DIR}/local-gateway-config.md"
set TREE_FILE "${OUT_DIR}/tree.txt"
set BACKUP_FILE "/home/openclaw/openclaw-backup.tar.gz"

# Get current time
set NOW_LOCAL [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S %Z"]
set NOW_UTC [clock format [clock seconds] -gmt true -format "%Y-%m-%dT%H:%M:%SZ"]

# Get hostname
if {[catch {exec hostname -f} HOST]} {
    set HOST [exec hostname]
}

set OPENCLAW_JSON "${ROOT}/openclaw.json"
set EXEC_APPROVALS_JSON "${ROOT}/exec-approvals.json"
set GATEWAY_SYSTEMD_ENV "${ROOT}/gateway.systemd.env"
set DOT_ENV "${ROOT}/.env"
set CONFIG_DIR "${ROOT}/.config"
set AGENTS_DIR "${ROOT}/agents"

# Create directories
file mkdir $OUT_DIR
file mkdir $TRANSFER_DIR

# Check if tree command exists
if {[catch {exec which tree}]} {
    puts stderr "Fehler: 'tree' ist nicht installiert."
    exit 1
}

proc append_file_verbatim {label path {lang "text"}} {
    global MD_FILE
    set fp [open $MD_FILE a]
    puts $fp ""
    puts $fp "## $label"
    puts $fp ""
    puts $fp "Pfad: `$path`"
    puts $fp ""
    puts $fp "```$lang"
    if {[file exists $path] && [file readable $path]} {
        set content [read [open $path r]]
        puts -nonewline $fp $content
    } else {
        puts $fp "\[FEHLT\] $path"
    }
    puts $fp ""
    puts $fp "```"
    close $fp
}

proc append_env_verbatim {} {
    global MD_FILE
    set fp [open $MD_FILE a]
    puts $fp ""
    puts $fp "## Umgebungsvariablen (env)"
    puts $fp ""
    puts $fp "```text"
    foreach var [lsort [array names ::env]] {
        puts $fp "$var=$::env($var)"
    }
    puts $fp "```"
    close $fp
}

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
    puts $fp "Basisverzeichnis: `$dir`"
    close $fp
    
    # Find all files recursively and sort them
    set files [lsort [glob -directory $dir -types f -nocomplain **]]
    foreach f $files {
        set fp [open $MD_FILE a]
        puts $fp ""
        puts $fp "### Datei: `$f`"
        puts $fp ""
        puts $fp "```text"
        if {[file exists $f] && [file readable $f]} {
            set content [read [open $f r]]
            puts -nonewline $fp $content
        }
        puts $fp ""
        puts $fp "```"
        close $fp
    }
}

# Write header to markdown file
set fp [open $MD_FILE w]
puts $fp "# Lokaler Gateway-Konfigurationsstand"
puts $fp ""
puts $fp "Generiert: $NOW_LOCAL"
puts $fp "UTC: $NOW_UTC"
puts $fp "Host: $HOST"
puts $fp ""
puts $fp "Diese Datei enthaelt den lokalen Stand mit unveraenderten Inhalten."
close $fp

append_file_verbatim "openclaw.json" $OPENCLAW_JSON "json"
append_file_verbatim "exec-approvals.json" $EXEC_APPROVALS_JSON "json"
append_file_verbatim "gateway.systemd.env" $GATEWAY_SYSTEMD_ENV "dotenv"
append_file_verbatim ".env" $DOT_ENV "dotenv"
append_env_verbatim
append_dir_files_verbatim ".config (alle Dateien rekursiv)" $CONFIG_DIR
append_dir_files_verbatim "agents (alle Dateien rekursiv)" $AGENTS_DIR

# Generate tree output
exec tree -a -L 6 $ROOT > $TREE_FILE

# Create backup
exec openclaw backup create --output $BACKUP_FILE --verify
file copy -force $BACKUP_FILE $OUT_DIR

puts "OK"
puts "Erzeugt:"
puts "- $MD_FILE"
puts "- $TREE_FILE"
puts "- $BACKUP_FILE"
puts "- $TRANSFER_DIR (leer)"
