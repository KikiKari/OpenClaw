#!/usr/bin/env tclsh8.6
# abstraction-provenance: {"artifact_sha256": "a8e6faafadcc38ad961095bd1858ae9212a5d05ecda8098c42fbcf9266ca455e", "source_sha256": "e7fd0186c81e698f59895dc87d98d60489bddd55b4ee6f4ba864c23613d06f6b", "target_language": "tcl"}
# irc_bot_syntax.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/irc_bot_syntax.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/irc_bot_syntax.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

package require json

# IRC Bot command syntax reference.
# Sources:
# - pbot: https://github.com/pragma-/pbot
# - Limnoria: https://docs.limnoria.net/
# - Eggdrop: https://docs.eggheads.org/

# Define BotCommand structure as dict
proc create_bot_command {bot command syntax example description {permission ""}} {
    return [dict create \
        bot $bot \
        command $command \
        syntax $syntax \
        example $example \
        description $description \
        permission $permission]
}

# Define command sets
set PBOT_COMMANDS [dict create \
    "keyword add" [create_bot_command \
        "pbot" \
        "keyword add" \
        "keyword add <keyword> <text>" \
        "keyword add hello Hello, World!" \
        "Add a keyword trigger" \
        "admin"] \
    "fact add" [create_bot_command \
        "pbot" \
        "fact add" \
        "fact add <channel> <subject> <text>" \
        "fact add #channel python Python is a programming language" \
        "Add a factoid" \
        " whitelisted"] \
    "ban" [create_bot_command \
        "pbot" \
        "ban" \
        "ban <nick|mask> [duration] [reason]" \
        "ban spambot 1h Spamming" \
        "Ban a user" \
        "op"]]

set LIMNORIA_COMMANDS [dict create \
    "config channel" [create_bot_command \
        "limnoria" \
        "config channel" \
        "config channel <#channel> <plugin>.<variable> <value>" \
        "config channel #bot supybot.plugins.Channel.enabled True" \
        "Configure channel-specific settings" \
        "admin"] \
    "load" [create_bot_command \
        "limnoria" \
        "load" \
        "load <plugin>" \
        "load User" \
        "Load a plugin" \
        "owner"] \
    "aka add" [create_bot_command \
        "limnoria" \
        "aka add" \
        "aka add <name> <command>" \
        "aka add hi say Hello \$nick!" \
        "Create command alias" \
        "admin"]]

set EGGDROP_COMMANDS [dict create \
    "bind" [create_bot_command \
        "eggdrop" \
        "bind" \
        "bind <type> <flags> <keyword> <proc>" \
        "bind pub - !hello pub_hello" \
        "Bind a command to a Tcl procedure" \
        "n/a (script)"] \
    "putserv" [create_bot_command \
        "eggdrop" \
        "putserv" \
        "putserv <text>" \
        "putserv PRIVMSG #channel :Hello World" \
        "Send raw IRC command" \
        "n/a (script)"] \
    "setudef" [create_bot_command \
        "eggdrop" \
        "setudef" \
        "setudef <type> <name>" \
        "setudef str bot_setting" \
        "Define user-defined variable" \
        "n/a (script)"]]

set ALL_COMMANDS [dict create \
    "pbot" $PBOT_COMMANDS \
    "limnoria" $LIMNORIA_COMMANDS \
    "eggdrop" $EGGDROP_COMMANDS]

proc get_command {bot command} {
    global ALL_COMMANDS
    set bot [string tolower $bot]
    set command [string tolower $command]
    
    if {[dict exists $ALL_COMMANDS $bot]} {
        set bot_commands [dict get $ALL_COMMANDS $bot]
        if {[dict exists $bot_commands $command]} {
            return [dict get $bot_commands $command]
        }
    }
    return ""
}

