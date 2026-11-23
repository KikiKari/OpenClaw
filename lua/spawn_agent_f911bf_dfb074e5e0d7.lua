#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "1e9d5d98741c93dae2f4e1266fde096293f7413bc6895305c5d9c91c80ee8176", "source_sha256": "f911bfbdbdc66c53e970ead9851f23e8c415a17f83d92cea3a53539f83a49ad2", "target_language": "lua"}
-- spawn_agent.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway2:skills/sub-agents-utils/scripts/spawn_agent.py
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

--[[
Sub-Agent spawner - Einfache CLI für sessions_spawn
]]

local argparse = require "argparse"
local json = require "cjson"

-- Hilfsfunktion zur Pfadverwaltung
local function script_path()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)") or "./"
end

-- WORKSPACE-Pfad (angepasst an Lua)
local WORKSPACE = "/home/openclaw/.openclaw/workspace"

-- Dummy-Funktion für Modelle (da Lua keine direkte Entsprechung zu Python-Modulen hat)
-- In einer echten Implementierung würde hier die Modellkonfiguration geladen
local function configured_models()
    -- Beispielhafte Liste von Modellen
    return {
        ["openrouter/anthropic/claude-haiku-4.5"] = true,
        ["openrouter/google/gemini-pro"] = true,
        ["together/mistralai/Mixtral-8x7B-Instruct-v0.1"] = true
    }
end

local MODELS = configured_models()

-- SubAgentSpawner Klasse
local SubAgentSpawner = {}

function SubAgentSpawner.get_spawn_config(task, label, model, thinking, timeout, thread, mode)
    local config = {
        task = task
    }

    if label then
        config.label = label
    end
    if model and MODELS[model] then
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
    local parser = argparse.ArgumentParser({
        description = "Sub-Agent Spawn Helper",
        epilog = [[
Beispiele:
  ]] .. arg[0] .. [[ -t "Analyze logs" 
  ]] .. arg[0] .. [[ -t "Code review" -m openrouter/anthropic/claude-haiku-4.5 --timeout 1800
  ]] .. arg[0] .. [[ -t "Batch process" -l "batch-worker" --thread
        ]]
    })

    parser:add_argument("--task", "-t"):required(true):help("Aufgabenbeschreibung")
    parser:add_argument("--label", "-l"):help("Optionaler Label")
    parser:add_argument("--model", "-m"):choices(MODELS):help("KI-Modell")
    parser:add_argument("--thinking"):choices({"low", "medium", "high"}):help("Thinking Level")
    parser:add_argument("--timeout"):type("integer"):default(900):help("Timeout in Sekunden (default: 900)")
    parser:add_argument("--thread"):flag(true):help("Thread-Binding aktivieren")
    parser:add_argument("--mode"):choices({"run", "session"}):default("run"):help("Run mode")
    parser:add_argument("--output", "-o"):choices({"tool", "slash", "json"}):default("tool"):help("Output format")

    local args = parser:parse_args()

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
    print(json.encode_pretty(config))

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
            file:write(json.encode_pretty(config))
            file:close()
            print("💾 Gespeichert: " .. output_file)
        else
            print("❌ Fehler beim Speichern der Datei: " .. output_file)
        end
    end
end

main()
