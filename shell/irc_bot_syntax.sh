#!/usr/bin/env bash
# irc_bot_syntax.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/irc_bot_syntax.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/irc_bot_syntax.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# IRC Bot command syntax for pbot (Perl), Limnoria (Python), and Eggdrop (Tcl).
# Fetches syntax from documentation sources.

# Declare associative arrays for bot commands
declare -A PBOT_KEYWORD_ADD_SYNTAX PBOT_FACT_ADD_SYNTAX PBOT_BAN_SYNTAX
declare -A LIMNORIA_CONFIG_CHANNEL_SYNTAX LIMNORIA_LOAD_SYNTAX LIMNORIA_AKA_ADD_SYNTAX
declare -A EGGDROP_BIND_SYNTAX EGGDROP_PUTSERV_SYNTAX EGGDROP_SETUDEF_SYNTAX

# Initialize pbot commands
PBOT_KEYWORD_ADD_SYNTAX=(
    [bot]="pbot"
    [command]="keyword add"
    [syntax]="keyword add <keyword> <text>"
    [example]="keyword add hello Hello, World!"
    [description]="Add a keyword trigger"
    [permission]="admin"
)

PBOT_FACT_ADD_SYNTAX=(
    [bot]="pbot"
    [command]="fact add"
    [syntax]="fact add <channel> <subject> <text>"
    [example]="fact add #channel python Python is a programming language"
    [description]="Add a factoid"
    [permission]=" whitelisted"
)

PBOT_BAN_SYNTAX=(
    [bot]="pbot"
    [command]="ban"
    [syntax]="ban <nick|mask> [duration] [reason]"
    [example]="ban spambot 1h Spamming"
    [description]="Ban a user"
    [permission]="op"
)

# Initialize Limnoria commands
LIMNORIA_CONFIG_CHANNEL_SYNTAX=(
    [bot]="limnoria"
    [command]="config channel"
    [syntax]="config channel <#channel> <plugin>.<variable> <value>"
    [example]="config channel #bot supybot.plugins.Channel.enabled True"
    [description]="Configure channel-specific settings"
    [permission]="admin"
)

LIMNORIA_LOAD_SYNTAX=(
    [bot]="limnoria"
    [command]="load"
    [syntax]="load <plugin>"
    [example]="load User"
    [description]="Load a plugin"
    [permission]="owner"
)

LIMNORIA_AKA_ADD_SYNTAX=(
    [bot]="limnoria"
    [command]="aka add"
    [syntax]="aka add <name> <command>"
    [example]="aka add hi say Hello \$nick!"
    [description]="Create command alias"
    [permission]="admin"
)

# Initialize Eggdrop commands
EGGDROP_BIND_SYNTAX=(
    [bot]="eggdrop"
    [command]="bind"
    [syntax]="bind <type> <flags> <keyword> <proc>"
    [example]="bind pub - !hello pub_hello"
    [description]="Bind a command to a Tcl procedure"
    [permission]="n/a (script)"
)

EGGDROP_PUTSERV_SYNTAX=(
    [bot]="eggdrop"
    [command]="putserv"
    [syntax]="putserv <text>"
    [example]="putserv PRIVMSG #channel :Hello World"
    [description]="Send raw IRC command"
    [permission]="n/a (script)"
)

EGGDROP_SETUDEF_SYNTAX=(
    [bot]="eggdrop"
    [command]="setudef"
    [syntax]="setudef <type> <name>"
    [example]="setudef str bot_setting"
    [description]="Define user-defined variable"
    [permission]="n/a (script)"
)

