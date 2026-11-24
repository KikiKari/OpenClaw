#!/usr/bin/env tclsh
# abstraction-provenance: {"artifact_sha256": "45536d89c0fa50ddda56d38cc3525570a0551ac47840202e3130b5d9650e462e", "source_sha256": "abd8d4ba00ec9fdd77f25b23ab47e935f021988f065beaf326675ccb0ef53522", "target_language": "tcl"}
# ABSTRACTIONS_MANAGER.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
# Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

# Script Abstractions Manager
#
# Uebersetzt jede Quelldatei aus den drei Repositories KikiKari/OpenClaw,
# KikiKari/Projects und KikiKari/Onboarding in zehn Zielsprachen und legt
# das Ergebnis in den Sprachverzeichnissen des Abstraktions-Repositories ab.
#
# Es entstehen vollstaendige Uebersetzungen, keine Ruempfe: jede Datei geht
# als Ganzes an ein Sprachmodell, das lauffaehigen Code in der Zielsprache
# zurueckgibt. Erzeugnisse, deren Syntax sich nicht pruefen laesst oder die
# erkennbar unfertig sind, werden verworfen statt abgelegt.
#
# Verwendung:
#     tclsh ABSTRACTIONS_MANAGER.tcl [--prioritaet high|medium|low|alle]
#                                    [--anzahl N] [--probelauf]
#
# Umgebung:
#     OPENROUTER_API_KEY      Pflicht. Schluessel fuer die Uebersetzung.
#     ABSTRACTIONS_WORKSPACE  Arbeitsverzeichnis, Vorgabe
#                             /home/openclaw/.openclaw/workspace
#     ABSTRACTIONS_MODELL     Modellkennung, Vorgabe siehe MODELLE
#     ABSTRACTIONS_ANZAHL     Quelldateien je Lauf, Vorgabe 40

package require Tcl 8.6
package require http
package require json
package require fileutil
package require sha256

# ---------------------------------------------------------------------------
# Konfiguration
# ---------------------------------------------------------------------------

set WORKSPACE [expr {[info exists ::env(ABSTRACTIONS_WORKSPACE)] ? $::env(ABSTRACTIONS_WORKSPACE) : "/home/openclaw/.openclaw/workspace"}]
set ABSTRACTIONS_REPO [file join $WORKSPACE git OpenClaw-gateway1-abstractions]
set QUELLEN_DIR [file join $WORKSPACE git quellen]
set LOG_DIR [file join $WORKSPACE logs abstractions-manager]
set STATE_FILE [file join $WORKSPACE db abstractions_state.json]

set GITHUB_BENUTZER "KikiKari"

# Herkunft der Quelldateien. Projects wird ueber alle Branches gelesen, weil
# dort jedes Projekt in einem eigenen verwaisten Branch liegt.
array set QUELLEN {
    OpenClaw   {main gateway1 gateway2}
    Projects   alle
    Onboarding {main}
}

# Dateiendung -> Quellsprache. Bestimmt zugleich, was eingelesen wird.
array set QUELLSPRACHEN {
    .pl      perl5
    .pm      perl5
    .raku    perl6
    .rakumod perl6
    .rb      ruby
    .lua     lua
    .go      go
    .ps1     powershell
    .psm1    powershell
    .sh      shell
    .bash    shell
    .tcl     tcl
    .html    html
    .htm     html
    .js      javascript
    .mjs     javascript
    .cjs     javascript
    .py      python
    .css     css
    .java    java
    .c       c
    .cpp     cpp
    .cc      cpp
    .cxx     cpp
    .php     php
    .fs      fsharp
    .fsx     fsharp
}

