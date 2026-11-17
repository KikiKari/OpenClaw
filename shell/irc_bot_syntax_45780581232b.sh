#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "06b69e6824f1ee6ecf917ed8eb59bd501395d8af62cb4087d0a8fa9f535bd568", "source_sha256": "e7fd0186c81e698f59895dc87d98d60489bddd55b4ee6f4ba864c23613d06f6b", "target_language": "shell"}
# irc_bot_syntax.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/irc_bot_syntax.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/irc_bot_syntax.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# IRC Bot command syntax for pbot (Perl), Limnoria (Python), and Eggdrop (Tcl).
# Fetches syntax from documentation sources.

# Declare associative arrays for bot commands
declare -A PBOT_COMMANDS
declare -A LIMNORIA_COMMANDS
declare -A EGGDROP_COMMANDS

# Initialize pbot commands
PBOT_COMMANDS["keyword add"]="pbot|keyword add|keyword add <keyword> <text>|keyword add hello Hello, World!|Add a keyword trigger|admin"
PBOT_COMMANDS["fact add"]="pbot|fact add|fact add <channel> <subject> <text>|fact add #channel python Python is a programming language|Add a factoid|whitelisted"
PBOT_COMMANDS["ban"]="pbot|ban|ban <nick|mask> [duration] [reason]|ban spambot 1h Spamming|Ban a user|op"

# Initialize limnoria commands
LIMNORIA_COMMANDS["config channel"]="limnoria|config channel|config channel <#channel> <plugin>.<variable> <value>|config channel #bot supybot.plugins.Channel.enabled True|Configure channel-specific settings|admin"
LIMNORIA_COMMANDS["load"]="limnoria|load|load <plugin>|load User|Load a plugin|owner"
LIMNORIA_COMMANDS["aka add"]="limnoria|aka add|aka add <name> <command>|aka add hi say Hello \$nick!|Create command alias|admin"

# Initialize eggdrop commands
EGGDROP_COMMANDS["bind"]="eggdrop|bind|bind <type> <flags> <keyword> <proc>|bind pub - !hello pub_hello|Bind a command to a Tcl procedure|n/a (script)"
EGGDROP_COMMANDS["putserv"]="eggdrop|putserv|putserv <text>|putserv PRIVMSG #channel :Hello World|Send raw IRC command|n/a (script)"
EGGDROP_COMMANDS["setudef"]="eggdrop|setudef|setudef <type> <name>|setudef str bot_setting|Define user-defined variable|n/a (script)"

# Function to get command syntax for a specific bot
get_command() {
    local bot="$1"
    local command="$2"
    local bot_lower="${bot,,}"
    local cmd_lower="${command,,}"
    local result=""
    
    case "$bot_lower" in
        "pbot")
            if [[ -n "${PBOT_COMMANDS[$cmd_lower]:-}" ]]; then
                result="${PBOT_COMMANDS[$cmd_lower]}"
            fi
            ;;
        "limnoria")
            if [[ -n "${LIMNORIA_COMMANDS[$cmd_lower]:-}" ]]; then
                result="${LIMNORIA_COMMANDS[$cmd_lower]}"
            fi
            ;;
        "eggdrop")
            if [[ -n "${EGGDROP_COMMANDS[$cmd_lower]:-}" ]]; then
                result="${EGGDROP_COMMANDS[$cmd_lower]}"
            fi
            ;;
    esac
    
    echo "$result"
}

