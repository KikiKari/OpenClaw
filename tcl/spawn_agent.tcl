#!/usr/bin/env tclsh
# spawn_agent.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:skills/sub-agents-utils/scripts/spawn_agent.py
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

# Sub-Agent spawner - Einfache CLI für sessions_spawn

package require json

set WORKSPACE "/home/openclaw/.openclaw/workspace"

# Füge WORKSPACE zum auto_path hinzu, falls noch nicht vorhanden
if {[lsearch -exact $::auto_path $WORKSPACE] == -1} {
    lappend ::auto_path $WORKSPACE
}

# Lade openclaw_models Modul
if [catch {package require openclaw_models} err] {
    puts stderr "Fehler beim Laden von openclaw_models: $err"
    exit 1
}

# Verfügbare Modelle abrufen
if [catch {configured_models} MODELS] {
    puts stderr "Modellkonfiguration kann nicht geladen werden: $MODELS"
    exit 1
}

# Hilfsfunktion zur Konfigurationserstellung
proc get_spawn_config {args} {
    array set opts $args
    
    set config [dict create task $opts(-task)]
    
    if {[info exists opts(-label)] && $opts(-label) ne ""} {
        dict set config label $opts(-label)
    }
    
    if {[info exists opts(-model)] && $opts(-model) in $::MODELS} {
        dict set config model $opts(-model)
    }
    
    if {[info exists opts(-thinking)] && $opts(-thinking) ne ""} {
        dict set config thinking $opts(-thinking)
    }
    
    if {[info exists opts(-timeout)] && $opts(-timeout) != 0} {
        dict set config runTimeoutSeconds $opts(-timeout)
    }
    
    if {[info exists opts(-thread)] && $opts(-thread)} {
        dict set config thread true
        if {$opts(-mode) eq "run"} {
            dict set config mode session
        } else {
            dict set config mode $opts(-mode)
        }
    } else {
        dict set config mode $opts(-mode)
    }
    
    return $config
}

# Gibt das equivalente Tool-Kommando aus
proc print_spawn_command {config} {
    puts "\n🛠️  Tool-Aufruf:"
    puts "=================================================="
    puts "sessions_spawn("
    
    dict for {key value} $config {
        if {[string is wordchar -strict $value] || [string is integer $value]} {
            puts "    $key=$value"
        } else {
            puts "    $key=\"$value\""
        }
    }
    
    puts ")"
    puts "=================================================="
}

# Gibt das equivalente Slash-Kommando aus
proc print_slash_command {config} {
    set task [dict get $config task]
    set label [dict get $config label "agent"]
    set model [dict get $config model ""]
    
    set cmd "/subagents spawn $label \"$task\""
    
    if {$model ne ""} {
        append cmd " --model $model"
    }
    
    if {[dict exists $config thinking]} {
        set thinking [dict get $config thinking]
        append cmd " --thinking $thinking"
    }
    
    puts "\n💬 Slash Command:"
    puts "=================================================="
    puts $cmd
    puts "=================================================="
}

# Hauptprogramm
proc main {} {
    global argv argc
    
    # Argumente parsen
    set task ""
    set label ""
    set model ""
    set thinking ""
    set timeout 900
    set thread false
    set mode "run"
    set output "tool"
    
    # Manuelle Argumentverarbeitung
    for {set i 0} {$i < $argc} {incr i} {
        set arg [lindex $argv $i]
        switch -exact -- $arg {
            "--task" - "-t" {
                incr i
                set task [lindex $argv $i]
            }
            "--label" - "-l" {
                incr i
                set label [lindex $argv $i]
            }
            "--model" - "-m" {
                incr i
                set model [lindex $argv $i]
            }
            "--thinking" {
                incr i
                set thinking [lindex $argv $i]
            }
            "--timeout" {
                incr i
                set timeout [lindex $argv $i]
            }
            "--thread" {
                set thread true
            }
            "--mode" {
                incr i
                set mode [lindex $argv $i]
            }
            "--output" - "-o" {
                incr i
                set output [lindex $argv $i]
            }
            "--help" - "-h" {
                puts "Sub-Agent Spawn Helper\n"
                puts "Usage: $argv0 \[options\]\n"
                puts "Options:"
                puts "  -t, --task TASK           Aufgabenbeschreibung"
                puts "  -l, --label LABEL         Optionaler Label"
                puts "  -m, --model MODEL         KI-Modell"
                puts "      --thinking LEVEL      Thinking Level (low|medium|high)"
                puts "      --timeout SECONDS     Timeout in Sekunden (default: 900)"
                puts "      --thread              Thread-Binding aktivieren"
                puts "      --mode MODE           Run mode (run|session)"
                puts "  -o, --output FORMAT       Output format (tool|slash|json)"
                puts "  -h, --help                Diese Hilfe anzeigen"
                puts "\nBeispiele:"
                puts "  $argv0 -t \"Analyze logs\""
                puts "  $argv0 -t \"Code review\" -m openrouter/anthropic/claude-haiku-4.5 --timeout 1800"
                puts "  $argv0 -t \"Batch process\" -l \"batch-worker\" --thread"
                return
            }
        }
    }
    
    # Validierung
    if {$task eq ""} {
        puts stderr "Fehler: Task ist erforderlich (-t oder --task)"
        exit 1
    }
    
    # Modelvalidierung
    if {$model ne "" && $model ni $::MODELS} {
        puts stderr "Fehler: Ungültiges Modell '$model'"
        puts stderr "Verfügbare Modelle: [join $::MODELS ", "]"
        exit 1
    }
    
    # Thinking-Level validieren
    if {$thinking ne "" && $thinking ni {"low" "medium" "high"}} {
        puts stderr "Fehler: Ungültiger Thinking-Level '$thinking'. Erlaubt: low, medium, high"
        exit 1
    }
    
    # Mode validieren
    if {$mode ni {"run" "session"}} {
        puts stderr "Fehler: Ungültiger Mode '$mode'. Erlaubt: run, session"
        exit 1
    }
    
    # Output validieren
    if {$output ni {"tool" "slash" "json"}} {
        puts stderr "Fehler: Ungültiges Output-Format '$output'. Erlaubt: tool, slash, json"
        exit 1
    }
    
    # Konfiguration erstellen
    set config [get_spawn_config \
        -task $task \
        -label $label \
        -model $model \
        -thinking $thinking \
        -timeout $timeout \
        -thread $thread \
        -mode $mode]
    
    # Konfiguration ausgeben
    puts "✅ Sub-Agent Konfiguration:"
    puts [::json::encode $config 2]
    
    # Je nach Output-Format verfahren
    switch -exact -- $output {
        "tool" {
            print_spawn_command $config
        }
        "slash" {
            print_slash_command $config
        }
        "json" {
            puts "\n📄 JSON:"
            puts [::json::encode $config]
            
            # Speichere als Datei
            set filename [expr {[dict exists $config label] ? [dict get $config label] : "spawn"}]
            set output_file "/tmp/subagent_${filename}.json"
            
            set fh [open $output_file w]
            puts $fh [::json::encode $config 2]
            close $fh
            
            puts "💾 Gespeichert: $output_file"
        }
    }
}

# Starte Hauptprogramm
if {[info script] eq $argv0} {
    main
}
