#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "9d5813b67bc70a811a57bb50259234dd7ce7be14033360cb3073d2abc376195a", "source_sha256": "f911bfbdbdc66c53e970ead9851f23e8c415a17f83d92cea3a53539f83a49ad2", "target_language": "tcl"}
# spawn_agent.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway2:skills/sub-agents-utils/scripts/spawn_agent.py
# Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

# Sub-Agent spawner - Einfache CLI für sessions_spawn

package require json
package require cmdline

# WORKSPACE wird hier direkt im Skript definiert
set WORKSPACE "/home/openclaw/.openclaw/workspace"

# Füge WORKSPACE zum auto_path hinzu, falls noch nicht vorhanden
if {[lsearch -exact $::auto_path $WORKSPACE] == -1} {
    lappend ::auto_path $WORKSPACE
}

# Lade das Modul openclaw_models
if {[catch {package require openclaw_models} err]} {
    puts stderr "Fehler beim Laden von openclaw_models: $err"
    exit 1
}

# Verfügbare Modelle abrufen
if {[catch {configured_models} MODELS]} {
    puts stderr "Modellkonfiguration kann nicht geladen werden: $MODELS"
    exit 1
}

# Hilfsfunktion zur Erstellung der Konfiguration
proc get_spawn_config {args} {
    array set opts $args
    
    set config [dict create task $opts(task)]
    
    if {[info exists opts(label)] && $opts(label) ne ""} {
        dict set config label $opts(label)
    }
    if {[info exists opts(model)] && $opts(model) in $::MODELS} {
        dict set config model $opts(model)
    }
    if {[info exists opts(thinking)] && $opts(thinking) ne ""} {
        dict set config thinking $opts(thinking)
    }
    if {[info exists opts(timeout)] && $opts(timeout) != 0} {
        dict set config runTimeoutSeconds $opts(timeout)
    }
    if {[info exists opts(thread)] && $opts(thread)} {
        dict set config thread true
        if {$opts(mode) eq "run"} {
            dict set config mode "session"
        } else {
            dict set config mode $opts(mode)
        }
    } else {
        dict set config mode $opts(mode)
    }
    
    return $config
}

# Gibt das equivalente Tool-Kommando aus
proc print_spawn_command {config} {
    puts "\n🛠️  Tool-Aufruf:"
    puts "=================================================="
    puts "sessions_spawn("
    dict for {key value} $config {
        if {[string is integer $value] || [string is boolean $value]} {
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
    global argv MODELS
    
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
    
    # Beschreibung für die Hilfe
    set usage "Sub-Agent Spawn Helper\n\n"
    append usage "Beispiele:\n"
    append usage "  [file tail $argv0] --task \"Analyze logs\"\n"
    append usage "  [file tail $argv0] --task \"Code review\" --model openrouter/anthropic/claude-haiku-4.5 --timeout 1800\n"
    append usage "  [file tail $argv0] --task \"Batch process\" --label \"batch-worker\" --thread\n"
    
    # Parsen der Kommandozeilenargumente
    if {[catch {cmdline::typedGetoptions argv $options} result]} {
        puts stderr $result
        exit 1
    }
    
    array set opts $result
    
    # Validierung der Argumente
    if {$opts(task) eq ""} {
        puts stderr "Fehler: --task ist erforderlich"
        exit 1
    }
    
    if {$opts(model) ne "" && $opts(model) ni $MODELS} {
        puts stderr "Fehler: Ungültiges Modell. Gültige Modelle sind: [join $MODELS ", "]"
        exit 1
    }
    
    if {$opts(thinking) ne "" && $opts(thinking) ni {"low" "medium" "high"}} {
        puts stderr "Fehler: Ungültiger Thinking-Level. Gültige Werte sind: low, medium, high"
        exit 1
    }
    
    if {$opts(mode) ni {"run" "session"}} {
        puts stderr "Fehler: Ungültiger Mode. Gültige Werte sind: run, session"
        exit 1
    }
    
    if {$opts(output) ni {"tool" "slash" "json"}} {
        puts stderr "Fehler: Ungültiges Output-Format. Gültige Werte sind: tool, slash, json"
        exit 1
    }
    
    # Konfiguration erstellen
    set config_params [list \
        task $opts(task) \
        label $opts(label) \
        model $opts(model) \
        thinking $opts(thinking) \
        timeout $opts(timeout) \
        thread $opts(thread) \
        mode $opts(mode) \
    ]
    
    set config [get_spawn_config {*}$config_params]
    
    # Ausgabe der Konfiguration
    puts "✅ Sub-Agent Konfiguration:"
    puts [::json::write indented 2 [dict create {*}[dict map {k v} $config {set v}]]]
    
    # Je nach Output-Format unterschiedliche Ausgabe
    switch $opts(output) {
        "tool" {
            print_spawn_command $config
        }
        "slash" {
            print_slash_command $config
        }
        "json" {
            puts "\n📄 JSON:"
            puts [::json::write indented 2 [dict create {*}[dict map {k v} $config {set v}]]]
            
            # Speichere als Datei
            set label [dict get $config label "spawn"]
            set output_file "/tmp/subagent_${label}.json"
            set fh [open $output_file w]
            puts $fh [::json::write indented 2 [dict create {*}[dict map {k v} $config {set v}]]]
            close $fh
            puts "💾 Gespeichert: $output_file"
        }
    }
}

# Starte das Hauptprogramm
if {[info script] eq $argv0} {
    main
}
