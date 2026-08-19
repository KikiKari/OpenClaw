#!/usr/bin/env node
// irc_bot_syntax.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/irc_bot_syntax.py
// auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/irc_bot_syntax.py
// Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

/**
 * IRC Bot command syntax for pbot (Perl), Limnoria (Python), and Eggdrop (Tcl).
 * Fetches syntax from documentation sources.
 */

class BotCommand {
    constructor(bot, command, syntax, example, description, permission = null) {
        this.bot = bot;
        this.command = command;
        this.syntax = syntax;
        this.example = example;
        this.description = description;
        this.permission = permission;
    }
}

class IRCBotSyntax {
    /**
     * IRC Bot command syntax reference.
     * Sources:
     * - pbot: https://github.com/pragma-/pbot
     * - Limnoria: https://docs.limnoria.net/
     * - Eggdrop: https://docs.eggheads.org/
     */
    
    static PBOT_COMMANDS = {
        "keyword add": new BotCommand(
            "pbot",
            "keyword add",
            "keyword add <keyword> <text>",
            "keyword add hello Hello, World!",
            "Add a keyword trigger",
            "admin"
        ),
        "fact add": new BotCommand(
            "pbot",
            "fact add",
            "fact add <channel> <subject> <text>",
            "fact add #channel python Python is a programming language",
            "Add a factoid",
            " whitelisted"
        ),
        "ban": new BotCommand(
            "pbot",
            "ban",
            "ban <nick|mask> [duration] [reason]",
            "ban spambot 1h Spamming",
            "Ban a user",
            "op"
        ),
    };
    
    static LIMNORIA_COMMANDS = {
        "config channel": new BotCommand(
            "limnoria",
            "config channel",
            "config channel <#channel> <plugin>.<variable> <value>",
            "config channel #bot supybot.plugins.Channel.enabled True",
            "Configure channel-specific settings",
            "admin"
        ),
        "load": new BotCommand(
            "limnoria",
            "load",
            "load <plugin>",
            "load User",
            "Load a plugin",
            "owner"
        ),
        "aka add": new BotCommand(
            "limnoria",
            "aka add",
            "aka add <name> <command>",
            "aka add hi say Hello $nick!",
            "Create command alias",
            "admin"
        ),
    };
    
    static EGGDROP_COMMANDS = {
        "bind": new BotCommand(
            "eggdrop",
            "bind",
            "bind <type> <flags> <keyword> <proc>",
            "bind pub - !hello pub_hello",
            "Bind a command to a Tcl procedure",
            "n/a (script)"
        ),
        "putserv": new BotCommand(
            "eggdrop",
            "putserv",
            "putserv <text>",
            "putserv PRIVMSG #channel :Hello World",
            "Send raw IRC command",
            "n/a (script)"
        ),
        "setudef": new BotCommand(
            "eggdrop",
            "setudef",
            "setudef <type> <name>",
            "setudef str bot_setting",
            "Define user-defined variable",
            "n/a (script)"
        ),
    };
    
    static ALL_COMMANDS = {
        "pbot": IRCBotSyntax.PBOT_COMMANDS,
        "limnoria": IRCBotSyntax.LIMNORIA_COMMANDS,
        "eggdrop": IRCBotSyntax.EGGDROP_COMMANDS,
    };
    
    /**
     * Get command syntax for a specific bot.
     * @param {string} bot 
     * @param {string} command 
     * @returns {BotCommand|null}
     */
    getCommand(bot, command) {
        bot = bot.toLowerCase();
        command = command.toLowerCase();
        
        const botCommands = IRCBotSyntax.ALL_COMMANDS[bot] || {};
        return botCommands[command] || null;
    }
    
    /**
     * List available commands for a bot or all bots.
     * @param {string|null} bot 
     * @returns {Object}
     */
    listCommands(bot = null) {
        if (bot) {
            const commands = IRCBotSyntax.ALL_COMMANDS[bot.toLowerCase()] || {};
            return { [bot]: Object.keys(commands) };
        }
        const result = {};
        for (const [key, value] of Object.entries(IRCBotSyntax.ALL_COMMANDS)) {
            result[key] = Object.keys(value);
        }
        return result;
    }
    
    /**
     * Generate a script template for a bot.
     * @param {string} bot 
     * @param {string} purpose 
     * @returns {string}
     */
    generateScriptTemplate(bot, purpose) {
        const templates = {
            "pbot": `# pbot applet - ${purpose}
# Place in ~/.pbot/applets/

use strict;
use warnings;

sub ${purpose.replace(/\s+/g, '_')} {
    my ($self, $from, $to, $args) = @_;
    
    # Your code here
    return "Result: $args";
}

1;
`,
            "limnoria": `# Limnoria plugin - ${purpose}
# Place in plugins/${purpose.replace(/\s+/g, '')}/

from supybot import utils, plugins, ircutils, callbacks
from supybot.commands import *

class ${purpose.replace(/\s+/g, '').replace(/^\w/, c => c.toUpperCase())}(callbacks.Plugin):
    """${purpose}"""
    
    threaded = True
    
    def ${purpose.replace(/\s+/g, '_')}(self, irc, msg, args):
        """<args>"""
        irc.reply("Hello from ${purpose}!")
    
Class = ${purpose.replace(/\s+/g, '').replace(/^\w/, c => c.toUpperCase())}
`,
            "eggdrop": `# Eggdrop Tcl script - ${purpose}
# Add to eggdrop.conf: source scripts/${purpose.replace(/\s+/g, '_')}.tcl

proc ${purpose.replace(/\s+/g, '_')} {nick uhost hand chan arg} {
    putserv "PRIVMSG $chan :Hello $nick, this is ${purpose}!"
}

bind pub - !${purpose.replace(/\s+/g, '_')} ${purpose.replace(/\s+/g, '_')}
`,
        };
        return templates[bot.toLowerCase()] || "# Unknown bot";
    }
}

function main() {
    const { Command } = require('commander');
    const program = new Command();
    
    program
        .description("IRC Bot command syntax reference")
        .requiredOption('--bot <bot>', 'Bot type', /^(pbot|limnoria|eggdrop)$/i)
        .option('--command <command>', 'Command to look up')
        .option('--list', 'List all commands')
        .option('--template <purpose>', 'Generate script template for purpose')
        .parse();
    
    const options = program.opts();
    const syntax = new IRCBotSyntax();
    
    if (options.list) {
        const commands = syntax.listCommands(options.bot);
        console.log(JSON.stringify(commands, null, 2));
    } else if (options.command) {
        const cmd = syntax.getCommand(options.bot, options.command);
        if (cmd) {
            console.log(`Bot: ${cmd.bot}`);
            console.log(`Command: ${cmd.command}`);
            console.log(`Syntax: ${cmd.syntax}`);
            console.log(`Example: ${cmd.example}`);
            console.log(`Description: ${cmd.description}`);
            if (cmd.permission) {
                console.log(`Permission: ${cmd.permission}`);
            }
        } else {
            console.log(`Command not found: ${options.command}`);
            console.log("Available commands:");
            const cmds = syntax.listCommands(options.bot);
            console.log(JSON.stringify(cmds, null, 2));
        }
    } else if (options.template) {
        const template = syntax.generateScriptTemplate(options.bot, options.template);
        console.log(template);
    }
}

if (require.main === module) {
    main();
}

module.exports = { IRCBotSyntax, BotCommand };
