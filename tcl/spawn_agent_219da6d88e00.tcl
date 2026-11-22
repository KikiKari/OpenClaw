#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "6a24777758976b5619766b6fb2743f9860bfe21edb0bb263d1b257b1c3234b08", "source_sha256": "a26da3d1befb1a302d385e0a3c85117de3ec06543d5017cf1d706e7f0602be0f", "target_language": "tcl"}
# spawn_agent.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/sub-agents-utils/scripts/spawn_agent.py
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Sub-Agent spawner - Einfache CLI für sessions_spawn

package require json
package require cmdline

# Globale Variable für Modelle
set MODELS {}

# Lade Modelle aus Konfigurationsdatei
proc load_models {} {
    global MODELS
    set configPath $::env(OPENCLAW_CONFIG)
    if {$configPath eq ""} {
        set configPath "/home/openclaw/.openclaw/openclaw.json"
    }
    
    if {[catch {open $configPath r} fid]} {
        error "Modellkonfiguration kann nicht geladen werden: $configPath: $fid"
    }
    
    if {[catch {read $fid} content]} {
        close $fid
        error "Modellkonfiguration kann nicht geladen werden: $configPath: $content"
    }
    close $fid
    
    if {[catch {::json::json2dict $content} config]} {
        error "Modellkonfiguration kann nicht geladen werden: $configPath: Invalid JSON"
    }
    
    # Extrahiere Model-Konfiguration
    if {![dict exists $config agents defaults model]} {
        error "Modellkonfiguration kann nicht geladen werden: $configPath: Key not found"
    }
    
    set modelConfig [dict get $config agents defaults model]
    set candidates {}
    
    # Füge primary Modell hinzu
    if {[dict exists $modelConfig primary]} {
        lappend candidates [dict get $modelConfig primary]
    }
    
    # Füge fallbacks hinzu
    if {[dict exists $modelConfig fallbacks]} {
        set fallbacks [dict get $modelConfig fallbacks]
        foreach fallback $fallbacks {
            lappend candidates $fallback
        }
    }
    
    # Filtere Modelle
    set filteredModels {}
    foreach model $candidates {
        if {$model ne "" && ![string match "anthropic/*" $model]} {
            lappend filteredModels $model
        }
    }
    
    # Entferne Duplikate und speichere in globaler Variable
    set MODELS [lsort -unique $filteredModels]
    
    if {[llength $MODELS] == 0} {
        error "Keine allgemein verfügbaren Modelle in $configPath"
    }
    
    return $MODELS
}

# Initialisiere Modelle
load_models

# Hilfsklasse für Sub-Agent Spawning
namespace eval SubAgentSpawner {
    # Erstellt Konfiguration für sessions_spawn
    proc get_spawn_config {args} {
        array set params $args
        set config [dict create task $params(task)]
        
        if {[info exists params(label)] && $params(label) ne ""} {
            dict set config label $params(label)
        }
        
        if {[info exists params(model)] && $params(model) in $::MODELS} {
            dict set config model $params(model)
        }
        
        if {[info exists params(thinking)] && $params(thinking) ne ""} {
            dict set config thinking $params(thinking)
        }
        
        if {[info exists params(timeout)] && $params(timeout) != 0} {
            dict set config runTimeoutSeconds $params(timeout)
        }
        
        if {[info exists params(thread)] && $params(thread)} {
            dict set config thread true
            if {![info exists params(mode)] || $params(mode) eq "run"} {
                dict set config mode session
            } else {
                dict set config mode $params(mode)
            }
        } elseif {[info exists params(mode)]} {
            dict set config mode $params(mode)
        }
        
        return $config
    }
    
    # Gibt das equivalente Tool-Kommando aus
    proc print_spawn_command {config} {
        puts "\n🛠️  Tool-Aufruf:"
        puts "=================================================="
        puts "sessions_spawn("
        
        dict for {key value} $config {
            if {[string is alnum $value] && $value ne "true" && $value ne "false"} {
                puts "    $key=\"$value\""
            } else {
                puts "    $key=$value"
            }
        }
        
        puts ")"
        puts "=================================================="
    }
    
