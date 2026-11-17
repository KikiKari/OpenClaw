// abstraction-provenance: {"artifact_sha256": "520675686b3612f19e2ec7bebd9b1b0ffbb69fbcd8dcb4220529ddf082a428a5", "source_sha256": "e7fd0186c81e698f59895dc87d98d60489bddd55b4ee6f4ba864c23613d06f6b", "target_language": "go"}
// irc_bot_syntax.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/irc_bot_syntax.py
// auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/irc_bot_syntax.py
// Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"
)

// BotCommand represents a bot command with its metadata
type BotCommand struct {
	Bot         string  `json:"bot"`
	Command     string  `json:"command"`
	Syntax      string  `json:"syntax"`
	Example     string  `json:"example"`
	Description string  `json:"description"`
	Permission  *string `json:"permission,omitempty"`
}

// IRCBotSyntax holds all bot command definitions
type IRCBotSyntax struct {
	PBotCommands     map[string]BotCommand
	LimnoriaCommands map[string]BotCommand
	EggdropCommands  map[string]BotCommand
	AllCommands      map[string]map[string]BotCommand
}

// NewIRCBotSyntax creates a new instance with all command definitions
func NewIRCBotSyntax() *IRCBotSyntax {
	s := &IRCBotSyntax{}
	
	// Initialize maps
	s.PBotCommands = make(map[string]BotCommand)
	s.LimnoriaCommands = make(map[string]BotCommand)
	s.EggdropCommands = make(map[string]BotCommand)
	
	// pbot commands
	adminPerm := "admin"
	whitelistedPerm := " whitelisted"
	opPerm := "op"
	s.PBotCommands["keyword add"] = BotCommand{
		Bot:         "pbot",
		Command:     "keyword add",
		Syntax:      "keyword add <keyword> <text>",
		Example:     "keyword add hello Hello, World!",
		Description: "Add a keyword trigger",
		Permission:  &adminPerm,
	}
	s.PBotCommands["fact add"] = BotCommand{
		Bot:         "pbot",
		Command:     "fact add",
		Syntax:      "fact add <channel> <subject> <text>",
		Example:     "fact add #channel python Python is a programming language",
		Description: "Add a factoid",
		Permission:  &whitelistedPerm,
	}
	s.PBotCommands["ban"] = BotCommand{
		Bot:         "pbot",
		Command:     "ban",
		Syntax:      "ban <nick|mask> [duration] [reason]",
		Example:     "ban spambot 1h Spamming",
		Description: "Ban a user",
		Permission:  &opPerm,
	}
	
	// Limnoria commands
	adminPerm2 := "admin"
	ownerPerm := "owner"
	s.LimnoriaCommands["config channel"] = BotCommand{
		Bot:         "limnoria",
		Command:     "config channel",
		Syntax:      "config channel <#channel> <plugin>.<variable> <value>",
		Example:     "config channel #bot supybot.plugins.Channel.enabled True",
		Description: "Configure channel-specific settings",
		Permission:  &adminPerm2,
	}
	s.LimnoriaCommands["load"] = BotCommand{
		Bot:         "limnoria",
		Command:     "load",
		Syntax:      "load <plugin>",
		Example:     "load User",
		Description: "Load a plugin",
		Permission:  &ownerPerm,
	}
	s.LimnoriaCommands["aka add"] = BotCommand{
		Bot:         "limnoria",
		Command:     "aka add",
		Syntax:      "aka add <name> <command>",
		Example:     "aka add hi say Hello $nick!",
		Description: "Create command alias",
		Permission:  &adminPerm2,
	}
	
	// Eggdrop commands
	scriptPerm := "n/a (script)"
	s.EggdropCommands["bind"] = BotCommand{
		Bot:         "eggdrop",
		Command:     "bind",
		Syntax:      "bind <type> <flags> <keyword> <proc>",
		Example:     "bind pub - !hello pub_hello",
		Description: "Bind a command to a Tcl procedure",
		Permission:  &scriptPerm,
	}
	s.EggdropCommands["putserv"] = BotCommand{
		Bot:         "eggdrop",
		Command:     "putserv",
		Syntax:      "putserv <text>",
		Example:     "putserv PRIVMSG #channel :Hello World",
		Description: "Send raw IRC command",
		Permission:  &scriptPerm,
	}
	s.EggdropCommands["setudef"] = BotCommand{
		Bot:         "eggdrop",
		Command:     "setudef",
		Syntax:      "setudef <type> <name>",
		Example:     "setudef str bot_setting",
		Description: "Define user-defined variable",
		Permission:  &scriptPerm,
	}
	
	// All commands mapping
	s.AllCommands = map[string]map[string]BotCommand{
		"pbot":      s.PBotCommands,
		"limnoria":  s.LimnoriaCommands,
		"eggdrop":   s.EggdropCommands,
	}
	
	return s
}

