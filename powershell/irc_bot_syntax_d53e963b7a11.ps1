#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "e3bd0b151440e763438a09458b70cb668ca60f63cf54c7d5f8c199ccdb19318e", "source_sha256": "e7fd0186c81e698f59895dc87d98d60489bddd55b4ee6f4ba864c23613d06f6b", "target_language": "powershell"}
# irc_bot_syntax.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/irc_bot_syntax.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/irc_bot_syntax.py
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
IRC Bot command syntax for pbot (Perl), Limnoria (Python), and Eggdrop (Tcl).
.DESCRIPTION
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
}

class IRCBotSyntax {
    <#
    .SYNOPSIS
    IRC Bot command syntax reference.
    .DESCRIPTION
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

        $botCommands = [IRCBotSyntax]::ALL_COMMANDS[$bot]
        if ($null -ne $botCommands) {
            return $botCommands[$command]
        }
        return $null
    }

    static [hashtable] ListCommands([string]$bot) {
        if ($bot) {
            $bot = $bot.ToLower()
            $commands = [IRCBotSyntax]::ALL_COMMANDS[$bot]
            if ($null -ne $commands) {
                return @{$bot = @($commands.Keys)}
            }
            return @{$bot = @()}
        }
        $result = @{}
        foreach ($key in [IRCBotSyntax]::ALL_COMMANDS.Keys) {
            $result[$key] = @([IRCBotSyntax]::ALL_COMMANDS[$key].Keys)
        }
        return $result
    }

    static [string] GenerateScriptTemplate([string]$bot, [string]$purpose) {
        $templates = @{
            "pbot" = @"
# pbot applet - $purpose
# Place in ~/.pbot/applets/

use strict;
use warnings;

sub $($purpose.Replace(' ', '_')) {
    my `$(self, `$from, `$to, `$args) = @_;
    
    # Your code here
    return "Result: `$args";
}

1;

"@
            "limnoria" = @"
# Limnoria plugin - $($purpose.Replace(' ', ''))
# Place in plugins/$($purpose.Replace(' ', ''))/

from supybot import utils, plugins, ircutils, callbacks
from supybot.commands import *

class $($purpose.Replace(' ', '').Substring(0, 1).ToUpper() + $purpose.Replace(' ', '').Substring(1))(callbacks.Plugin):
    """"""$purpose""""""
    
    threaded = True
    
    def $($purpose.Replace(' ', '_'))(self, irc, msg, args):
        """"""<args>""""""
        irc.reply("Hello from $purpose!")
    
Class = $($purpose.Replace(' ', '').Substring(0, 1).ToUpper() + $purpose.Replace(' ', '').Substring(1))

"@
            "eggdrop" = @"
# Eggdrop Tcl script - $($purpose.Replace(' ', '_'))
# Add to eggdrop.conf: source scripts/$($purpose.Replace(' ', '_')).tcl

proc $($purpose.Replace(' ', '_')) {nick uhost hand chan arg} {
    putserv "PRIVMSG `$chan :Hello `$nick, this is $purpose!"
}

bind pub - !$($purpose.Replace(' ', '_')) $($purpose.Replace(' ', '_'))

"@
        }
        return $templates[$bot.ToLower()]
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

    $syntax = New-Object IRCBotSyntax

    if ($List) {
        $commands = [IRCBotSyntax]::ListCommands($Bot)
        $commands | ConvertTo-Json -Depth 10
    } elseif ($Command) {
        $cmd = [IRCBotSyntax]::GetCommand($Bot, $Command)
        if ($cmd) {
            Write-Host "Bot: $($cmd.Bot)"
            Write-Host "Command: $($cmd.Command)"
            Write-Host "Syntax: $($cmd.Syntax)"
            Write-Host "Example: $($cmd.Example)"
            Write-Host "Description: $($cmd.Description)"
            if ($cmd.Permission) {
                Write-Host "Permission: $($cmd.Permission)"
            }
        } else {
            Write-Host "Command not found: $Command"
            Write-Host "Available commands:"
            $cmds = [IRCBotSyntax]::ListCommands($Bot)
            $cmds | ConvertTo-Json -Depth 10
        }
    } elseif ($Template) {
        $templateContent = [IRCBotSyntax]::GenerateScriptTemplate($Bot, $Template)
        Write-Host $templateContent
    }
}

# Parameter parsing
$paramBot = ""
$paramCommand = ""
$paramList = $false
$paramTemplate = ""

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
    Write-Host "Error: --bot parameter is required"
    exit 1
}

# Call main function with parsed parameters
Main -Bot $paramBot -Command $paramCommand -List:$paramList -Template $paramTemplate
