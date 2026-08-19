#!/usr/bin/env pwsh
# irc_bot_syntax.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/irc_bot_syntax.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/irc_bot_syntax.py
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
IRC Bot command syntax for pbot (Perl), Limnoria (Python), and Eggdrop (Tcl).
Fetches syntax from documentation sources.
#>

class BotCommand {
    [string]$Bot
    [string]$Command
    [string]$Syntax
    [string]$Example
    [string]$Description
    [string]$Permission

    BotCommand([string]$bot, [string]$command, [string]$syntax, [string]$example, [string]$description, [string]$permission) {
        $this.Bot = $bot
        $this.Command = $command
        $this.Syntax = $syntax
        $this.Example = $example
        $this.Description = $description
        $this.Permission = $permission
    }

    BotCommand([string]$bot, [string]$command, [string]$syntax, [string]$example, [string]$description) {
        $this.Bot = $bot
        $this.Command = $command
        $this.Syntax = $syntax
        $this.Example = $example
        $this.Description = $description
        $this.Permission = $null
    }
}

class IRCBotSyntax {
    <#
    .SYNOPSIS
    IRC Bot command syntax reference.
    Sources:
    - pbot: https://github.com/pragma-/pbot
    - Limnoria: https://docs.limnoria.net/
    - Eggdrop: https://docs.eggheads.org/
    #>

    static [hashtable]$PBOT_COMMANDS = @{
        "keyword add" = [BotCommand]::new(
            "pbot",
            "keyword add",
            "keyword add <keyword> <text>",
            "keyword add hello Hello, World!",
            "Add a keyword trigger",
            "admin"
        )
        "fact add" = [BotCommand]::new(
            "pbot",
            "fact add",
            "fact add <channel> <subject> <text>",
            "fact add #channel python Python is a programming language",
            "Add a factoid",
            " whitelisted"
        )
        "ban" = [BotCommand]::new(
            "pbot",
            "ban",
            "ban <nick|mask> [duration] [reason]",
            "ban spambot 1h Spamming",
            "Ban a user",
            "op"
        )
    }

    static [hashtable]$LIMNORIA_COMMANDS = @{
        "config channel" = [BotCommand]::new(
            "limnoria",
            "config channel",
            "config channel <#channel> <plugin>.<variable> <value>",
            "config channel #bot supybot.plugins.Channel.enabled True",
            "Configure channel-specific settings",
            "admin"
        )
        "load" = [BotCommand]::new(
            "limnoria",
            "load",
            "load <plugin>",
            "load User",
            "Load a plugin",
            "owner"
        )
        "aka add" = [BotCommand]::new(
            "limnoria",
            "aka add",
            "aka add <name> <command>",
            "aka add hi say Hello `$nick!",
            "Create command alias",
            "admin"
        )
    }

    static [hashtable]$EGGDROP_COMMANDS = @{
        "bind" = [BotCommand]::new(
            "eggdrop",
            "bind",
            "bind <type> <flags> <keyword> <proc>",
            "bind pub - !hello pub_hello",
            "Bind a command to a Tcl procedure",
            "n/a (script)"
        )
        "putserv" = [BotCommand]::new(
            "eggdrop",
            "putserv",
            "putserv <text>",
            "putserv PRIVMSG #channel :Hello World",
            "Send raw IRC command",
            "n/a (script)"
        )
        "setudef" = [BotCommand]::new(
            "eggdrop",
            "setudef",
            "setudef <type> <name>",
            "setudef str bot_setting",
            "Define user-defined variable",
            "n/a (script)"
        )
    }

    static [hashtable]$ALL_COMMANDS = @{
        "pbot" = [IRCBotSyntax]::PBOT_COMMANDS
        "limnoria" = [IRCBotSyntax]::LIMNORIA_COMMANDS
        "eggdrop" = [IRCBotSyntax]::EGGDROP_COMMANDS
    }

    static [BotCommand] GetCommand([string]$bot, [string]$command) {
        $bot = $bot.ToLower()
        $command = $command.ToLower()

        if ([IRCBotSyntax]::ALL_COMMANDS.ContainsKey($bot)) {
            $botCommands = [IRCBotSyntax]::ALL_COMMANDS[$bot]
            if ($botCommands.ContainsKey($command)) {
                return $botCommands[$command]
            }
        }
        return $null
    }

