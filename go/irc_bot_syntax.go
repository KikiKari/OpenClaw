// abstraction-provenance: {"artifact_sha256": "b1a4a688db35e349ce4d54c123fec9136b97fe50b9f484d5a48dc77c78f3d341", "source_sha256": "e7fd0186c81e698f59895dc87d98d60489bddd55b4ee6f4ba864c23613d06f6b", "target_language": "go"}
// irc_bot_syntax.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/irc_bot_syntax.py
// auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/irc_bot_syntax.py
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

/*
IRC Bot command syntax for pbot (Perl), Limnoria (Python), and Eggdrop (Tcl).
Fetches syntax from documentation sources.
*/

package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"strings"
)

// BotCommand represents an IRC bot command with its metadata
type BotCommand struct {
	Bot         string  `json:"bot"`
	Command     string  `json:"command"`
	Syntax      string  `json:"syntax"`
	Example     string  `json:"example"`
	Description string  `json:"description"`
	Permission  *string `json:"permission,omitempty"`
}

// IRCBotSyntax holds all the bot command definitions
type IRCBotSyntax struct {
	PBOTCommands     map[string]BotCommand
	LIMNORIACommands map[string]BotCommand
	EGGDROPCommands  map[string]BotCommand
	AllCommands      map[string]map[string]BotCommand
}

// NewIRCBotSyntax creates a new instance with all command definitions
func NewIRCBotSyntax() *IRCBotSyntax {
	syntax := &IRCBotSyntax{
		PBOTCommands:     make(map[string]BotCommand),
		LIMNORIACommands: make(map[string]BotCommand),
		EGGDROPCommands:  make(map[string]BotCommand),
	}

	// Initialize pbot commands
	adminPerm := "admin"
	whitelistedPerm := " whitelisted"
	opPerm := "op"
	syntax.PBOTCommands["keyword add"] = BotCommand{
		Bot:         "pbot",
		Command:     "keyword add",
		Syntax:      "keyword add <keyword> <text>",
		Example:     "keyword add hello Hello, World!",
		Description: "Add a keyword trigger",
		Permission:  &adminPerm,
	}
	syntax.PBOTCommands["fact add"] = BotCommand{
		Bot:         "pbot",
		Command:     "fact add",
		Syntax:      "fact add <channel> <subject> <text>",
		Example:     "fact add #channel python Python is a programming language",
		Description: "Add a factoid",
		Permission:  &whitelistedPerm,
	}
	syntax.PBOTCommands["ban"] = BotCommand{
		Bot:         "pbot",
		Command:     "ban",
		Syntax:      "ban <nick|mask> [duration] [reason]",
		Example:     "ban spambot 1h Spamming",
		Description: "Ban a user",
		Permission:  &opPerm,
	}

	// Initialize limnoria commands
	ownerPerm := "owner"
	syntax.LIMNORIACommands["config channel"] = BotCommand{
		Bot:         "limnoria",
		Command:     "config channel",
		Syntax:      "config channel <#channel> <plugin>.<variable> <value>",
		Example:     "config channel #bot supybot.plugins.Channel.enabled True",
		Description: "Configure channel-specific settings",
		Permission:  &adminPerm,
	}
	syntax.LIMNORIACommands["load"] = BotCommand{
		Bot:         "limnoria",
		Command:     "load",
		Syntax:      "load <plugin>",
		Example:     "load User",
		Description: "Load a plugin",
		Permission:  &ownerPerm,
	}
	syntax.LIMNORIACommands["aka add"] = BotCommand{
		Bot:         "limnoria",
		Command:     "aka add",
		Command:     "aka add",
		Syntax:      "aka add <name> <command>",
		Example:     "aka add hi say Hello $nick!",
		Description: "Create command alias",
		Permission:  &adminPerm,
	}

	// Initialize eggdrop commands
	scriptPerm := "n/a (script)"
	syntax.EGGDROPCommands["bind"] = BotCommand{
		Bot:         "eggdrop",
		Command:     "bind",
		Syntax:      "bind <type> <flags> <keyword> <proc>",
		Example:     "bind pub - !hello pub_hello",
		Description: "Bind a command to a Tcl procedure",
		Permission:  &scriptPerm,
	}
	syntax.EGGDROPCommands["putserv"] = BotCommand{
		Bot:         "eggdrop",
		Command:     "putserv",
		Syntax:      "putserv <text>",
		Example:     "putserv PRIVMSG #channel :Hello World",
		Description: "Send raw IRC command",
		Permission:  &scriptPerm,
	}
	syntax.EGGDROPCommands["setudef"] = BotCommand{
		Bot:         "eggdrop",
		Command:     "setudef",
		Syntax:      "setudef <type> <name>",
		Example:     "setudef str bot_setting",
		Description: "Define user-defined variable",
		Permission:  &scriptPerm,
	}

	// Build all commands map
	syntax.AllCommands = map[string]map[string]BotCommand{
		"pbot":      syntax.PBOTCommands,
		"limnoria":  syntax.LIMNORIACommands,
		"eggdrop":   syntax.EGGDROPCommands,
	}

	return syntax
}

