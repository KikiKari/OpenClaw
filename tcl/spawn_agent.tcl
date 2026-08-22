#!/usr/bin/env tclsh
# spawn_agent.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/sub-agents-utils/scripts/spawn_agent.py
# Erzeugt: 2026-08-22 durch ABSTRACTIONS_MANAGER.py

# Sub-Agent spawner - Einfache CLI für sessions_spawn

package require json
package require cmdline

# Globale Variablen
set MODELS {}

# Lade Modellkonfiguration
proc load_models {} {
    global env
    set configPath [expr {[info exists env(OPENCLAW_CONFIG)] ? $env(OPENCLAW_CONFIG) : "/home/openclaw/.openclaw/openclaw.json"}]
    
    if {![file exists $configPath]} {
        error "Modellkonfiguration kann nicht geladen werden: $configPath: File not found"
    }
    
    set fd [open $configPath r]
    set content [read $fd]
    close $fd
    
    if {[catch {::json::json2dict $content} config]} {
        error "Modellkonfiguration kann nicht geladen werden: $configPath: Invalid JSON"
    }
    
    if {![dict exists $config agents defaults model]} {
        error "Modellkonfiguration kann nicht geladen werden: $configPath: Missing configuration keys"
    }
    
    set modelConfig [dict get $config agents defaults model]
    set candidates [list [dict get $modelConfig primary]]
    
    if {[dict exists $modelConfig fallbacks]} {
        set fallbacks [dict get $modelConfig fallbacks]
        if {[llength $fallbacks] > 0} {
            foreach fallback $fallbacks {
                lappend candidates $fallback
            }
        }
    }
    
    set models {}
    foreach model $candidates {
        if {$model != "" && ![string match "anthropic/*" $model]} {
            if {[lsearch -exact $models $model] == -1} {
                lappend models $model
            }
        }
    }
    
    if {[llength $models] == 0} {
        error "Keine allgemein verfügbaren Modelle in $configPath"
    }
    
    return $models
}

# Initialisiere MODELS
set MODELS [load_models]

# Hilfsklasse für Sub-Agent Spawning
namespace eval SubAgentSpawner {
    # Erstellt Konfiguration für sessions_spawn
    proc get_spawn_config {args} {
        global MODELS
        array set options {
            task ""
            label ""
            model ""
            thinking ""
            timeout 0
            thread false
            mode "run"
        }
        array set options $args
        
        set config [dict create task $options(task)]
        
        if {$options(label) ne ""} {
            dict set config label $options(label)
        }
        if {$options(model) ne "" && [lsearch -exact $MODELS $options(model)] != -1} {
            dict set config model $options(model)
        }
        if {$options(thinking) ne ""} {
            dict set config thinking $options(thinking)
        }
        if {$options(timeout) > 0} {
            dict set config runTimeoutSeconds $options(timeout)
        }
        if {$options(thread)} {
            dict set config thread true
            if {$options(mode) eq "run"} {
                dict set config mode "session"
            } else {
                dict set config mode $options(mode)
            }
        } else {
            dict set config mode $options(mode)
        }
        
        return $config
    }
    
    # Gibt das equivalente Tool-Kommando aus
    proc print_spawn_command {config} {
        puts "\n🛠️  Tool-Aufruf:"
        puts "=================================================="
        puts "sessions_spawn("
        dict for {key value} $config {
            if {[string is alpha $value] && $value ne "true" && $value ne "false"} {
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
        set label [expr {[dict exists $config label] ? [dict get $config label] : "agent"}]
        set model [expr {[dict exists $config model] ? [dict get $config model] : ""}]
        
        set cmd "/subagents spawn $label \"$task\""
        if {$model ne ""} {
            append cmd " --model $model"
        }
        if {[dict exists $config thinking]} {
            set thinking [dict get $config thinking]
            if {$thinking ne ""} {
                append cmd " --thinking $thinking"
            }
        }
        
        puts "\n💬 Slash Command:"
        puts "=================================================="
        puts $cmd
        puts "=================================================="
    }
}

# Hauptprogramm
proc main {} {
    global MODELS argv
    
    # Kommandozeilenoptionen definieren
    set options {
        {task.arg "" "Aufgabenbeschreibung"}
        {label.arg "" "Optionaler Label"}
        {model.arg "" "KI-Modell"}
        {thinking.arg "" "Thinking Level"}
        {timeout.arg 900 "Timeout in Sekunden (default: 900)"}
        {thread "Thread-Binding aktivieren"}
        {mode.arg "run" "Run mode"}
        {output.arg "tool" "Output format"}
    }
    
    set usage "Sub-Agent Spawn Helper\n\nBeispiele:\n  [file tail [info script]] -task \"Analyze logs\"\n  [file tail [info script]] -task \"Code review\" -model openai/gpt-5.6-sol --timeout 1800\n  [file tail [info script]] -task \"Batch process\" -label \"batch-worker\" --thread"
    
    if {[catch {cmdline::typedGetoptions argv $options} result]} {
        puts stderr $result
        exit 1
    }
    
    array set opts $result
    
    # Validierung der Pflichtargumente
    if {$opts(task) eq ""} {
        puts stderr "Fehler: --task ist ein Pflichtfeld"
        exit 1
    }
    
    # Validierung des Modells
    if {$opts(model) ne "" && [lsearch -exact $MODELS $opts(model)] == -1} {
        puts stderr "Fehler: Ungültiges Modell '$opts(model)'. Gültige Optionen: [join $MODELS ", "]"
        exit 1
    }
    
    # Validierung von thinking
    if {$opts(thinking) ne "" && [lsearch -exact {low medium high} $opts(thinking)] == -1} {
        puts stderr "Fehler: Ungültiger Thinking-Wert '$opts(thinking)'. Gültige Optionen: low, medium, high"
        exit 1
    }
    
    # Validierung von mode
    if {[lsearch -exact {run session} $opts(mode)] == -1} {
        puts stderr "Fehler: Ungültiger Mode-Wert '$opts(mode)'. Gültige Optionen: run, session"
        exit 1
    }
    
    # Validierung von output
    if {[lsearch -exact {tool slash json} $opts(output)] == -1} {
        puts stderr "Fehler: Ungültiger Output-Wert '$opts(output)'. Gültige Optionen: tool, slash, json"
        exit 1
    }
    
    # Konfiguration erstellen
    set config [SubAgentSpawner::get_spawn_config \
        task $opts(task) \
        label $opts(label) \
        model $opts(model) \
        thinking $opts(thinking) \
        timeout $opts(timeout) \
        thread $opts(thread) \
        mode $opts(mode) \
    ]
    
    # Ausgabe der Konfiguration
    puts "✅ Sub-Agent Konfiguration:"
    puts [::json::dict2json $config 2]
    
    # Formatierter Output
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
            set label [expr {[dict exists $config label] ? [dict get $config label] : "spawn"}]
            set outputFile "/tmp/subagent_${label}.json"
            set fd [open $outputFile w]
            puts $fd [::json::dict2json $config]
            close $fd
            puts "💾 Gespeichert: $outputFile"
        }
    }
}

# Starte das Programm
if {[info script] eq $argv0} {
    main
}
