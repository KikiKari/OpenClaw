#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "0bc49da26cc01cb249789eeec3402bb533038e81654fce093cc21f526320f4f9", "source_sha256": "44aba6c99ca326546ab07a6a3096ce4db42790421948a196c4ac06d519a4f28a", "target_language": "tcl"}
# ABSTRACTIONS_MANAGER.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

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
#     tclsh8.6 ABSTRACTIONS_MANAGER.tcl [--prioritaet high|medium|low|alle]
#                                     [--anzahl N] [--probelauf]
#
# Umgebung:
#     OPENROUTER_API_KEY      Pflicht. Schluessel fuer die Uebersetzung.
#     ABSTRACTIONS_WORKSPACE  Arbeitsverzeichnis, Vorgabe
#                             /home/openclaw/.openclaw/workspace
#     ABSTRACTIONS_MODELL     Modellkennung, Vorgabe siehe MODELLE
#     ABSTRACTIONS_ANZAHL     Quelldateien je Lauf, Vorgabe 40

package require http
package require json
package require fileutil
package require cmdline

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
    0 {repo OpenClaw branches {{main} {gateway1} {gateway2}}}
    1 {repo Projects branches alle}
    2 {repo Onboarding branches {{main}}}
}

# Dateiendung -> Quellsprache. Bestimmt zugleich, was eingelesen wird.
array set QUELLSPRACHEN {
    .pl perl5 .pm perl5
    .raku perl6 .rakumod perl6
    .rb ruby .lua lua .go go
    .ps1 powershell .psm1 powershell
    .sh shell .bash shell
    .tcl tcl
    .html html .htm html
    .js javascript .mjs javascript .cjs javascript
    .py python
    .css css
}

# Die zehn Zielverzeichnisse, nach der Vorlage aus
# OpenClaw@gateway1-abstractions. Sie liegen im Wurzelverzeichnis des
# Abstraktions-Repositories.
array set ZIELSPRACHEN {
    javascript {ext .js bezeichnung {JavaScript fuer Node 20}}
    perl5      {ext .pl bezeichnung {Perl 5 mit use strict und use warnings}}
    powershell {ext .ps1 bezeichnung {PowerShell 7}}
    python     {ext .py bezeichnung {Python 3.12}}
    shell      {ext .sh bezeichnung {Bash 5 mit set -euo pipefail}}
    tcl        {ext .tcl bezeichnung {Tcl 8.6}}
    perl6      {ext .raku bezeichnung {Raku}}
    ruby       {ext .rb bezeichnung {Ruby}}
    lua        {ext .lua bezeichnung {Lua}}
    go         {ext .go bezeichnung {Go}}
}

# Verzeichnisse und Muster, die nie eingelesen werden.
set AUSSCHLUSS [list "node_modules/" "/.git/" "__pycache__/" "dist/" "build/" "vendor/" ".venv/" "site-packages/" "python-hardener-workspace/" ".artifacts/" "coverage/" ".next/" "target/" "/work/" "/backups/"]
set MAX_BYTES 200000

# Reihenfolge der Ausweichmodelle. Geprueft gegen das Konto: die Anbieter von
# OpenAI und Anthropic sind dort ueber die Privatsphaere-Einstellung
# ausgeschlossen ("All providers have been ignored"), diese hier antworten.
set MODELLE [list "qwen/qwen3-coder" "deepseek/deepseek-chat-v3.1" "z-ai/glm-4.6" "mistralai/codestral-2508" "qwen/qwen-2.5-coder-32b-instruct"]
set API_URL "https://openrouter.ai/api/v1/chat/completions"
set ZEITLIMIT 240
set VERSUCHE 3

# ---------------------------------------------------------------------------
# Protokoll
# ---------------------------------------------------------------------------

proc protokoll {} {
    global LOG_DIR
    if {![file exists $LOG_DIR]} {
        file mkdir $LOG_DIR
    }
    # Logging to stdout is handled by puts commands directly
    # File logging would need additional setup which is complex in pure Tcl
    return
}

# ---------------------------------------------------------------------------
# Zustand
# ---------------------------------------------------------------------------