// GetCommand gets command syntax for a specific bot
func (ibs *IRCBotSyntax) GetCommand(bot string, command string) (*BotCommand, bool) {
	bot = strings.ToLower(bot)
	command = strings.ToLower(command)

	botCommands, exists := ibs.AllCommands[bot]
	if !exists {
		return nil, false
	}

	cmd, found := botCommands[command]
	if found {
		return &cmd, true
	}
	return nil, false
}

// ListCommands lists available commands for a bot or all bots
func (ibs *IRCBotSyntax) ListCommands(bot string) map[string][]string {
	if bot != "" {
		bot = strings.ToLower(bot)
		if commands, exists := ibs.AllCommands[bot]; exists {
			keys := make([]string, 0, len(commands))
			for k := range commands {
				keys = append(keys, k)
			}
			return map[string][]string{bot: keys}
		}
		return map[string][]string{bot: {}}
	}

	result := make(map[string][]string)
	for botName, commands := range ibs.AllCommands {
		keys := make([]string, 0, len(commands))
		for k := range commands {
			keys = append(keys, k)
		}
		result[botName] = keys
	}
	return result
}

// GenerateScriptTemplate generates a script template for a bot
func (ibs *IRCBotSyntax) GenerateScriptTemplate(bot string, purpose string) string {
	bot = strings.ToLower(bot)
	
	switch bot {
	case "pbot":
		template := fmt.Sprintf(`# pbot applet - %s
# Place in ~/.pbot/applets/

use strict;
use warnings;

sub %s {
    my ($self, $from, $to, $args) = @_;
    
    # Your code here
    return "Result: $args";
}

1;
`, purpose, strings.ReplaceAll(purpose, " ", "_"))
		return template
		
	case "limnoria":
		cleanPurpose := strings.ReplaceAll(purpose, " ", "")
		titlePurpose := strings.Title(cleanPurpose)
		template := fmt.Sprintf(`# Limnoria plugin - %s
# Place in plugins/%s/

from supybot import utils, plugins, ircutils, callbacks
from supybot.commands import *

class %s(callbacks.Plugin):
    """%s"""
    
    threaded = True
    
    def %s(self, irc, msg, args):
        """<args>"""
        irc.reply("Hello from %s!")
    
Class = %s
`, purpose, cleanPurpose, titlePurpose, purpose, strings.ReplaceAll(purpose, " ", "_"), purpose, titlePurpose)
		return template
		
	case "eggdrop":
		template := fmt.Sprintf(`# Eggdrop Tcl script - %s
# Add to eggdrop.conf: source scripts/%s.tcl

proc %s {nick uhost hand chan arg} {
    putserv "PRIVMSG $chan :Hello $nick, this is %s!"
}

bind pub - !%s %s
`, purpose, strings.ReplaceAll(purpose, " ", "_"), strings.ReplaceAll(purpose, " ", "_"), purpose, strings.ReplaceAll(purpose, " ", "_"), strings.ReplaceAll(purpose, " ", "_"))
		return template
		
	default:
		return "# Unknown bot"
	}
}

func main() {
	var bot, command, template string
	var list bool

	flag.StringVar(&bot, "bot", "", "Bot type (pbot, limnoria, eggdrop)")
	flag.StringVar(&command, "command", "", "Command to look up")
	flag.BoolVar(&list, "list", false, "List all commands")
	flag.StringVar(&template, "template", "", "Generate script template for purpose")
	flag.Parse()

	if bot == "" {
		fmt.Println("Error: --bot is required")
		return
	}

	syntax := NewIRCBotSyntax()

	if list {
		commands := syntax.ListCommands(bot)
		jsonData, _ := json.MarshalIndent(commands, "", "  ")
		fmt.Println(string(jsonData))
	} else if command != "" {
		cmd, found := syntax.GetCommand(bot, command)
		if found {
			fmt.Printf("Bot: %s\n", cmd.Bot)
			fmt.Printf("Command: %s\n", cmd.Command)
			fmt.Printf("Syntax: %s\n", cmd.Syntax)
			fmt.Printf("Example: %s\n", cmd.Example)
			fmt.Printf("Description: %s\n", cmd.Description)
			if cmd.Permission != nil {
				fmt.Printf("Permission: %s\n", *cmd.Permission)
			}
		} else {
			fmt.Printf("Command not found: %s\n", command)
			fmt.Println("Available commands:")
			cmds := syntax.ListCommands(bot)
			jsonData, _ := json.MarshalIndent(cmds, "", "  ")
			fmt.Println(string(jsonData))
		}
	} else if template != "" {
		tmpl := syntax.GenerateScriptTemplate(bot, template)
		fmt.Println(tmpl)
	}
}