    static [hashtable] ListCommands([string]$bot) {
        if ($bot) {
            $bot = $bot.ToLower()
            if ([IRCBotSyntax]::ALL_COMMANDS.ContainsKey($bot)) {
                $commands = [IRCBotSyntax]::ALL_COMMANDS[$bot].Keys | Sort-Object
                return @{$bot = @($commands)}
            }
            return @{$bot = @()}
        }
        else {
            $result = @{}
            foreach ($key in [IRCBotSyntax]::ALL_COMMANDS.Keys) {
                $commands = [IRCBotSyntax]::ALL_COMMANDS[$key].Keys | Sort-Object
                $result[$key] = @($commands)
            }
            return $result
        }
    }

    static [string] GenerateScriptTemplate([string]$bot, [string]$purpose) {
        $templates = @{
            "pbot" = @"
# pbot applet - $purpose
# Place in ~/.pbot/applets/

use strict;
use warnings;

sub $($purpose -replace ' ','_') {
    my (`$self, `$from, `$to, `$args) = @_;
    
    # Your code here
    return "Result: `$args";
}

1;
"@
            "limnoria" = @"
# Limnoria plugin - $purpose
# Place in plugins/$($purpose -replace ' ','')

from supybot import utils, plugins, ircutils, callbacks
from supybot.commands import *

class $(($purpose -replace ' ','').Substring(0,1).ToUpper()+($purpose -replace ' ','').Substring(1))(callbacks.Plugin):
    """$purpose"""
    
    threaded = True
    
    def $($purpose -replace ' ','_')(self, irc, msg, args):
        """<args>"""
        irc.reply("Hello from $purpose!")
    
Class = $(($purpose -replace ' ','').Substring(0,1).ToUpper()+($purpose -replace ' ','').Substring(1))
"@
            "eggdrop" = @"
# Eggdrop Tcl script - $purpose
# Add to eggdrop.conf: source scripts/$($purpose -replace ' ','_').tcl

proc $($purpose -replace ' ','_') {nick uhost hand chan arg} {
    putserv "PRIVMSG `$chan :Hello `$nick, this is $purpose!"
}

bind pub - !$($purpose -replace ' ','_') $($purpose -replace ' ','_')
"@
        }

        $botLower = $bot.ToLower()
        if ($templates.ContainsKey($botLower)) {
            return $templates[$botLower]
        }
        return "# Unknown bot"
    }
}

function Main {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("pbot", "limnoria", "eggdrop")]
        [string]$Bot,

        [string]$Command,

        [switch]$List,

        [string]$Template
    )

    if ($List) {
        $commands = [IRCBotSyntax]::ListCommands($Bot)
        $commands | ConvertTo-Json -Depth 3
    }
    elseif ($Command) {
        $cmd = [IRCBotSyntax]::GetCommand($Bot, $Command)
        if ($cmd) {
            Write-Output "Bot: $($cmd.Bot)"
            Write-Output "Command: $($cmd.Command)"
            Write-Output "Syntax: $($cmd.Syntax)"
            Write-Output "Example: $($cmd.Example)"
            Write-Output "Description: $($cmd.Description)"
            if ($cmd.Permission) {
                Write-Output "Permission: $($cmd.Permission)"
            }
        }
        else {
            Write-Output "Command not found: $Command"
            Write-Output "Available commands:"
            $cmds = [IRCBotSyntax]::ListCommands($Bot)
            $cmds | ConvertTo-Json -Depth 3
        }
    }
    elseif ($Template) {
        $template = [IRCBotSyntax]::GenerateScriptTemplate($Bot, $Template)
        Write-Output $template
    }
}

# Parse command line arguments
$paramBot = $null
$paramCommand = $null
$paramList = $false
$paramTemplate = $null

for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        "--bot" {
            $i++
            if ($i -lt $args.Count) {
                $paramBot = $args[$i]
            }
        }
        "--command" {
            $i++
            if ($i -lt $args.Count) {
                $paramCommand = $args[$i]
            }
        }
        "--list" {
            $paramList = $true
        }
        "--template" {
            $i++
            if ($i -lt $args.Count) {
                $paramTemplate = $args[$i]
            }
        }
    }
}

# Validate required parameters
if (-not $paramBot) {
    Write-Error "Missing required parameter --bot"
    exit 1
}

# Call main function with parsed parameters
Main -Bot $paramBot -Command $paramCommand -List:$paramList -Template $paramTemplate