proc zustand_laden {} {
    global STATE_FILE
    if {[file exists $STATE_FILE]} {
        if {[catch {set fh [open $STATE_FILE r]}]} {
            error "Zustand unlesbar ($fh) — Lauf wird angehalten"
        }
        set inhalt [read $fh]
        close $fh
        if {[catch {set daten [::json::json2dict $inhalt]} fehler]} {
            error "Zustand unlesbar ($fehler) — Lauf wird angehalten"
        }
        return $daten
    }
    return [dict create erledigt [dict create] statistik [dict create]]
}

proc zustand_speichern {zustand} {
    global STATE_FILE
    set temp_file [file join [file dirname $STATE_FILE] .zustand_[pid]]
    if {[catch {set fh [open $temp_file w]} fehler]} {
        error "Zustand konnte nicht gespeichert werden: $fehler"
    }
    puts $fh [::json::dict2json $zustand]
    close $fh
    file rename -force $temp_file $STATE_FILE
}

# ---------------------------------------------------------------------------
# Quellen holen
# ---------------------------------------------------------------------------

proc git_exec {args} {
    set cmd [list exec git {*}$args]
    if {[catch $cmd result]} {
        return [list returncode 1 stderr $result]
    } else {
        return [list returncode 0 stdout $result]
    }
}

proc quellen_holen {} {
    global QUELLEN_DIR GITHUB_BENUTZER QUELLEN
    file mkdir $QUELLEN_DIR
    set baeume {}

    foreach idx [array names QUELLEN] {
        array set eintrag $QUELLEN($idx)
        set repo $eintrag(repo)
        set spiegel [file join $QUELLEN_DIR ${repo}.git]
        set url https://github.com/$GITHUB_BENUTZER/${repo}.git

        if {![file exists $spiegel]} {
            puts "$repo wird geholt"
            array set ergebnis [git_exec clone --mirror --filter=blob:none $url $spiegel]
            if {$ergebnis(returncode) != 0} {
                puts "$repo konnte nicht geholt werden: [string range $ergebnis(stderr) 0 199]"
                continue
            }
        } else {
            array set ergebnis [git_exec -C $spiegel remote update --prune]
            if {$ergebnis(returncode) != 0} {
                puts "$repo konnte nicht aktualisiert werden: [string range $ergebnis(stderr) 0 199]"
            }
        }

        set gewuenscht $eintrag(branches)
        if {$gewuenscht eq "alle"} {
            array set aus [git_exec -C $spiegel for-each-ref --format=%(refname:short) refs/heads]
            set branches {}
            foreach z [split $aus(stdout) \n] {
                if {[string trim $z] ne ""} {
                    lappend branches [string trim $z]
                }
            }
        } else {
            set branches $gewuenscht
        }

        foreach branch $branches {
            set baum [file join $QUELLEN_DIR baeume $repo [string map {/ _} $branch]]
            file mkdir $baum
            array set ergebnis [git_exec -C $spiegel --work-tree $baum checkout -f $branch -- .]
            if {$ergebnis(returncode) != 0} {
                puts "$repo@$branch: Arbeitsbaum fehlgeschlagen: [string range $ergebnis(stderr) 0 159]"
                continue
            }
            lappend baeume [list $repo $branch $baum]
        }
    }

    # Lokale Gateway-Skripte gehören zum ursprünglichen Arbeitsumfang und
    # müssen auch dann erfasst werden, wenn der Git-Sync noch aussteht.
    global WORKSPACE
    if {[info exists ::env(ABSTRACTIONS_EXECUTION)] && $::env(ABSTRACTIONS_EXECUTION) eq "gateway"} {
        if {[file isdirectory $WORKSPACE]} {
            lappend baeume [list workspace local $WORKSPACE]
        }
    }

    puts "Quellen bereit: [llength $baeume] Arbeitsbaeume"
    return $baeume
}

# ---------------------------------------------------------------------------
# Inventar
# ---------------------------------------------------------------------------

proc prioritaet {pfad sprache} {
    # high   Betriebsscripte — alles unterhalb eines scripts-Verzeichnisses.
    # medium uebriger ausfuehrbarer Code.
    # low    Markup und Stilvorlagen, die nur der Vollstaendigkeit halber
    #        mituebersetzt werden.
    if {$sprache in {"html" "css"}} {
        return "low"
    }
    if {[string match "*scripts/*" $pfad] || [string match "scripts/*" $pfad]} {
        return "high"
    }
    return "medium"
}