# Function to get command syntax for a specific bot
get_command() {
    local bot="$1"
    local command="$2"
    
    case "${bot,,}" in
        pbot)
            case "${command,,}" in
                "keyword add")
                    echo "bot:pbot"
                    echo "command:keyword add"
                    echo "syntax:${PBOT_KEYWORD_ADD_SYNTAX[syntax]}"
                    echo "example:${PBOT_KEYWORD_ADD_SYNTAX[example]}"
                    echo "description:${PBOT_KEYWORD_ADD_SYNTAX[description]}"
                    echo "permission:${PBOT_KEYWORD_ADD_SYNTAX[permission]}"
                    ;;
                "fact add")
                    echo "bot:pbot"
                    echo "command:fact add"
                    echo "syntax:${PBOT_FACT_ADD_SYNTAX[syntax]}"
                    echo "example:${PBOT_FACT_ADD_SYNTAX[example]}"
                    echo "description:${PBOT_FACT_ADD_SYNTAX[description]}"
                    echo "permission:${PBOT_FACT_ADD_SYNTAX[permission]}"
                    ;;
                "ban")
                    echo "bot:pbot"
                    echo "command:ban"
                    echo "syntax:${PBOT_BAN_SYNTAX[syntax]}"
                    echo "example:${PBOT_BAN_SYNTAX[example]}"
                    echo "description:${PBOT_BAN_SYNTAX[description]}"
                    echo "permission:${PBOT_BAN_SYNTAX[permission]}"
                    ;;
                *)
                    return 1
                    ;;
            esac
            ;;
        limnoria)
            case "${command,,}" in
                "config channel")
                    echo "bot:limnoria"
                    echo "command:config channel"
                    echo "syntax:${LIMNORIA_CONFIG_CHANNEL_SYNTAX[syntax]}"
                    echo "example:${LIMNORIA_CONFIG_CHANNEL_SYNTAX[example]}"
                    echo "description:${LIMNORIA_CONFIG_CHANNEL_SYNTAX[description]}"
                    echo "permission:${LIMNORIA_CONFIG_CHANNEL_SYNTAX[permission]}"
                    ;;
                "load")
                    echo "bot:limnoria"
                    echo "command:load"
                    echo "syntax:${LIMNORIA_LOAD_SYNTAX[syntax]}"
                    echo "example:${LIMNORIA_LOAD_SYNTAX[example]}"
                    echo "description:${LIMNORIA_LOAD_SYNTAX[description]}"
                    echo "permission:${LIMNORIA_LOAD_SYNTAX[permission]}"
                    ;;
                "aka add")
                    echo "bot:limnoria"
                    echo "command:aka add"
                    echo "syntax:${LIMNORIA_AKA_ADD_SYNTAX[syntax]}"
                    echo "example:${LIMNORIA_AKA_ADD_SYNTAX[example]}"
                    echo "description:${LIMNORIA_AKA_ADD_SYNTAX[description]}"
                    echo "permission:${LIMNORIA_AKA_ADD_SYNTAX[permission]}"
                    ;;
                *)
                    return 1
                    ;;
            esac
            ;;
        eggdrop)
            case "${command,,}" in
                "bind")
                    echo "bot:eggdrop"
                    echo "command:bind"
                    echo "syntax:${EGGDROP_BIND_SYNTAX[syntax]}"
                    echo "example:${EGGDROP_BIND_SYNTAX[example]}"
                    echo "description:${EGGDROP_BIND_SYNTAX[description]}"
                    echo "permission:${EGGDROP_BIND_SYNTAX[permission]}"
                    ;;
                "putserv")
                    echo "bot:eggdrop"
                    echo "command:putserv"
                    echo "syntax:${EGGDROP_PUTSERV_SYNTAX[syntax]}"
                    echo "example:${EGGDROP_PUTSERV_SYNTAX[example]}"
                    echo "description:${EGGDROP_PUTSERV_SYNTAX[description]}"
                    echo "permission:${EGGDROP_PUTSERV_SYNTAX[permission]}"
                    ;;
                "setudef")
                    echo "bot:eggdrop"
                    echo "command:setudef"
                    echo "syntax:${EGGDROP_SETUDEF_SYNTAX[syntax]}"
                    echo "example:${EGGDROP_SETUDEF_SYNTAX[example]}"
                    echo "description:${EGGDROP_SETUDEF_SYNTAX[description]}"
                    echo "permission:${EGGDROP_SETUDEF_SYNTAX[permission]}"
                    ;;
                *)
                    return 1
                    ;;
            esac
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to list available commands for a bot or all bots
list_commands() {
    local bot="${1:-}"
    
    if [[ -n "$bot" ]]; then
        case "${bot,,}" in
            pbot)
                echo '{"pbot": ["keyword add", "fact add", "ban"]}'
                ;;
            limnoria)
                echo '{"limnoria": ["config channel", "load", "aka add"]}'
                ;;
            eggdrop)
                echo '{"eggdrop": ["bind", "putserv", "setudef"]}'
                ;;
            *)
                echo "{}"
                ;;
        esac
    else
        echo '{"pbot": ["keyword add", "fact add", "ban"], "limnoria": ["config channel", "load", "aka add"], "eggdrop": ["bind", "putserv", "setudef"]}'
    fi
}

# Function to generate a script template for a bot
generate_script_template() {
    local bot="$1"
    local purpose="$2"
    
    case "${bot,,}" in
        pbot)
            cat <<EOF
# pbot applet - ${purpose}
# Place in ~/.pbot/applets/

use strict;
use warnings;

sub ${purpose// /_} {
    my (\$self, \$from, \$to, \$args) = \@_;
    
    # Your code here
    return "Result: \$args";
}

1;
EOF
            ;;
        limnoria)
            local class_name="${purpose// /}"
            class_name="$(tr '[:lower:]' '[:upper:]' <<<"${class_name:0:1}")${class_name:1}"
            cat <<EOF
# Limnoria plugin - ${purpose}
# Place in plugins/${purpose// /}/

from supybot import utils, plugins, ircutils, callbacks
from supybot.commands import *

class ${class_name}(callbacks.Plugin):
    """${purpose}"""
    
    threaded = True
    
    def ${purpose// /_}(self, irc, msg, args):
        """<args>"""
        irc.reply("Hello from ${purpose}!")
    
Class = ${class_name}
EOF
            ;;
        eggdrop)
            cat <<EOF
# Eggdrop Tcl script - ${purpose}
# Add to eggdrop.conf: source scripts/${purpose// /_}.tcl

proc ${purpose// /_} {nick uhost hand chan arg} {
    putserv "PRIVMSG \$chan :Hello \$nick, this is ${purpose}!"
}

bind pub - !${purpose// /_} ${purpose// /_}
EOF
            ;;
        *)
            echo "# Unknown bot"
            ;;
    esac
}

# Main function
main() {
    local bot=""
    local command=""
    local list=false
    local template=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --bot)
                bot="$2"
                shift 2
                ;;
            --command)
                command="$2"
                shift 2
                ;;
            --list)
                list=true
                shift
                ;;
            --template)
                template="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage: $0 --bot <bot> [--command <command>] | [--list] | [--template <purpose>]"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Validate bot argument
    if [[ -z "$bot" ]]; then
        echo "Error: --bot is required"
        exit 1
    fi
    
    # Process actions
    if [[ "$list" == true ]]; then
        list_commands "$bot"
    elif [[ -n "$command" ]]; then
        if ! get_command "$bot" "$command"; then
            echo "Command not found: $command"
            echo "Available commands:"
            list_commands "$bot"
        fi
    elif [[ -n "$template" ]]; then
        generate_script_template "$bot" "$template"
    else
        echo "Error: One of --command, --list, or --template must be specified"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