# Die zehn Zielverzeichnisse, nach der Vorlage aus
# OpenClaw@gateway1-abstractions. Sie liegen im Wurzelverzeichnis des
# Abstraktions-Repositories.
array set ZIELSPRACHEN {
    javascript {ext .js  bezeichnung "JavaScript fuer Node 20"}
    perl5      {ext .pl  bezeichnung "Perl 5 mit use strict und use warnings"}
    powershell {ext .ps1 bezeichnung "PowerShell 7"}
    python     {ext .py  bezeichnung "Python 3.12"}
    shell      {ext .sh  bezeichnung "Bash 5 mit set -euo pipefail"}
    tcl        {ext .tcl bezeichnung "Tcl 8.6"}
    perl6      {ext .raku bezeichnung "Raku"}
    ruby       {ext .rb bezeichnung "Ruby"}
    lua        {ext .lua bezeichnung "Lua"}
    go         {ext .go bezeichnung "Go"}
    java       {ext .java bezeichnung "Java"}
    c          {ext .c bezeichnung "C"}
    cpp        {ext .cpp bezeichnung "C++"}
    php        {ext .php bezeichnung "PHP"}
    fsharp     {ext .fs bezeichnung "F#"}
    css        {ext .css bezeichnung "CSS"}
}

# Verzeichnisse und Muster, die nie eingelesen werden.
set AUSSCHLUSS [list "node_modules/" "/.git/" "__pycache__/" "dist/" "build/" "vendor/" \
                     ".venv/" "site-packages/" "python-hardener-workspace/" ".artifacts/" \
                     "coverage/" ".next/" "target/" "/work/" "/backups/"]

set MAX_BYTES 200000

# Reihenfolge der Ausweichmodelle. Geprueft gegen das Konto: die Anbieter von
# OpenAI und Anthropic sind dort ueber die Privatsphaere-Einstellung
# ausgeschlossen ("All providers have been ignored"), diese hier antworten.
set MODELLE [list \
    "qwen/qwen3-coder" \
    "deepseek/deepseek-chat-v3.1" \
    "z-ai/glm-4.6" \
    "mistralai/codestral-2508" \
    "qwen/qwen-2.5-coder-32b-instruct" \
]

set API_URL "https://openrouter.ai/api/v1/chat/completions"
set ZEITLIMIT 240
set VERSUCHE 3

# Mindestreserven auf dem Gateway und auf den entfernten Nodes.
set GATEWAY_MIN_FREI [expr {40 * 1024 * 1024 * 1024}]
set NODE_MIN_FREI [expr {4 * 1024 * 1024 * 1024}]
set NODE_STATUS_MAX_ALTER_MS 300000

proc node_speicherstatus {} {
    # Liefert nur aktuelle freie Bytes, keyed by paired device identity.
    if {[catch {exec openclaw nodes status --json} result]} {
        return [dict create]
    }
    
    if {[catch {::json::json2dict $result} status]} {
        return [dict create]
    }
    
    set timestamp [dict get $status ts]
    set nodes [dict get $status nodes]
    
    if {![string is double $timestamp] || ![llength $nodes]} {
        return [dict create]
    }
    
    if {abs([clock milliseconds] - $timestamp) > $::NODE_STATUS_MAX_ALTER_MS} {
        return [dict create]
    }
    
    set available [dict create]
    foreach node $nodes {
        if {[dict get $node connected] ne "true"} {
            continue
        }
        
        set node_id [dict get $node nodeId]
        set stats [dict get $node hostStats]
        
        if {$node_id eq "" || ![dict exists $stats diskAvailableBytes] || ![dict exists $stats updatedAtMs]} {
            continue
        }
        
        set free [dict get $stats diskAvailableBytes]
        set updated [dict get $stats updatedAtMs]
        
        if {![string is integer $free] || $free < 0 || ![string is double $updated] || \
            abs($timestamp - $updated) > $::NODE_STATUS_MAX_ALTER_MS} {
            continue
        }
        
        dict set available $node_id $free
    }
    
    return $available
}

