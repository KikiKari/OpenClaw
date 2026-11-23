#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "3a3c898dbad74c8cab123eb40de9700110873fecf92db66673d4a2d6858a69d8", "source_sha256": "f911bfbdbdc66c53e970ead9851f23e8c415a17f83d92cea3a53539f83a49ad2", "target_language": "lua"}
-- spawn_agent.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway2:skills/sub-agents-utils/scripts/spawn_agent.py
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

--[[
Sub-Agent spawner - Einfache CLI für sessions_spawn
]]

local argparse = require "argparse"
local json = require "cjson"

local WORKSPACE = "/home/openclaw/.openclaw/workspace"

-- Füge WORKSPACE zum Paketpfad hinzu, falls nicht vorhanden
local package_path_added = false
for path in string.gmatch(package.path, "[^;]+") do
    if path:match(WORKSPACE) then
        package_path_added = true
        break
    end
end

if not package_path_added then
    package.path = WORKSPACE .. "/?.lua;" .. package.path
end

-- Lade openclaw_models Modul
local ok, openclaw_models = pcall(require, "openclaw_models")
if not ok then
    error("Modellkonfiguration kann nicht geladen werden: " .. tostring(openclaw_models))
end

-- Verfügbare Modelle
local MODELS = {}
local model_config_status, model_config_result = pcall(openclaw_models.configured_models)
if model_config_status then
    MODELS = model_config_result
else
    error("Modellkonfiguration kann nicht geladen werden: " .. tostring(model_config_result))
end

-- Hilfstabelle für String-Operationen
local function table_contains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- SubAgentSpawner Klasse
local SubAgentSpawner = {}

function SubAgentSpawner.get_spawn_config(task, options)
    options = options or {}
    
    local config = {
        task = task
    }
    
    if options.label then
        config.label = options.label
    end
    
    if options.model and table_contains(MODELS, options.model) then
        config.model = options.model
    end
    
    if options.thinking then
        config.thinking = options.thinking
    end
    
    if options.timeout then
        config.runTimeoutSeconds = options.timeout
    end
    
    if options.thread then
        config.thread = true
        if options.mode == "run" then
            config.mode = "session"  -- thread requires session mode
        end
    else
        config.mode = options.mode or "run"
    end
    
    return config
end

function SubAgentSpawner.print_spawn_command(config)
    print("\n🛠️  Tool-Aufruf:")
    print(string.rep("=", 50))
    print("sessions_spawn(")
    
    local keys = {}
    for k in pairs(config) do
        table.insert(keys, k)
    end
    table.sort(keys)
    
    for _, key in ipairs(keys) do
        local value = config[key]
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
    local parser = argparse.ArgumentParser({
        description = "Sub-Agent Spawn Helper",
        epilog = [[
Beispiele:
  ]] .. arg[0] .. [[ -t "Analyze logs" 
  ]] .. arg[0] .. [[ -t "Code review" -m openrouter/anthropic/claude-haiku-4.5 --timeout 1800
  ]] .. arg[0] .. [[ -t "Batch process" -l "batch-worker" --thread
        ]]
    })
    
    parser:option("-t --task", "Aufgabenbeschreibung"):count(1):required(true)
    parser:option("-l --label", "Optionaler Label")
    parser:option("-m --model", "KI-Modell"):choices(MODELS)
    parser:option("--thinking", "Thinking Level"):choices({"low", "medium", "high"})
    parser:option("--timeout", "Timeout in Sekunden (default: 900)"):default(900):convert(tonumber)
    parser:flag("--thread", "Thread-Binding aktivieren"):action("store_true")
    parser:option("--mode", "Run mode"):choices({"run", "session"}):default("run")
    parser:option("-o --output", "Output format"):choices({"tool", "slash", "json"}):default("tool")
    
    local args = parser:parse()
    
    local config = SubAgentSpawner.get_spawn_config(args.task, {
        label = args.label,
        model = args.model,
        thinking = args.thinking,
        timeout = args.timeout,
        thread = args.thread,
        mode = args.mode
    })
    
    print("✅ Sub-Agent Konfiguration:")
    print(json.encode(config, {indent = true}))
    
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
            file:write(json.encode(config, {indent = true}))
            file:close()
            print("💾 Gespeichert: " .. output_file)
        else
            print("❌ Fehler beim Speichern: " .. output_file)
        end
    end
end

-- Führe Hauptfunktion aus
main()
