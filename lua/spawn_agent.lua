#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "faa994b745e0d441a6b37ff9ed031e47a121c12685084a150a396b8616dd47f0", "source_sha256": "a26da3d1befb1a302d385e0a3c85117de3ec06543d5017cf1d706e7f0602be0f", "target_language": "lua"}
-- spawn_agent.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/sub-agents-utils/scripts/spawn_agent.py
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

--[[
Sub-Agent spawner - Einfache CLI für sessions_spawn
]]

local json = require("cjson")
local argparse = require("argparse")

-- Hilfsfunktion zum Lesen von Dateien
local function read_file(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local content = file:read("*a")
    file:close()
    return content
end

-- Lade Modelle aus Konfiguration
local function load_models()
    local config_path = os.getenv("OPENCLAW_CONFIG") or "/home/openclaw/.openclaw/openclaw.json"
    local content = read_file(config_path)
    if not content then
        error("Modellkonfiguration kann nicht geladen werden: " .. config_path .. ": Datei nicht gefunden")
    end
    
    local success, config = pcall(json.decode, content)
    if not success then
        error("Modellkonfiguration kann nicht geladen werden: " .. config_path .. ": " .. config)
    end
    
    local model_config = config.agents.defaults.model
    local candidates = {model_config.primary}
    for _, fallback in ipairs(model_config.fallbacks or {}) do
        table.insert(candidates, fallback)
    end
    
    local models = {}
    local seen = {}
    for _, model in ipairs(candidates) do
        if type(model) == "string" and model ~= "" and not string.match(model, "^anthropic/") and not seen[model] then
            table.insert(models, model)
            seen[model] = true
        end
    end
    
    if #models == 0 then
        error("Keine allgemein verfügbaren Modelle in " .. config_path)
    end
    
    return models
end

local MODELS = load_models()

-- SubAgentSpawner Klasse
local SubAgentSpawner = {}

function SubAgentSpawner.get_spawn_config(task, label, model, thinking, timeout, thread, mode)
    local config = {
        task = task
    }
    
    if label then
        config.label = label
    end
    if model and vim.tbl_contains(MODELS, model) then
        config.model = model
    end
    if thinking then
        config.thinking = thinking
    end
    if timeout then
        config.runTimeoutSeconds = timeout
    end
    if thread then
        config.thread = true
        if mode == "run" then
            config.mode = "session"  -- thread requires session mode
        end
    else
        config.mode = mode
    end
    
    return config
end

function SubAgentSpawner.print_spawn_command(config)
    print("\n🛠️  Tool-Aufruf:")
    print(string.rep("=", 50))
    print("sessions_spawn(")
    for key, value in pairs(config) do
        if type(value) == "string" then
            print(string.format('    %s="%s"', key, value))
        else
            print(string.format('    %s=%s', key, tostring(value)))
        end
    end
    print(")")
    print(string.rep("=", 50))
end

function SubAgentSpawner.print_slash_command(config)
    local task = config.task or ""
    local label = config.label or "agent"
    local model = config.model or ""
    
    local cmd = string.format("/subagents spawn %s \"%s\"", label, task)
    if model ~= "" then
        cmd = cmd .. string.format(" --model %s", model)
    end
    if config.thinking then
        cmd = cmd .. string.format(" --thinking %s", config.thinking)
    end
    
    print("\n💬 Slash Command:")
    print(string.rep("=", 50))
    print(cmd)
    print(string.rep("=", 50))
end

-- Hauptfunktion
local function main()
    local parser = argparse("spawn_agent", "Sub-Agent Spawn Helper")
    parser:help_description_margin(25)
    parser:help_usage_margin(25)
    
    parser:add_argument("--task", "-t")
        :required(true)
        :help("Aufgabenbeschreibung")
    
    parser:add_argument("--label", "-l")
        :help("Optionaler Label")
    
    parser:add_argument("--model", "-m")
        :choices(MODELS)
        :help("KI-Modell")
    
    parser:add_argument("--thinking")
        :choices({"low", "medium", "high"})
        :help("Thinking Level")
    
    parser:add_argument("--timeout")
        :convert(tonumber)
        :default(900)
        :help("Timeout in Sekunden (default: 900)")
    
    parser:add_argument("--thread")
        :flag(true)
        :help("Thread-Binding aktivieren")
    
    parser:add_argument("--mode")
        :choices({"run", "session"})
        :default("run")
        :help("Run mode")
    
    parser:add_argument("--output", "-o")
        :choices({"tool", "slash", "json"})
        :default("tool")
        :help("Output format")
    
    local args = parser:parse()
    
    local config = SubAgentSpawner.get_spawn_config(
        args.task,
        args.label,
        args.model,
        args.thinking,
        args.timeout,
        args.thread,
        args.mode
    )
    
    print("✅ Sub-Agent Konfiguration:")
    print(json.encode(config, true))
    
    if args.output == "tool" then
        SubAgentSpawner.print_spawn_command(config)
    elseif args.output == "slash" then
        SubAgentSpawner.print_slash_command(config)
    elseif args.output == "json" then
        print("\n📄 JSON:")
        print(json.encode(config))
        
        -- Speichere als Datei
        local label = config.label or "spawn"
        local output_file = "/tmp/subagent_" .. label .. ".json"
        local file = io.open(output_file, "w")
        if file then
            file:write(json.encode(config, true))
            file:close()
            print("💾 Gespeichert: " .. output_file)
        end
    end
end

main()