proc node_hat_reserve {node device_id frei} {
    # Unbekannte Werte sind nicht als ausreichender Speicher nachgewiesen.
    if {$node eq "node1"} {
        if {[catch {fileutil::file_size [file join $::WORKSPACE]} size]} {
            return false
        }
        return [expr {$size >= $::GATEWAY_MIN_FREI}]
    }
    
    set wert [dict get $frei $device_id]
    return [expr {[string is integer $wert] && $wert >= $::NODE_MIN_FREI}]
}

# ---------------------------------------------------------------------------
# Protokoll
# ---------------------------------------------------------------------------

proc _protokoll {} {
    # Richtet die Protokollierung nach stdout und, wenn moeglich, in eine Datei ein.
    variable logger_initialized
    
    if {[info exists logger_initialized]} {
        return
    }
    
    set logger_initialized 1
    
    # Create log directory
    if {![file exists $::LOG_DIR]} {
        file mkdir $::LOG_DIR
    }
    
    # Setup basic logging to stdout
    proc log_info {msg} {
        puts stderr "[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"] | INFO    | [info level 1]:$[info level 0] | $msg"
    }
    
    proc log_warning {msg} {
        puts stderr "[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"] | WARNING | [info level 1]:$[info level 0] | $msg"
    }
    
    proc log_error {msg} {
        puts stderr "[clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"] | ERROR   | [info level 1]:$[info level 0] | $msg"
    }
}

# ---------------------------------------------------------------------------
# Zustand
# ---------------------------------------------------------------------------

proc zustand_laden {} {
    # Liest den Zustand. Er merkt sich je Quelldatei-Hash die bereits
    # erzeugten Zielsprachen, damit ein erneuter Lauf nichts doppelt uebersetzt.
    if {[file exists $::STATE_FILE]} {
        if {[catch {open $::STATE_FILE r} fd]} {
            log_error "Zustand unlesbar ($fd) — Lauf wird angehalten"
            error "Zustand unlesbar"
        }
        
        if {[catch {read $fd} content] || [catch {close $fd}]} {
            log_error "Zustand unlesbar — Lauf wird angehalten"
            error "Zustand unlesbar"
        }
        
        if {[catch {::json::json2dict $content} state]} {
            log_error "Zustand unlesbar ($state) — Lauf wird angehalten"
            error "Zustand unlesbar"
        }
        
        return $state
    }
    
    return [dict create erledigt [dict create] statistik [dict create]]
}

proc zustand_speichern {zustand} {
    # Schreibt den Zustand atomar, damit ein Abbruch ihn nicht zerstoert.
    set temp_file [file join [file dirname $::STATE_FILE] ".zustand_[pid]"]
    
    if {[catch {open $temp_file w} fd]} {
        log_error "Zustand konnte nicht gespeichert werden: $fd"
        error "Zustand konnte nicht gespeichert werden"
    }
    
    if {[catch {puts $fd [::json::dict2json $zustand]}] || [catch {close $fd}]} {
        log_error "Zustand konnte nicht gespeichert werden"
        error "Zustand konnte nicht gespeichert werden"
    }
    
    if {[catch {file rename -force $temp_file $::STATE_FILE} err]} {
        log_error "Zustand konnte nicht gespeichert werden: $err"
        error "Zustand konnte nicht gespeichert werden"
    }
}

# ---------------------------------------------------------------------------
# Quellen holen
# ---------------------------------------------------------------------------

proc _git {args} {
    # Fuehrt einen Git-Befehl aus und gibt das Ergebnis zurueck, ohne zu werfen.
    set cmd [concat git $args]
    if {[catch {exec {*}$cmd} result]} {
        return [list returncode 1 stdout "" stderr $result]
    }
    return [list returncode 0 stdout $result stderr ""]
}

