#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "ef66358da41a6138ffca157ee21f1cf6377397be16bda774016f8eb6fb287ccd", "source_sha256": "e7fd0186c81e698f59895dc87d98d60489bddd55b4ee6f4ba864c23613d06f6b", "target_language": "lua"}
-- irc_bot_syntax.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/irc_bot_syntax.py
-- auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/irc_bot_syntax.py
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

--[[
IRC Bot command syntax for pbot (Perl), Limnoria (Python), and Eggdrop (Tcl).
Fetches syntax from documentation sources.
]]

local json = require("cjson")

local function BotCommand(bot, command, syntax, example, description, permission)
    return {
        bot = bot,
        command = command,
        syntax = syntax,
        example = example,
        description = description,
        permission = permission
    }
end

local IRCBotSyntax = {}
IRCBotSyntax.__index = IRCBotSyntax

function IRCBotSyntax:new()
    local obj = {
        PBOT_COMMANDS = {
            ["keyword add"] = BotCommand(
                "pbot",
                "keyword add",
                "keyword add <keyword> <text>",
                "keyword add hello Hello, World!",
                "Add a keyword trigger",
                "admin"
            ),
            ["fact add"] = BotCommand(
                "pbot",
                "fact add",
                "fact add <channel> <subject> <text>",
                "fact add #channel python Python is a programming language",
                "Add a factoid",
                " whitelisted"
            ),
            ["ban"] = BotCommand(
                "pbot",
                "ban",
                "ban <nick|mask> [duration] [reason]",
                "ban spambot 1h Spamming",
                "Ban a user",
                "op"
            ),
        },
        
        LIMNORIA_COMMANDS = {
            ["config channel"] = BotCommand(
                "limnoria",
                "config channel",
                "config channel <#channel> <plugin>.<variable> <value>",
                "config channel #bot supybot.plugins.Channel.enabled True",
                "Configure channel-specific settings",
                "admin"
            ),
            ["load"] = BotCommand(
                "limnoria",
                "load",
                "load <plugin>",
                "load User",
                "Load a plugin",
                "owner"
            ),
            ["aka add"] = BotCommand(
                "limnoria",
                "aka add",
                "aka add <name> <command>",
                "aka add hi say Hello $nick!",
                "Create command alias",
                "admin"
            ),
        },
        
        EGGDROP_COMMANDS = {
            ["bind"] = BotCommand(
                "eggdrop",
                "bind",
                "bind <type> <flags> <keyword> <proc>",
                "bind pub - !hello pub_hello",
                "Bind a command to a Tcl procedure",
                "n/a (script)"
            ),
            ["putserv"] = BotCommand(
                "eggdrop",
                "putserv",
                "putserv <text>",
                "putserv PRIVMSG #channel :Hello World",
                "Send raw IRC command",
                "n/a (script)"
            ),
            ["setudef"] = BotCommand(
                "eggdrop",
                "setudef",
                "setudef <type> <name>",
                "setudef str bot_setting",
                "Define user-defined variable",
                "n/a (script)"
            ),
        }
    }
    
    obj.ALL_COMMANDS = {
        pbot = obj.PBOT_COMMANDS,
        limnoria = obj.LIMNORIA_COMMANDS,
        eggdrop = obj.EGGDROP_COMMANDS,
    }
    
    setmetatable(obj, IRCBotSyntax)
    return obj
end

function IRCBotSyntax:get_command(bot, command)
    -- Get command syntax for a specific bot
    bot = string.lower(bot)
    command = string.lower(command)
    
    local bot_commands = self.ALL_COMMANDS[bot] or {}
    return bot_commands[command]
end

function IRCBotSyntax:list_commands(bot)
    -- List available commands for a bot or all bots
    if bot then
        local bot_lower = string.lower(bot)
        local commands = self.ALL_COMMANDS[bot_lower] or {}
        local result = {}
        for cmd_name, _ in pairs(commands) do
            table.insert(result, cmd_name)
        end
        return {[bot] = result}
    end
    
    local result = {}
    for bot_name, commands in pairs(self.ALL_COMMANDS) do
        local cmd_list = {}
        for cmd_name, _ in pairs(commands) do
            table.insert(cmd_list, cmd_name)
        end
        result[bot_name] = cmd_list
    end
    return result