    # Gibt das equivalente Slash-Kommando aus
    proc print_slash_command {config} {
        set task [dict get $config task]
        set label "agent"
        if {[dict exists $config label]} {
            set label [dict get $config label]
        }
        set model ""
        if {[dict exists $config model]} {
            set model [dict get $config model]
        }
        
        set cmd "/subagents spawn $label \"$task\""
        if {$model ne ""} {
            append cmd " --model $model"
        }
        if {[dict exists $config thinking]} {
            append cmd " --thinking [dict get $config thinking]"
        }
        
        puts "\n💬 Slash Command:"
        puts "=================================================="
        puts $cmd
        puts "=================================================="
    }
}

# Hauptfunktion
proc main {} {
    # Kommandozeilenargumente definieren
    set options {
        {task.arg "" "Aufgabenbeschreibung"}
        {label.arg "" "Optionaler Label"}
        {model.arg "" "KI-Modell"}
        {thinking.arg "" "Thinking Level"}
        {timeout.arg 900 "Timeout in Sekunden (default: 900)"}
        {thread.boolean "Thread-Binding aktivieren"}
        {mode.arg "run" "Run mode"}
        {output.arg "tool" "Output format"}
    }
    
    # Parse Argumente
    if {[catch {cmdline::typedGetoptions argv $options} result]} {
        puts stderr "Fehler beim Parsen der Argumente: $result"
        exit 1
    }
    
    array set opts $result
    
    # Validiere erforderliche Argumente
    if {$opts(task) eq ""} {
        puts stderr "Fehler: --task ist erforderlich"
        exit 1
    }
    
    # Validiere Model-Auswahl
    if {$opts(model) ne "" && $opts(model) ni $::MODELS} {
        puts stderr "Fehler: Ungültiges Modell. Gültige Optionen: [join $::MODELS ", "]"
        exit 1
    }
    
    # Validiere Thinking-Level
    if {$opts(thinking) ne "" && $opts(thinking) ni {"low" "medium" "high"}} {
        puts stderr "Fehler: Ungültiger Thinking-Level. Gültige Optionen: low, medium, high"
        exit 1
    }
    
    # Validiere Mode
    if {$opts(mode) ni {"run" "session"}} {
        puts stderr "Fehler: Ungültiger Mode. Gültige Optionen: run, session"
        exit 1
    }
    
    # Validiere Output-Format
    if {$opts(output) ni {"tool" "slash" "json"}} {
        puts stderr "Fehler: Ungültiges Output-Format. Gültige Optionen: tool, slash, json"
        exit 1
    }
    
    # Erstelle Konfiguration
    set config [SubAgentSpawner::get_spawn_config \
        task $opts(task) \
        label $opts(label) \
        model $opts(model) \
        thinking $opts(thinking) \
        timeout $opts(timeout) \
        thread $opts(thread) \
        mode $opts(mode)]
    
    # Zeige Konfiguration
    puts "✅ Sub-Agent Konfiguration:"
    puts [::json::dict2json $config 2]
    
    # Zeige entsprechendes Output-Format
    switch $opts(output) {
        "tool" {
            SubAgentSpawner::print_spawn_command $config
        }
        "slash" {
            SubAgentSpawner::print_slash_command $config
        }
        "json" {
            puts "\n📄 JSON:"
            puts [::json::dict2json $config]
            
            # Speichere als Datei
            set label "spawn"
            if {[dict exists $config label]} {
                set label [dict get $config label]
            }
            set outputFile "/tmp/subagent_${label}.json"
            
            if {[catch {open $outputFile w} fid]} {
                puts stderr "Fehler beim Öffnen der Datei $outputFile: $fid"
            } else {
                puts [::json::dict2json $config 2] $fid
                close $fid
                puts "💾 Gespeichert: $outputFile"
            }
        }
    }
}

# Starte Hauptprogramm
if {[info script] eq $argv0} {
    main
}