proc _indizierter_quellbaum {spiegel repo branch} {
    # Materialisiere nur erfasste Quelltypen aus genau einem Branch-Commit.
    set revision [_git rev-parse --verify refs/heads/$branch^{commit} -C $spiegel]
    if {[dict get $revision returncode] != 0} {
        error "Branch-Commit nicht verfuegbar"
    }
    
    set sha [string trim [dict get $revision stdout]]
    if {![regexp {^[0-9a-f]{40}$} $sha]} {
        error "ungueltiger Branch-Commit"
    }
    
    if {[catch {exec git -C $spiegel ls-tree -r -z --full-tree $sha} listing]} {
        error "Konnte Branch-Inhalt nicht auflisten"
    }
    
    set paths [list]
    foreach record [split $listing \0] {
        if {$record eq ""} continue
        set parts [split $record \t]
        set metadata [lindex $parts 0]
        set path [lindex $parts 1]
        
        set meta_parts [split $metadata " "]
        if {[lindex $meta_parts 1] ne "blob"} {
            continue
        }
        
        set ext [string tolower [file extension $path]]
        if {[info exists ::QUELLSPRACHEN($ext)]} {
            lappend paths $path
        }
    }
    
    set parent [file join $::QUELLEN_DIR "indizierte-baeume" $repo]
    file mkdir $parent
    set baum [file join $parent "quelle_[pid]_[clock clicks]"]
    file mkdir $baum
    
    if {[llength $paths] > 0} {
        set index_dir [file join $::QUELLEN_DIR "quellindex_[pid]"]
        file mkdir $index_dir
        
        set env(GIT_INDEX_FILE) [file join $index_dir index]
        
        if {[catch {exec git -C $spiegel read-tree $sha}]} {
            file delete -force $baum
            error "Konnte Index nicht erstellen"
        }
        
        set input_data [join $paths \0]\0
        if {[catch {exec git -C $spiegel --work-tree $baum checkout-index --stdin -z --prefix=$baum/ << $input_data}]} {
            file delete -force $baum
            error "Konnte Dateien nicht auschecken"
        }
        
        file delete -force $index_dir
    }
    
    return $baum
}

proc quellen_holen {} {
    #
    # Holt oder aktualisiert die Quell-Repositories und legt fuer jeden Branch
    # einen Arbeitsbaum an.
    #
    # Alle drei Repositories sind oeffentlich, es wird daher kein Token benoetigt.
    #
    # Returns:
    #     Liste aus (Repo, Branch, Pfad zum Arbeitsbaum).
    #
    file mkdir $::QUELLEN_DIR
    set baeume [list]
    
    foreach {repo branches} [array get ::QUELLEN] {
        set spiegel [file join $::QUELLEN_DIR "${repo}.git"]
        set url "https://github.com/${::GITHUB_BENUTZER}/${repo}.git"
        
        if {![file exists $spiegel]} {
            log_info "$repo wird geholt"
            set ergebnis [_git clone --mirror --filter=blob:none $url $spiegel]
            if {[dict get $ergebnis returncode] != 0} {
                error "$repo: Quellspiegel konnte nicht geholt werden"
            }
        } else {
            set ergebnis [_git remote update --prune -C $spiegel]
            if {[dict get $ergebnis returncode] != 0} {
                error "$repo: Quellspiegel konnte nicht aktualisiert werden"
            }
        }
        
        set gewuenscht $branches
        if {$gewuenscht eq "alle"} {
            set aus [_git for-each-ref --format=%(refname:short) refs/heads -C $spiegel]
            set branches_list [list]
            foreach z [split [dict get $aus stdout] \n] {
                set trimmed [string trim $z]
                if {$trimmed ne ""} {
                    lappend branches_list $trimmed
                }
            }
        } else {
            set branches_list $gewuenscht
        }
        
        foreach branch $branches_list {
            if {[catch {set baum [_indizierter_quellbaum $spiegel $repo $branch]} fehler]} {
                error "$repo@$branch: indizierter Checkout fehlgeschlagen: $fehler"
            }
            lappend baeume [list $repo $branch $baum]
        }
    }
    
    # Lokale Gateway-Skripte gehören zum ursprünglichen Arbeitsumfang und
    # müssen auch dann erfasst werden, wenn der Git-Sync noch aussteht.
    if {[info exists ::env(ABSTRACTIONS_EXECUTION)] && $::env(ABSTRACTIONS_EXECUTION) eq "gateway"} {
        if {[file isdirectory $::WORKSPACE]} {
            lappend baeume [list workspace local $::WORKSPACE]
        }
        # CSS-Quellen ausserhalb des Workspace: gesamtes OpenClaw-Verzeichnis.
        if {[file isdirectory [file dirname $::WORKSPACE]]} {
            lappend baeume [list openclaw-css local [file dirname $::WORKSPACE]]
        }
    }
    
    log_info "Quellen bereit: [llength $baeume] Arbeitsbaeume"
    return $baeume
}