end

function IRCBotSyntax:generate_script_template(bot, purpose)
    -- Generate a script template for a bot
    local templates = {
        pbot = function()
            return "# pbot applet - " .. purpose .. "\n" ..
                   "# Place in ~/.pbot/applets/\n\n" ..
                   "use strict;\n" ..
                   "use warnings;\n\n" ..
                   "sub " .. string.gsub(purpose, "%s+", "_") .. " {\n" ..
                   "    my ($self, $from, $to, $args) = @_;\n\n" ..
                   "    # Your code here\n" ..
                   "    return \"Result: $args\";\n" ..
                   "}\n\n" ..
                   "1;\n"
        end,
        
        limnoria = function()
            local class_name = string.gsub(purpose, "%s+", "")
            class_name = class_name:sub(1,1):upper() .. class_name:sub(2)
            
            return "# Limnoria plugin - " .. purpose .. "\n" ..
                   "# Place in plugins/" .. string.gsub(purpose, "%s+", "") .. "/\n\n" ..
                   "from supybot import utils, plugins, ircutils, callbacks\n" ..
                   "from supybot.commands import *\n\n" ..
                   "class " .. class_name .. "(callbacks.Plugin):\n" ..
                   "    \"\"\"" .. purpose .. "\"\"\"\n\n" ..
                   "    threaded = True\n\n" ..
                   "    def " .. string.gsub(purpose, "%s+", "_") .. "(self, irc, msg, args):\n" ..
                   "        \"\"\"<args>\"\"\"\n" ..
                   "        irc.reply(\"Hello from " .. purpose .. "!\")\n\n" ..
                   "Class = " .. class_name .. "\n"
        end,
        
        eggdrop = function()
            local func_name = string.gsub(purpose, "%s+", "_")
            return "# Eggdrop Tcl script - " .. purpose .. "\n" ..
                   "# Add to eggdrop.conf: source scripts/" .. func_name .. ".tcl\n\n" ..
                   "proc " .. func_name .. " {nick uhost hand chan arg} {\n" ..
                   "    putserv \"PRIVMSG $chan :Hello $nick, this is " .. purpose .. "!\"\n" ..
                   "}\n\n" ..
                   "bind pub - !" .. func_name .. " " .. func_name .. "\n"
        end
    }
    
    local template_func = templates[string.lower(bot)]
    if template_func then
        return template_func()
    else
        return "# Unknown bot"
    end
end

local function main()
    local argparse = require("argparse")
    
    local parser = argparse("irc_bot_syntax.lua", "IRC Bot command syntax reference")
    parser:option("--bot", "Bot name"):choices({"pbot", "limnoria", "eggdrop"}):required(true)
    parser:option("--command", "Command to look up")
    parser:flag("--list", "List all commands")
    parser:option("--template", "Generate script template for purpose")
    
    local args = parser:parse()
    
    local syntax = IRCBotSyntax:new()
    
    if args.list then
        local commands = syntax:list_commands(args.bot)
        print(json.encode(commands))
    elseif args.command then
        local cmd = syntax:get_command(args.bot, args.command)
        if cmd then
            print("Bot: " .. cmd.bot)
            print("Command: " .. cmd.command)
            print("Syntax: " .. cmd.syntax)
            print("Example: " .. cmd.example)
            print("Description: " .. cmd.description)
            if cmd.permission then
                print("Permission: " .. cmd.permission)
            end
        else
            print("Command not found: " .. args.command)
            print("Available commands:")
            local cmds = syntax:list_commands(args.bot)
            print(json.encode(cmds, {indent = true}))
        end
    elseif args.template then
        local template = syntax:generate_script_template(args.bot, args.template)
        print(template)
    end
end

if arg[0] == nil or arg[0] == "" then
    main()
end

return IRCBotSyntax