proc list_commands {{bot ""}} {
    global ALL_COMMANDS
    if {$bot ne ""} {
        set bot [string tolower $bot]
        if {[dict exists $ALL_COMMANDS $bot]} {
            set bot_commands [dict get $ALL_COMMANDS $bot]
            return [dict keys $bot_commands]
        } else {
            return {}
        }
    } else {
        set result [dict create]
        dict for {bot_name bot_commands} $ALL_COMMANDS {
            dict set result $bot_name [dict keys $bot_commands]
        }
        return $result
    }
}

proc generate_script_template {bot purpose} {
    switch [string tolower $bot] {
        "pbot" {
            set safe_purpose [regsub -all {[^a-zA-Z0-9_]} $purpose {_}]
            return "# pbot applet - $purpose\n# Place in ~/.pbot/applets/\n\nuse strict;\nuse warnings;\n\nsub $safe_purpose {\n    my (\$self, \$from, \$to, \$args) = \@_;\n    \n    # Your code here\n    return \"Result: \$args\";\n}\n\n1;"
        }
        "limnoria" {
            set class_name [string map { { } {} } [string title $purpose]]
            set method_name [regsub -all {[^a-zA-Z0-9_]} $purpose {_}]
            return "# Limnoria plugin - $purpose\n# Place in plugins/$class_name/\n\nfrom supybot import utils, plugins, ircutils, callbacks\nfrom supybot.commands import *\n\nclass $class_name(callbacks.Plugin):\n    \"\"\"$purpose\"\"\"\n    \n    threaded = True\n    \n    def $method_name(self, irc, msg, args):\n        \"\"\"<args>\"\"\"\n        irc.reply(\"Hello from $purpose!\")\n    \nClass = $class_name"
        }
        "eggdrop" {
            set proc_name [regsub -all {[^a-zA-Z0-9_]} $purpose {_}]
            return "# Eggdrop Tcl script - $purpose\n# Add to eggdrop.conf: source scripts/${proc_name}.tcl\n\nproc $proc_name {nick uhost hand chan arg} {\n    putserv \"PRIVMSG \$chan :Hello \$nick, this is $purpose!\"\n}\n\nbind pub - !$proc_name $proc_name"
        }
        default {
            return "# Unknown bot"
        }
    }
}

proc main {} {
    global argv
    
    # Simple argument parsing since we don't have argparse in Tcl
    set args $argv
    set bot ""
    set command ""
    set list_mode false
    set template ""
    
    set i 0
    while {$i < [llength $args]} {
        set arg [lindex $args $i]
        incr i
        
        switch $arg {
            "--bot" {
                if {$i < [llength $args]} {
                    set bot [lindex $args $i]
                    incr i
                }
            }
            "--command" {
                if {$i < [llength $args]} {
                    set command [lindex $args $i]
                    incr i
                }
            }
            "--list" {
                set list_mode true
            }
            "--template" {
                if {$i < [llength $args]} {
                    set template [lindex $args $i]
                    incr i
                }
            }
        }
    }
    
    if {$bot eq ""} {
        puts stderr "Error: --bot is required"
        exit 1
    }
    
    if {$list_mode} {
        set commands [list_commands $bot]
        set result_dict [dict create $bot $commands]
        puts [::json::write object $bot [::json::write array {*}$commands]]
    } elseif {$command ne ""} {
        set cmd [get_command $bot $command]
        if {$cmd ne ""} {
            puts "Bot: [dict get $cmd bot]"
            puts "Command: [dict get $cmd command]"
            puts "Syntax: [dict get $cmd syntax]"
            puts "Example: [dict get $cmd example]"
            puts "Description: [dict get $cmd description]"
            if {[dict get $cmd permission] ne ""} {
                puts "Permission: [dict get $cmd permission]"
            }
        } else {
            puts "Command not found: $command"
            puts "Available commands:"
            set cmds [list_commands $bot]
            set result_dict [dict create $bot $cmds]
            puts [::json::write object $bot [::json::write array {*}$cmds]]
        }
    } elseif {$template ne ""} {
        set template_str [generate_script_template $bot $template]
        puts $template_str
    } else {
        puts stderr "Error: must specify --list, --command, or --template"
        exit 1
    }
}

if {[info script] eq $argv0} {
    main
}