# ---------------------------------------------------------------------------
# Inventar
# ---------------------------------------------------------------------------

proc _prioritaet {pfad sprache} {
    #
    # Ordnet einer Quelldatei ihre Dringlichkeit zu.
    #
    # high   Betriebsscripte — alles unterhalb eines scripts-Verzeichnisses.
    # medium uebriger ausfuehrbarer Code.
    # low    Markup und Stilvorlagen, die nur der Vollstaendigkeit halber
    #        mituebersetzt werden.
    #
    if {$sprache in [list html css]} {
        return "low"
    }
    if {[string match "scripts/*" $pfad] || [string match "*/scripts/*" $pfad]} {
        return "high"
    }
    return "medium"
}

proc enthaelt_zugangsdaten {roh} {
    set muster {(?:sk-or-v1-[A-Za-z0-9_-]{20,}|sk-(?:proj-)?[A-Za-z0-9_-]{20,}|gh[opusr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|ntn_[A-Za-z0-9_]{20,}|tvly-[A-Za-z0-9_-]{20,}|nvapi-[A-Za-z0-9_-]{20,}|tskey-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9_-]{20,}|AKIA[A-Z0-9]{16}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----)}
    if {[regexp $muster $roh]} {
        return true
    }
    
    foreach {name wert} [array get ::env] {
        if {[string first TOKEN [string toupper $name]] != -1 || 
            [string first SECRET [string toupper $name]] != -1 ||
            [string first PASSWORD [string toupper $name]] != -1 ||
            [string first API_KEY [string toupper $name]] != -1} {
            if {[string length $wert] >= 12 && [string first $wert $roh] != -1} {
                return true
            }
        }
    }
    return false
}

proc css_html_dateien {baum} {
    # Durchsucht lokale HTML-Quellen ohne ausgeschlossene Unterbaeume.
    set ausgeschlossen [list ".git" "node_modules" "__pycache__" "dist" "build" "vendor" ".venv" "site-packages" "python-hardener-workspace" ".artifacts" "coverage" ".next" "target" "work" "backups" "logs" "log" "db" "state" "tmp" "temp" "cache" ".cache" "artifacts" "secrets" "credentials" ".credentials" "private" ".private"]
    set results [list]
    
    proc walk_directory {dir exclude_list} {
        upvar results results
        set dirs [list]
        set files [list]
        
        if {[catch {glob -nocomplain -dir $dir *} entries]} {
            return
        }
        
        foreach entry $entries {
            set basename [file tail $entry]
            if {$basename in $exclude_list} {
                continue
            }
            
            if {[file isdirectory $entry]} {
                lappend dirs $entry
            } elseif {[file isfile $entry]} {
                lappend files $entry
            }
        }
        
        foreach f $files {
            set ext [string tolower [file extension $f]]
            if {$ext in [list .html .htm]} {
                lappend results $f
            }
        }
        
        foreach d $dirs {
            walk_directory $d $exclude_list
        }
    }
    
    walk_directory $baum $ausgeschlossen
    return $results
}