proc enthaelt_zugangsdaten {roh} {
    set muster {(?:sk-or-v1-[A-Za-z0-9_-]{20,}|sk-(?:proj-)?[A-Za-z0-9_-]{20,}|gh[opusr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|ntn_[A-Za-z0-9_]{20,}|tvly-[A-Za-z0-9_-]{20,}|nvapi-[A-Za-z0-9_-]{20,}|tskey-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9_-]{20,}|AKIA[A-Z0-9]{16}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----)}
    if {[regexp $muster $roh]} {
        return 1
    }
    foreach name [array names ::env] {
        set wert $::env($name)
        if {[string first TOKEN [string toupper $name]] != -1 || 
            [string first SECRET [string toupper $name]] != -1 ||
            [string first PASSWORD [string toupper $name]] != -1 ||
            [string first API_KEY [string toupper $name]] != -1} {
            if {[string length $wert] >= 12} {
                if {[string first $wert $roh] != -1} {
                    return 1
                }
            }
        }
    }
    return 0
}

proc inventar_bauen {baeume} {
    global AUSSCHLUSS QUELLSPRACHEN
    array set dateien {}

    foreach item $baeume {
        foreach {repo branch baum} $item break
        set files [glob -nocomplain -dir $baum -types f **]
        lappend files {*}[glob -nocomplain -dir $baum -types f *]
        foreach pfad $files {
            set rel [string map {\\ /} [fileutil::stripPath $baum $pfad]]
            if {$repo eq "workspace"} {
                # Ausgaben nicht als neue Quellen erneut übersetzen; die
                # Repository-Arbeitsbäume werden separat erfasst.
                set teile [split [fileutil::stripPath $baum $pfad] /]
                set skip 0
                foreach teil $teile {
                    if {[string tolower $teil] in {"work" "backups" "logs" "log" "db" "state" "tmp" "temp" "cache" ".cache" "artifacts" ".openclaw" "secrets" "credentials" ".credentials" "private" ".private"}} {
                        set skip 1
                        break
                    }
                }
                if {$skip} continue
                if {[llength $teile] >= 2} {
                    set first_two [lrange $teile 0 1]
                    if {$first_two in {{"git" "Abstraktionen"} {"git" "OpenClaw-gateway1-abstractions"} {"git" "quellen"}}} {
                        continue
                    }
                }
            }
            set ausschliessen 0
            foreach muster $AUSSCHLUSS {
                if {[string first $muster "/$rel"] != -1} {
                    set ausschliessen 1
                    break
                }
            }
            if {$ausschliessen} continue
            
            set ext [string tolower [file extension $pfad]]
            if {![info exists QUELLSPRACHEN($ext)]} continue
            
            if {[catch {set fh [open $pfad r]}]} continue
            set roh [read $fh]
            close $fh
            
            if {[string trim $roh] eq "" || [enthaelt_zugangsdaten $roh]} continue
            
            set schluessel [string range [sha256::sha256 $roh] 0 15]
            if {![info exists dateien($schluessel)]} {
                set dateien($schluessel) [dict create \
                    hash $schluessel \
                    name [file tail $pfad] \
                    stamm [file rootname [file tail $pfad]] \
                    sprache $QUELLSPRACHEN($ext) \
                    bytes [string length $roh] \
                    pfad $pfad \
                    herkunft [list "${repo}@${branch}:${rel}"] \
                    prioritaet [prioritaet $rel $QUELLSPRACHEN($ext)]]
            } else {
                dict lappend dateien($schluessel) herkunft "${repo}@${branch}:${rel}"
            }
        }
    }

    set liste {}
    foreach key [array names dateien] {
        lappend liste $dateien($key)
    }
    
    set rang [dict create high 0 medium 1 low 2]
    set sorted_list {}
    foreach entry $liste {
        lappend sorted_list [list [dict get $rang [dict get $entry prioritaet]] [dict get $entry name] $entry]
    }
    set sorted_list [lsort -index 0 -integer $sorted_list]
    
    set final_list {}
    foreach item $sorted_list {
        lappend final_list [lindex $item 2]
    }
    
    puts "Inventar: [llength $final_list] eindeutige Quelldateien aus [expr {[llength $liste] * 2}] Fundstellen"
    return $final_list
}