// GetCommand retrieves a command for a specific bot
func (s *IRCBotSyntax) GetCommand(bot, command string) (*BotCommand, bool) {
	bot = strings.ToLower(bot)
	command = strings.ToLower()
	
	if botCommands, exists := s.AllCommands[bot]; exists {
		if cmd, found := botCommands[command]; found {
			return &cmd, true
		}
	}
	return nil, false
}

// ListCommands returns available commands for a bot or all bots
func (s *IRCBotSyntax) ListCommands(bot string) map[string][]string {
	if bot != "" {
		result := make(map[string][]string)
		if commands, exists := s.AllCommands[strings.ToLower(bot)]; exists {
			keys := make([]string, 0, len(commands))
			for k := range commands {
				keys = append(keys, k)
			}
			result[bot] = keys
			return result
		}
		return result
	}
	
	result := make(map[string][]string)
	for k, v := range s.AllCommands {
		keys := make([]string, 0, len(v))
		for key := range v {
			keys = append(keys, key)
		}
		result[k] = keys
	}
	return result
}

// GenerateScriptTemplate generates a script template for a bot
func (s *IRCBotSyntax) GenerateScriptTemplate(bot, purpose string) string {
	switch strings.ToLower(bot) {
	case "pbot":
		return fmt.Sprintf(`# pbot applet - %s
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
		
	case "limnoria":
		titleCase := strings.Title(strings.ReplaceAll(purpose, " ", ""))
		return fmt.Sprintf(`# Limnoria plugin - %s
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
`, purpose, strings.ReplaceAll(purpose, " ", ""), titleCase, purpose, 
   strings.ReplaceAll(purpose, " ", "_"), purpose, titleCase)
		
	case "eggdrop":
		underscorePurpose := strings.ReplaceAll(purpose, " ", "_")
		return fmt.Sprintf(`# Eggdrop Tcl script - %s
# Add to eggdrop.conf: source scripts/%s.tcl

proc %s {nick uhost hand chan arg} {
    putserv "PRIVMSG $chan :Hello $nick, this is %s!"
}

bind pub - !%s %s
`, purpose, underscorePurpose, underscorePurpose, purpose, underscorePurpose, underscorePurpose)
		
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
		os.Exit(1)
	}
	
	validBots := map[string]bool{"pbot": true, "limnoria": true, "eggdrop": true}
	if !validBots[strings.ToLower(bot)] {
		fmt.Printf("Error: Invalid bot '%s'. Valid options: pbot, limnoria, eggdrop\n", bot)
		os.Exit(1)
	}
	
	syntax := NewIRCBotSyntax()
	
	if list {
		commands := syntax.ListCommands(bot)
		jsonData, _ := json.MarshalIndent(commands, "", "  ")
		fmt.Println(string(jsonData))
	} else if command != "" {
		cmd, found := syntax.GetCommand(bot, command)
		if found && cmd != nil {
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
	} else {
		fmt.Println("Error: Either --list, --command, or --template must be specified")
		os.Exit(1)
	}
}