proc inventar_bauen {baeume} {
    #
    # Erfasst alle Quelldateien und fasst inhaltsgleiche Fundstellen zusammen.
    #
    # Deduplizierung geschieht ueber den SHA-256 des Inhalts. Eine Datei, die in
    # mehreren Branches identisch vorliegt, wird genau einmal uebersetzt; alle
    # Fundstellen bleiben als Herkunft vermerkt.
    #
    # Returns:
    #     Nach Dringlichkeit und Name sortierte Liste von Eintraegen.
    #
    array set dateien {}
    
    foreach {repo branch baum} $baeume {
        set pfade [list]
        if {$repo eq "openclaw-css"} {
            set pfade [css_html_dateien $baum]
        } else {
            # Find all files recursively
            if {[catch {glob -nocomplain -dir $baum -types f *} all_files]} {
                set all_files [list]
            }
            set pfade $all_files
        }
        
        foreach pfad $pfade {
            if {![file isfile $pfad]} {
                continue
            }
            
            set rel [string map {\\ /} [fileutil::stripPath $baum $pfad]]
            
            if {$repo eq "openclaw-css"} {
                # Dieser zusaetzliche Bestand dient ausschliesslich CSS.
                set ext [string tolower [file extension $pfad]]
                if {$ext ni [list .html .htm]} {
                    continue
                }
                
                set teile [file split [fileutil::stripPath $baum $pfad]]
                set skip false
                foreach t $teile {
                    set t_lower [string tolower $t]
                    if {$t_lower in [list "work" "backups" "logs" "log" "db" "state" "tmp" "temp" "cache" ".cache" "artifacts" "secrets" "credentials" ".credentials" "private" ".private"]} {
                        set skip true
                        break
                    }
                }
                if {$skip} continue
                
                set skip_path false
                for {set i 0} {$i < [llength $teile]-1} {incr i} {
                    set pair [list [lindex $teile $i] [lindex $teile [expr {$i+1}]]]
                    if {$pair in [list [list "git" "Abstraktionen"] [list "git" "OpenClaw-gateway1-abstractions"] [list "git" "quellen"]]} {
                        set skip_path true
                        break
                    }
                }
                if {$skip_path} continue
                
                if {[catch {file normalize $pfad} normalized_path] || 
                    [catch {file normalize $baum} normalized_baum] ||
                    [string first $normalized_baum $normalized_path] != 0} {
                    continue
                }
            }
            
            if {$repo eq "workspace"} {
                # Ausgaben nicht als neue Quellen erneut übersetzen; die
                # Repository-Arbeitsbäume werden separat erfasst.
                set teile [file split [fileutil::stripPath $baum $pfad]]
                set skip_workspace false
                if {[llength $teile] >= 2} {
                    set pair [list [lindex $teile 0] [lindex $teile 1]]
                    if {$pair in [list [list "git" "Abstraktionen"] [list "git" "OpenClaw-gateway1-abstractions"] [list "git" "quellen"]]} {
                        set skip_workspace true
                    }
                }
                if {$skip_workspace} continue
                
                set skip_dir false
                foreach t $teile {
                    set t_lower [string tolower $t]
                    if {$t_lower in [list "work" "backups" "logs" "log" "db" "state" "tmp" "temp" "cache" ".cache" "artifacts" ".openclaw" "secrets" "credentials" ".credentials" "private" ".private"]} {
                        set skip_dir true
                        break
                    }
                }
                if {$skip_dir} continue
                
                if {[catch {file normalize $pfad} normalized_path] || 
                    [catch {file normalize $baum} normalized_baum] ||
                    [string first $normalized_baum $normalized_path] != 0} {
                    continue
                }
            }
            
            set skip_exclude false
            foreach muster $::AUSSCHLUSS {
                if {[string first $muster "/$rel"] != -1} {
                    set skip_exclude true
                    break
                }
            }
            if {$skip_exclude} continue
            
            set ext [string tolower [file extension $pfad]]
            if {![info exists ::QUELLSPRACHEN($ext)]} {
                continue
            }
            
            if {[catch {read_binary_file $pfad} roh]} {
                continue
            }
            
            if {[string trim $roh] eq "" || [enthaelt_zugangsdaten $roh]} {
                continue
            }
            
            set schluessel [string range [sha256::sha256 $roh] 0 15]
            if {![info exists dateien($schluessel)]} {
                set css_only [expr {$repo eq "openclaw-css"}]
                set dateien($schluessel) [dict create \
                    hash $schluessel \
                    name [file tail $pfad] \
                    stamm [file rootname [file tail $pfad]] \
                    sprache $::QUELLSPRACHEN($ext) \
                    bytes [string length $roh] \
                    pfad $pfad \
                    herkunft [list] \
                    prioritaet [_prioritaet $rel $::QUELLSPRACHEN($ext)] \
                    css_only $css_only]
            } elseif {$repo ne "openclaw-css"} {
                dict set dateien($schluessel) css_only false
            }
            
            dict lappend dateien($schluessel) herkunft "$repo@$branch:$rel"
        }
    }
    
    set liste [list]
    foreach key [array names dateien] {
        lappend liste $dateien($key)
    }
    
    set rang [dict create high 0 medium 1 low 2]
    proc compare_entries {a b} {
        upvar rang rang
        set prio_a [dict get $a prioritaet]
        set prio_b [dict get $b prioritaet]
        set rank_a [dict get $rang $prio_a]
        set rank_b [dict get $rang $prio_b]
        
        if {$rank_a != $rank_b} {
            return [expr {$rank_a - $rank_b}]
        }
        
        set name_a [dict get $a name]
        set name_b [dict get $b name]
        return [string compare $name_a $name_b]
    }
    
    set sorted_list [lsort -command compare_entries $liste]
    log_info "Inventar: [llength $sorted_list] eindeutige Quelldateien aus [expr {[llength $liste] > 0 ? [tcl::mathop::+ {*}[lmap e $liste {llength [dict get $e herkunft]}]} : 0}] Fundstellen"
    return $sorted_list
}