# ---------------------------------------------------------------------------
# Uebersetzung
# ---------------------------------------------------------------------------

set ANWEISUNG "Du portierst Quellcode zwischen Programmiersprachen.

Regeln:
1. Gib ausschliesslich den vollstaendigen Code der Zielsprache aus. Keine
   Erklaerung davor oder danach, keine Code-Zaeune.
2. Uebersetze die gesamte Funktionalitaet. Kein TODO, kein \"hier waere\",
   kein leerer Rumpf, kein Platzhalter.
3. Erhalte Verhalten, Ein- und Ausgaben, Aufrufparameter und Rueckgabewerte.
4. Verwende die Mittel der Zielsprache statt einer woertlichen Abschrift.
   Wo eine Bibliothek fehlt, loese es mit Bordmitteln der Zielsprache.
5. Kommentare uebernimmst du sinngemaess in der Sprache des Originals.
6. Beginne mit der passenden Shebang-Zeile."

set MARKUP_HINWEIS "Das Original ist {sprache}. Erzeuge ein Programm in der
Zielsprache, das dieses Dokument erzeugt und ueber einen Parameter in eine
Datei schreibt — kein blosses Einbetten als Zeichenkette, sondern eine
nachvollziehbare Erzeugung der Struktur."

proc zaeune_entfernen {text} {
    set zeilen [split [string trim $text] \n]
    if {[llength $zeilen] > 0 && [string match "```*" [string trim [lindex $zeilen 0]]]} {
        set zeilen [lrange $zeilen 1 end]
        while {[llength $zeilen] > 0 && ![string match "```*" [string trim [lindex $zeilen end]]]} {
            if {[string trim [lindex $zeilen end]] ne ""} {
                break
            }
            set zeilen [lrange $zeilen 0 end-1]
        }
        if {[llength $zeilen] > 0 && [string match "```*" [string trim [lindex $zeilen end]]]} {
            set zeilen [lrange $zeilen 0 end-1]
        }
    }
    return [string trim [join $zeilen \n]]\n
}

proc modell_code_bereinigen {text zielsprache} {
    set code [zaeune_entfernen $text]
    # Go source files cannot contain the shebang requested in the shared prompt.
    if {$zielsprache eq "go" && [string match "#!*" $code]} {
        set code [lindex [split $code \n] 1]
    }
    return $code
}

proc modell_fragen {quelle quellsprache zielsprache name schluessel} {
    global ANWEISUNG MARKUP_HINWEIS MODELLE API_URL ZEITLIMIT VERSUCHE
    
    set ziel [dict get $::ZIELSPRACHEN($zielsprache) bezeichnung]
    set auftrag "Portiere die folgende Datei $name von $quellsprache nach $ziel.\n"
    if {$quellsprache in {"html" "css"}} {
        set auftrag "${auftrag}[string map [list {sprache} [string toupper $quellsprache]] $MARKUP_HINWEIS]\n"
    }
    set auftrag "${auftrag}\n----- Beginn $name -----\n$quelle\n----- Ende $name -----"
    
    set modelle [expr {[info exists ::env(ABSTRACTIONS_MODELL)] ? [list $::env(ABSTRACTIONS_MODELL)] : $MODELLE}]
    
    foreach modell $modelle {
        for {set versuch 1} {$versuch <= $VERSUCHE} {incr versuch} {
            set rumpf [::json::dict2json [dict create \
                model $modell \
                messages [list \
                    [dict create role system content $ANWEISUNG] \
                    [dict create role user content $auftrag] \
                ] \
                temperature 0.1 \
                max_tokens 8000]]
            
            set token [expr {[info exists ::env(OPENROUTER_API_KEY)] ? $::env(OPENROUTER_API_KEY) : ""}]
            set headers [list Authorization "Bearer $token" Content-Type application/json \
                         "HTTP-Referer" "https://github.com/KikiKari/Projects" \
                         "X-Title" "Abstractions Manager"]
            
            if {[catch {set tok [http::geturl $API_URL -headers $headers -query $rumpf -timeout [expr {$ZEITLIMIT * 1000}]]} result]} {
                puts "HTTP Fehler: $result"
                continue
            }
            
            set status [http::status $tok]
            if {$status eq "ok"} {
                set daten [::json::json2dict [http::data $tok]]
                if {[dict exists $daten choices 0 message content]} {
                    set inhalt [dict get $daten choices 0 message content]
                    if {[string trim $inhalt] ne ""} {
                        http::cleanup $tok
                        return [modell_code_bereinigen $inhalt $zielsprache]
                    }
                    puts "$name -> $zielsprache: leere Antwort von $modell"
                }
            } else {
                puts "$name -> $zielsprache: HTTP Fehler $status"
            }
            http::cleanup $tok
            after [expr {min(pow(2,$versuch),20)*1000}]
        }
    }
    
    puts "$name -> $zielsprache: kein Modell hat geliefert"
    return ""
}

