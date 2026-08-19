#!/usr/bin/env tclsh8.6
# irc_bot_syntax.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/irc_bot_syntax.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/irc_bot_syntax.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

# IRC Bot command syntax for pbot (Perl), Limnoria (Python), and Eggdrop (Tcl).
# Fetches syntax from documentation sources.

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

# IRC Bot command syntax reference.
# Sources:
# - pbot: https://github.com/pragma-/pbot
# - Limnoria: https://docs.limnoria.net/
# - Eggdrop: https://docs.eggheads.org/

# Define PBOT commands
set PBOT_COMMANDS [dict create]

dict set PBOT_COMMANDS "keyword add" [create_bot_command \
    "pbot" \
    "keyword add" \
    "keyword add <keyword> <text>" \
    "keyword add hello Hello, World!" \
    "Add a keyword trigger" \
    "admin"]

dict set PBOT_COMMANDS "fact add" [create_bot_command \
    "pbot" \
    "fact add" \
    "fact add <channel> <subject> <text>" \
    "fact add #channel python Python is a programming language" \
    "Add a factoid" \
    " whitelisted"]

dict set PBOT_COMMANDS "ban" [create_bot_command \
    "pbot" \
    "ban" \
    "ban <nick|mask> [duration] [reason]" \
    "ban spambot 1h Spamming" \
    "Ban a user" \
    "op"]

# Define Limnoria commands
set LIMNORIA_COMMANDS [dict create]

dict set LIMNORIA_COMMANDS "config channel" [create_bot_command \
    "limnoria" \
    "config channel" \
    "config channel <#channel> <plugin>.<variable> <value>" \
    "config channel #bot supybot.plugins.Channel.enabled True" \
    "Configure channel-specific settings" \
    "admin"]

dict set LIMNORIA_COMMANDS "load" [create_bot_command \
    "limnoria" \
    "load" \
    "load <plugin>" \
    "load User" \
    "Load a plugin" \
    "owner"]

dict set LIMNORIA_COMMANDS "aka add" [create_bot_command \
    "limnoria" \
    "aka add" \
    "aka add <name> <command>" \
    "aka add hi say Hello \$nick!" \
    "Create command alias" \
    "admin"]

# Define Eggdrop commands
set EGGDROP_COMMANDS [dict create]

dict set EGGDROP_COMMANDS "bind" [create_bot_command \
    "eggdrop" \
    "bind" \
    "bind <type> <flags> <keyword> <proc>" \
    "bind pub - !hello pub_hello" \
    "Bind a command to a Tcl procedure" \
    "n/a (script)"]

dict set EGGDROP_COMMANDS "putserv" [create_bot_command \
    "eggdrop" \
    "putserv" \
    "putserv <text>" \
    "putserv PRIVMSG #channel :Hello World" \
    "Send raw IRC command" \
    "n/a (script)"]

dict set EGGDROP_COMMANDS "setudef" [create_bot_command \
    "eggdrop" \
    "setudef" \
    "setudef <type> <name>" \
    "setudef str bot_setting" \
    "Define user-defined variable" \
    "n/a (script)"]

# All commands dictionary
set ALL_COMMANDS [dict create \
    "pbot" $PBOT_COMMANDS \
    "limnoria" $LIMNORIA_COMMANDS \
    "eggdrop" $EGGDROP_COMMANDS]

# Get command syntax for a specific bot
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

# List available commands for a bot or all bots
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

# Generate a script template for a bot
proc generate_script_template {bot purpose} {
    switch [string tolower $bot] {
        "pbot" {
            set underscore_purpose [regsub -all { } $purpose _]
            return "# pbot applet - $purpose\n# Place in ~/.pbot/applets/\n\nuse strict;\nuse warnings;\n\nsub $underscore_purpose {\n    my (\$self, \$from, \$to, \$args) = \@_;\n    \n    # Your code here\n    return \"Result: \$args\";\n}\n\n1;"
        }
        "limnoria" {
            set clean_purpose [regsub -all { } $purpose ""]
            set title_purpose [string totitle $clean_purpose]
            return "# Limnoria plugin - $purpose\n# Place in plugins/$clean_purpose/\n\nfrom supybot import utils, plugins, ircutils, callbacks\nfrom supybot.commands import *\n\nclass $title_purpose(callbacks.Plugin):\n    \"\"\"$purpose\"\"\"\n    \n    threaded = True\n    \n    def [regsub -all { } $purpose _](self, irc, msg, args):\n        \"\"\"<args>\"\"\"\n        irc.reply(\"Hello from $purpose!\")\n    \nClass = $title_purpose"
        }
        "eggdrop" {
            set underscore_purpose [regsub -all { } $purpose _]
            return "# Eggdrop Tcl script - $purpose\n# Add to eggdrop.conf: source scripts/$underscore_purpose.tcl\n\nproc $underscore_purpose {nick uhost hand chan arg} {\n    putserv \"PRIVMSG \$chan :Hello \$nick, this is $purpose!\"\n}\n\nbind pub - !$underscore_purpose $underscore_purpose"
        }
        default {
            return "# Unknown bot"
        }
    }
}

# Convert dict to JSON-like format for output
proc dict_to_json {d {indent 0}} {
    set spaces [string repeat " " $indent]
    set result "\{"
    set first 1
    dict for {key value} $d {
        if {!$first} {
            append result ","
        }
        append result "\n${spaces}  \"$key\": "
        if {[llength $value] > 1 && [lindex $value 0] eq "dict"} {
            append result [dict_to_json $value [expr {$indent + 2}]]
        } else {
            append result "\"$value\""
        }
        set first 0
    }
    append result "\n${spaces}\}"
    return $result
}

# Main function
proc main {} {
    global argv ALL_COMMANDS
    
    # Simple argument parsing
    set bot ""
    set command ""
    set list_mode 0
    set template ""
    
    set i 0
    while {$i < [llength $argv]} {
        set arg [lindex $argv $i]
        incr i
        
        switch $arg {
            "--bot" {
                if {$i < [llength $argv]} {
                    set bot [lindex $argv $i]
                    incr i
                }
            }
            "--command" {
                if {$i < [llength $argv]} {
                    set command [lindex $argv $i]
                    incr i
                }
            }
            "--list" {
                set list_mode 1
            }
            "--template" {
                if {$i < [llength $argv]} {
                    set template [lindex $argv $i]
                    incr i
                }
            }
        }
    }
    
    if {$bot eq ""} {
        puts "Error: --bot is required"
        exit 1
    }
    
    if {$list_mode} {
        set commands [list_commands $bot]
        set result_dict [dict create $bot $commands]
        puts [dict_to_json $result_dict]
    } elseif {$command ne ""} {
        set cmd [get_command $bot $command]
        if {$cmd ne ""} {
            puts "Bot: [dict get $cmd bot]"
            puts "Command: [dict get $cmd command]"
            puts "Syntax: [dict get $cmd syntax]"
            puts "Example: [dict get $cmd example]"
            puts "Description: [dict get $cmd description]"
            set perm [dict get $cmd permission]
            if {$perm ne ""} {
                puts "Permission: $perm"
            }
        } else {
            puts "Command not found: $command"
            puts "Available commands:"
            set cmds [list_commands $bot]
            set result_dict [dict create $bot $cmds]
            puts [dict_to_json $result_dict]
        }
    } elseif {$template ne ""} {
        set template_result [generate_script_template $bot $template]
        puts $template_result
    } else {
        puts "No action specified. Use --list, --command, or --template."
    }
}

# Run main if script is executed directly
if {[info script] eq $argv0} {
    main
}