# ---------------------------------------------------------------------------
# Uebersetzung
# ---------------------------------------------------------------------------

set ANWEISUNG {Du portierst Quellcode zwischen Programmiersprachen.

Regeln:
1. Gib ausschliesslich den vollstaendigen Code der Zielsprache aus. Keine
   Erklaerung davor oder danach, keine Code-Zaeune.
2. Uebersetze die gesamte Funktionalitaet. Kein TODO, kein "hier waere",
   kein leerer Rumpf, kein Platzhalter.
3. Erhalte Verhalten, Ein- und Ausgaben, Aufrufparameter und Rueckgabewerte.
4. Verwende die Mittel der Zielsprache statt einer woertlichen Abschrift.
   Wo eine Bibliothek fehlt, loese es mit Bordmitteln der Zielsprache.
5. Kommentare uebernimmst du sinngemaess in der Sprache des Originals.
6. Beginne mit der passenden Shebang-Zeile.}

set MARKUP_HINWEIS {Das Original ist {sprache}. Erzeuge ein Programm in der
Zielsprache, das dieses Dokument erzeugt und ueber einen Parameter in eine
Datei schreibt — kein blosses Einbetten als Zeichenkette, sondern eine
nachvollziehbare Erzeugung der Struktur.}

set CSS_HINWEIS "Erzeuge ausschliesslich CSS aus den vorhandenen Stilinformationen des HTML-Dokuments. Erfinde keine Anwendungslogik."

set VERDACHT [list "TODO: Implementiere" "TODO: implement" "not implemented" \
                   "hier waere" "Platzhalter" "your code here" "pass  # TODO"]