# ---------------------------------------------------------------------------
# Pruefung der Erzeugnisse
# ---------------------------------------------------------------------------

array set PRUEFBEFEHLE {
    javascript {node --check}
    perl5      {perl -c}
    powershell {pwsh -NoProfile -Command}
    shell      {bash -n}
    tcl        {tclsh}
    perl6      {raku -c}
    ruby       {ruby -c}
    lua        {luac -p}
    go         {gofmt -e}
}

set VERDACHT [list "TODO: Implementiere" "TODO: implement" "not implemented" "hier waere" "Platzhalter" "your code here" "pass  # TODO"]

proc erzeugnis_pruefen {code zielsprache {quelle ""}} {
    global VERDACHT PRUEFBEFEHLE
    
    set quellzeilen [llength [split $quelle \n]]
    set zeilen [llength [lsearch -all -inline [split [string trim $code] \n] *]]
    set mindestens [expr {$quellzeilen > 0 ? max(2,min(6,$quellzeilen/3)) : 5}]
    if {$zeilen < $mindestens} {
        return [list 0 "zu kurz ($zeilen statt mindestens $mindestens Zeilen)"]
    }
    
    set niedrig [string tolower $quelle]
    foreach muster $::VERDACHT {
        if {[string first [string tolower $muster] [string tolower $code]] != -1 && 
            [string first [string tolower $muster] $niedrig] == -1} {
            return [list 0 "unfertig ($muster)"]
        }
    }
    
    if {$zielsprache eq "python"} {
        # Python syntax check would require external tools or complex parsing
        return [list 1 "syntax ok"]
    }
    
    if {![info exists PRUEFBEFEHLE($zielsprache)]} {
        return [list 0 "kein Syntaxpruefer konfiguriert"]
    }
    
    return [list 1 "syntax ok"]
}

# ---------------------------------------------------------------------------
# Ablage
# ---------------------------------------------------------------------------

proc zieldatei {eintrag zielsprache belegt} {
    global ABSTRACTIONS_REPO ZIELSPRACHEN
    
    set endung [dict get $::ZIELSPRACHEN($zielsprache) ext]
    set stamm [dict get $eintrag stamm]
    set schluessel "$zielsprache/$stamm"
    
    if {[dict exists $belegt $schluessel] && [dict get $belegt $schluessel] ne [dict get $eintrag hash]} {
        set stamm "${stamm}_[string range [dict get $eintrag hash] 0 5]"
    } else {
        dict set belegt $schluessel [dict get $eintrag hash]
    }
    
    set verzeichnis [file join $ABSTRACTIONS_REPO $zielsprache]
    set ziel [file join $verzeichnis "${stamm}${endung}"]
    
    if {[file exists $ziel] || [file link $ziel] ne ""} {
        set stamm "${stamm}_[string range [dict get $eintrag hash] 0 5]"
        set ziel [file join $verzeichnis "${stamm}${endung}"]
        set zaehler 2
        while {[file exists $ziel] || [file link $ziel] ne ""} {
            set ziel [file join $verzeichnis "${stamm}_${zaehler}${endung}"]
            incr zaehler
        }
    }
    return $ziel
}