# Function to list available commands for a bot
list_commands() {
    local bot="${1:-}"
    local output="{"
    
    if [[ -n "$bot" ]]; then
        local bot_lower="${bot,,}"
        output+="\"$bot\":["
        local first=true
        
        case "$bot_lower" in
            "pbot")
                for cmd in "${!PBOT_COMMANDS[@]}"; do
                    if [[ "$first" == true ]]; then
                        output+="\"$cmd\""
                        first=false
                    else
                        output+=",\"$cmd\""
                    fi
                done
                ;;
            "limnoria")
                for cmd in "${!LIMNORIA_COMMANDS[@]}"; do
                    if [[ "$first" == true ]]; then
                        output+="\"$cmd\""
                        first=false
                    else
                        output+=",\"$cmd\""
                    fi
                done
                ;;
            "eggdrop")
                for cmd in "${!EGGDROP_COMMANDS[@]}"; do
                    if [[ "$first" == true ]]; then
                        output+="\"$cmd\""
                        first=false
                    else
                        output+=",\"$cmd\""
                    fi
                done
                ;;
        esac
        output+="]"
    else
        output+="\"pbot\":["
        local first=true
        for cmd in "${!PBOT_COMMANDS[@]}"; do
            if [[ "$first" == true ]]; then
                output+="\"$cmd\""
                first=false
            else
                output+=",\"$cmd\""
            fi
        done
        output+="],\"limnoria\":["
        first=true
        for cmd in "${!LIMNORIA_COMMANDS[@]}"; do
            if [[ "$first" == true ]]; then
                output+="\"$cmd\""
                first=false
            else
                output+=",\"$cmd\""
            fi
        done
        output+="],\"eggdrop\":["
        first=true
        for cmd in "${!EGGDROP_COMMANDS[@]}"; do
            if [[ "$first" == true ]]; then
                output+="\"$cmd\""
                first=false
            else
                output+=",\"$cmd\""
            fi
        done
        output+="]"
    fi
    
    output+="}"
    echo "$output"
}

# Function to generate a script template for a bot
generate_script_template() {
    local bot="$1"
    local purpose="$2"
    local template=""
    local safe_purpose="${purpose// /_}"
    
    case "${bot,,}" in
        "pbot")
            template="# pbot applet - $purpose
# Place in ~/.pbot/applets/

use strict;
use warnings;

sub ${safe_purpose} {
    my (\$self, \$from, \$to, \$args) = \@_;
    
    # Your code here
    return \"Result: \$args\";
}

1;"
            ;;
        "limnoria")
            local class_name="${purpose// /}"
            class_name="$(tr '[:lower:]' '[:upper:]' <<< "${class_name:0:1}")${class_name:1}"
            template="# Limnoria plugin - $purpose
# Place in plugins/${purpose// /}/

from supybot import utils, plugins, ircutils, callbacks
from supybot.commands import *

class $class_name(callbacks.Plugin):
    \"\"\"$purpose\"\"\"
    
    threaded = True
    
    def ${safe_purpose}(self, irc, msg, args):
        \"\"\"<args>\"\"\"
        irc.reply(\"Hello from $purpose!\")
    
Class = $class_name"
            ;;
        "eggdrop")
            template="# Eggdrop Tcl script - $purpose
# Add to eggdrop.conf: source scripts/${safe_purpose}.tcl

proc ${safe_purpose} {nick uhost hand chan arg} {
    putserv \"PRIVMSG \$chan :Hello \$nick, this is $purpose!\"
}

bind pub - !${safe_purpose} ${safe_purpose}"
            ;;
        *)
            template="# Unknown bot"
            ;;
    esac
    
    echo "$template"
}

# Main function
main() {
    local bot=""
    local command=""
    local list_commands_flag=false
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
                list_commands_flag=true
                shift
                ;;
            --template)
                template="$2"
                shift 2
                ;;
            -h|--help)
                echo "IRC Bot command syntax reference"
                echo "Usage: $0 --bot <pbot|limnoria|eggdrop> [--command <command>] [--list] [--template <purpose>]"
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
    
    # Process commands
    if [[ "$list_commands_flag" == true ]]; then
        list_commands "$bot"
    elif [[ -n "$command" ]]; then
        local cmd_result
        cmd_result=$(get_command "$bot" "$command")
        if [[ -n "$cmd_result" ]]; then
            IFS='|' read -r cmd_bot cmd_name cmd_syntax cmd_example cmd_description cmd_permission <<< "$cmd_result"
            echo "Bot: $cmd_bot"
            echo "Command: $cmd_name"
            echo "Syntax: $cmd_syntax"
            echo "Example: $cmd_example"
            echo "Description: $cmd_description"
            if [[ -n "$cmd_permission" ]]; then
                echo "Permission: $cmd_permission"
            fi
        else
            echo "Command not found: $command"
            echo "Available commands:"
            list_commands "$bot"
        fi
    elif [[ -n "$template" ]]; then
        generate_script_template "$bot" "$template"
    else
        echo "Error: Either --command, --list, or --template must be specified"
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