proc zielsprachen_fuer {quellsprache {quelle ""}} {
    # CSS ist nur fuer HTML-Quellen vorgesehen, nicht fuer Skriptlogik.
    set css [expr {$quellsprache eq "html"}]
    if {$css && $quelle ne ""} {
        # Simple HTML style detection
        set css_found [expr {[string first "<style" [string tolower $quelle]] != -1 || [regexp {style\s*=\s*["'][^"']*[^"']*["']} $quelle]}]
        set css $css_found
    }
    
    set result [list]
    foreach z [array names ::ZIELSPRACHEN] {
        if {$z ne $quellsprache && ($z ne "css" || $css)} {
            lappend result $z
        }
    }
    return $result
}

proc system_anweisung {zielsprache} {
    variable ANWEISUNG
    if {$zielsprache in [list java c cpp php fsharp css]} {
        return [string map {"6. Beginne mit der passenden Shebang-Zeile." "6. Gib Quelltext im gueltigen Format der Zielsprache aus; verwende keine Shebang-Zeile."} $ANWEISUNG]
    }
    return $ANWEISUNG
}

proc markup_hinweis {quellsprache zielsprache} {
    variable MARKUP_HINWEIS
    variable CSS_HINWEIS
    
    if {$zielsprache eq "css"} {
        return $CSS_HINWEIS
    }
    
    if {$quellsprache in [list html css]} {
        return [string map [list {sprache} [string toupper $quellsprache]] $MARKUP_HINWEIS]
    }
    
    return ""
}

proc _zaeune_entfernen {text} {
    # Loest Code aus Markdown-Zaeunen, falls das Modell welche gesetzt hat.
    set zeilen [split [string trim $text] \n]
    if {[llength $zeilen] > 0 && [string match "```*" [string trim [lindex $zeilen 0]]]} {
        set zeilen [lrange $zeilen 1 end]
        set new_lines [list]
        set in_fence true
        foreach line $zeilen {
            if {$in_fence && [string match "```*" [string trim $line]]} {
                set in_fence false
                continue
            }
            if {$in_fence} {
                lappend new_lines $line
            }
        }
        set zeilen $new_lines
    }
    return [string trim [join $zeilen \n]]\n
}

proc _modell_code_bereinigen {text zielsprache} {
    set code [_zaeune_entfernen $text]
    # Go source files cannot contain the shebang requested in the shared prompt.
    if {$zielsprache in [list go java c cpp fsharp css] && [string match "#!*" $code]} {
        set code [lindex [split $code \n] 1]
    }
    return $code
}

proc modell_fragen {quelle quellsprache zielsprache name schluessel} {
    #
    # Laesst eine Quelldatei in die Zielsprache uebersetzen.
    #
    # Bei Fehlschlag wird mit wachsender Wartezeit wiederholt und danach auf
    # das naechste Modell der Liste ausgewichen.
    #
    # Returns:
    #     Der uebersetzte Code, oder None wenn kein Modell geantwortet hat.
    #
    set ziel [dict get $::ZIELSPRACHEN($zielsprache) bezeichnung]
    set auftrag "Portiere die folgende Datei $name von $quellsprache nach $ziel.\n"
    set hinweis [markup_hinweis $quellsprache $zielsprache]
    if {$hinweis ne ""} {
        append auftrag $hinweis\n
    }
    append auftrag "\n----- Beginn $name -----\n$quelle\n----- Ende $name -----"
    
    set modelle [expr {[info exists ::env(ABSTRACTIONS_MODELL)] ? [list $::env(ABSTRACTIONS_MODELL)] : $::MODELLE}]
    
    foreach modell $modelle {
        for {set versuch 1} {$versuch <= $::VERSUCHE} {incr versuch} {
            set body [::json::dict2json [dict create \
                model $modell \
                messages [list \
                    [dict create role system content [system_anweisung $zielsprache]] \
                    [dict create role user content $auftrag] \
                ] \
                temperature 0.1 \
                max_tokens 8000]]
            
            set opts [list -headers [list \
                Authorization "Bearer $schluessel" \
                Content-Type "application/json" \
                HTTP-Referer "https://github.com/KikiKari/Projects" \
                X-Title "Abstractions Manager"]]
            
            if {[