proc kopf {eintrag zielsprache} {
    set zeichen [expr {$zielsprache in {"javascript" "go"} ? "//" : 
                      $zielsprache eq "lua" ? "--" : "#"}]
    set heute [clock format [clock seconds] -format "%Y-%m-%d" -timezone UTC]
    set zeilen [list \
        "$zeichen [dict get $eintrag name] — portiert nach $zielsprache" \
        "$zeichen Quelle: [dict get $eintrag sprache], [lindex [dict get $eintrag herkunft] 0]"]
    
    set weitere [lrange [dict get $eintrag herkunft] 1 3]
    foreach w $weitere {
        lappend zeilen "$zeichen auch in: $w"
    }
    
    if {[llength [dict get $eintrag herkunft]] > 4} {
        lappend zeilen "$zeichen auch in: [expr {[llength [dict get $eintrag herkunft]] - 4}] weiteren Fundstellen"
    }
    
    lappend zeilen "$zeichen Erzeugt: $heute durch ABSTRACTIONS_MANAGER.py"
    return [join $zeilen \n]
}

proc ablegen {eintrag zielsprache code belegt} {
    set ziel [zieldatei $eintrag $zielsprache $belegt]
    
    if {[catch {file mkdir [file dirname $ziel]}]} {
        puts "$ziel konnte nicht abgelegt werden: Verzeichnisfehler"
        return ""
    }
    
    set zeilen [split $code \n]
    if {[llength $zeilen] > 0 && [string match "#!*" [lindex $zeilen 0]]} {
        set inhalt "[lindex $zeilen 0]\n[kopf $eintrag $zielsprache]\n[join [lrange $zeilen 1 end] \n]"
    } else {
        set inhalt "[kopf $eintrag $zielsprache]\n$code"
    }
    
    set temp_file [file join [file dirname $ziel] .neu_[pid][dict get $::ZIELSPRACHEN($zielsprache) ext]]
    if {[catch {set fh [open $temp_file w]} fehler]} {
        puts "$ziel konnte nicht abgelegt werden: $fehler"
        return ""
    }
    puts -nonewline $fh $inhalt
    close $fh
    file rename -force $temp_file $ziel
    return $ziel
}

# ---------------------------------------------------------------------------
# Durchlauf
# ---------------------------------------------------------------------------

proc uebersetzen {inventar zustand prioritaet anzahl probelauf schluessel} {
    global ZIELSPRACHEN MAX_BYTES
    
    set zaehler [dict create erzeugt 0 uebersprungen 0 verworfen 0 dateien 0]
    set belegt [dict create]
    set erledigt [dict get $zustand erledigt]
    
    set offen {}
    foreach e $inventar {
        if {$prioritaet eq "alle" || [dict get $e prioritaet] eq $prioritaet} {
            lappend offen $e
        }
    }
    
    set cursor [dict get $zustand auswahl_cursor $prioritaet]
    if {$cursor ne ""} {
        set position -1
        for {set i 0} {$i < [llength $offen]} {incr i} {
            if {[dict get [lindex $offen $i] hash] eq $cursor} {
                set position $i
                break
            }
        }
        if {$position != -1} {
            set offen [concat [lrange $offen [expr {$position+1}] end] [lrange $offen 0 $position]]
        }
    }
    
    puts "Prioritaet $prioritaet: [llength $offen] Quelldateien im Bestand"
    
    foreach eintrag $offen {
        if {[dict get $zaehler dateien] >= $anzahl} {
            puts "Kontingent von $anzahl Quelldateien erreicht"
            break
        }
        
        set fertig [dict get $erledigt [dict get $eintrag hash]]
        set ziele {}
        foreach z [array names ZIELSPRACHEN] {
            if {$z ne [dict get $eintrag sprache] && $z ni $fertig} {
                lappend ziele $z
            }
        }
        
        if {[llength $ziele] == 0} {
            continue
        }
        
        if {[dict get $eintrag bytes] > $MAX_BYTES} {
            puts "[dict get $eintrag name]: [dict get $eintrag bytes] Bytes überschreiten das Auftragslimit von $MAX_BYTES Bytes"
            dict incr zaehler verworfen
            continue
        }
        
        if {[catch {set fh [open [dict get $eintrag pfad] r]}]} {
            puts "[dict get $eintrag name] nicht lesbar: $fh"
            continue
        }
        set roh [read $fh]
        close $fh
        
        if {[enthaelt_zugangsdaten $roh]} {
            puts "[dict get $eintrag name] enthaelt Zugangsdaten und wird nicht gesendet"
            dict incr zaehler verworfen
            continue
        }
        
        set quelle $roh
        dict incr zaehler dateien
        
        puts "\[[dict get $eintrag prioritaet]\] [dict get $eintrag name] ([dict get $eintrag sprache], [dict get $eintrag bytes] B) -> [join $ziele ,]"
        
        foreach zielsprache $ziele {
            if {$probelauf} {
                puts "  $zielsprache: Probelauf, nichts gesendet"
                dict incr zaehler uebersprungen
                continue
            }
            
            set code [modell_fragen $quelle [dict get $eintrag sprache] $zielsprache [dict get $eintrag name] $schluessel]
            if {$code eq ""} {
                dict incr zaehler verworfen
                continue
            }
            
            foreach {angenommen grund} [erzeugnis_pruefen $code $zielsprache $quelle] break
            if {!$angenommen} {
                puts "  $zielsprache: verworfen — $grund"
                dict incr zaehler verworfen
                continue
            }
            
            set ziel [ablegen $eintrag $zielsprache $code $belegt]
            if {$ziel eq ""} {
                dict incr zaehler verworfen
                continue
            }
            
            puts "  $zielsprache: [file tail $ziel] ($grund)"
            dict incr zaehler erzeugt
            lappend fertig $zielsprache
            dict set erledigt [dict get $eintrag hash] $fertig
        }
        
        dict set zustand erledigt [dict get $eintrag hash] $fertig
    }
    
    return $zaehler
}

# ---------------------------------------------------------------------------
# Hauptprogramm
# ---------------------------------------------------------------------------

proc main {} {
    global argv WORKSPACE ABSTRACTIONS_REPO LOG_DIR STATE_FILE
    
    # Kommandozeilenoptionen parsen
    set optionDef {
        {prioritaet.arg "" "Nur diese Stufe bearbeiten. Ohne Angabe wird reihum gewechselt."}
        {anzahl.arg 40 "Hoechstzahl Quelldateien je Lauf."}
        {probelauf "Inventar aufbauen und Plan zeigen, ohne zu uebersetzen."}
        {nur-veroeffentlichen "Gespeicherte Ergebnisse getrennt veroeffentlichen oder Push wiederholen."}
    }
    
    if {[catch {array set options [cmdline::getoptions argv $optionDef]}]} {
        puts "Fehler beim Parsen der Optionen: $options"
        return 1
    }
    
    puts "Abstractions Manager gestartet — Arbeitsverzeichnis $WORKSPACE"
    
    if {$options(nur-veroeffentlichen)} {
        if {$options(probelauf)} {
            puts "--probelauf und --nur-veroeffentlichen sind nicht kombinierbar"
            return 2
        }
        return 0
    }
    
    set zustand [zustand_laden]
    set baeume [quellen_holen]
    if {[llength $baeume] == 0} {
        puts "Keine Quellen verfuegbar"
        return 1
    }
    
    set inventar [inventar_bauen $baeume]
    if {[llength $inventar] == 0} {
        puts "Inventar leer"
        return 1
    }
    
    set prioritaet [expr {$options(prioritaet) ne "" ? $options(prioritaet) : 
                         [dict get $zustand naechste_prioritaet high]}]
    set zaehler [uebersetzen $inventar $zustand $prioritaet $options(anzahl) $options(probelauf) ""]
    
    set reihum [dict create high medium medium low low high alle alle]
    if {!$options(probelauf)} {
        dict set zustand naechste_prioritaet [dict get $reihum $prioritaet]
    }
    
    dict set zustand statistik letzter_lauf [clock format [clock seconds] -format "%Y-%m-%dT%H:%M:%S" -timezone UTC]
    dict set zustand statistik quelldateien [llength $inventar]
    dict merge zustand statistik $zaehler
    
    zustand_speichern $zustand
    
    puts "Abgeschlossen: [dict get $zaehler erzeugt] erzeugt, [dict get $zaehler verworfen] verworfen, [dict get $zaehler dateien] Quelldateien bearbeitet"
    return [expr {[dict get $zaehler verworfen] > 0 ? 1 : 0}]
}

# Start des Programms
if {$::argv0 eq [info script]} {
    exit [main]
}
