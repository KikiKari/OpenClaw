#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "389e86847093bdc275e84f7c76b87234555539ee6e127165688e0326ead212dc", "source_sha256": "bb3a3622a1b49888ef51f2b6fac687955ed97e97b6ee7a16d4e47117a764be29", "target_language": "lua"}
-- agent_runner.py — portiert nach lua
-- Quelle: python, workspace@local:skills/sub-agents-utils/scripts/agent_runner.py
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

--[[Run a gateway-only OpenClaw agent turn for a porting task.]]

local json = require("cjson")
local uuid = require("uuid")

-- Generate a random UUID
function generate_uuid()
    math.randomseed(os.time())
    return uuid()
end

-- Read and parse JSON config file
function allowed_models(config_path)
    local file = io.open(config_path, "r")
    if not file then
        return {}
    end
    local content = file:read("*a")
    file:close()
    
    local status, config = pcall(json.decode, content)
    if not status then
        return {}
    end
    
    local models = {}
    local agents = config.agents or {}
    local defaults = agents.defaults or {}
    
    -- Add models from defaults.models
    if defaults.models then
        for _, model in ipairs(defaults.models) do
            models[model] = true
        end
    end
    
    -- Handle defaults.model (string or table)
    local selected = defaults.model
    if type(selected) == "string" then
        models[selected] = true
    elseif type(selected) == "table" then
        if selected.primary then
            models[selected.primary] = true
        end
        if selected.fallbacks then
            for _, fallback in ipairs(selected.fallbacks) do
                if type(fallback) == "string" then
                    models[fallback] = true
                end
            end
        end
    end
    
    return models
end

-- Run the agent with given parameters
function run(task, model, timeout)
    if not task or #task == 0 or #task > 500 then
        error("task must contain 1–500 characters")
    end
    if not timeout or timeout < 1 or timeout > 7200 then
        error("timeout must be between 1 and 7200 seconds")
    end
    
    local config_path = os.getenv("OPENCLAW_CONFIG") or (os.getenv("HOME") .. "/.openclaw/openclaw.json")
    local allowed = allowed_models(config_path)
    if not allowed[model] then
        error("model is not in the configured OpenClaw model allowlist")
    end
    
    local provider, model_id = model:match("^([^/]+)/(.+)$")
    if not provider or not model_id then
        error("model must have provider/model form")
    end
    
    local run_id = generate_uuid()
    local params = {
        message = task:match("^%s*(.-)%s*$"),
        provider = provider,
        model = model_id,
        sessionKey = "agent:main:abstraction-runner:" .. run_id,
        idempotencyKey = run_id,
        timeout = timeout,
        deliver = false
    }
    
    local cmd = "openclaw gateway call agent --params '" .. json.encode(params) .. "' --expect-final --json --timeout " .. ((timeout + 10) * 1000)
    
    local handle = io.popen(cmd .. " 2>&1", "r")
    if not handle then
        error("Failed to execute openclaw command")
    end
    
    local output = handle:read("*a")
    local success, _, exit_code = handle:close()
    
    if not success then
        io.stderr:write(output or "OpenClaw agent call failed\n")
        return exit_code or 1
    end
    
    local status, response = pcall(json.decode, output)
    if not status then
        error("OpenClaw returned invalid JSON")
    end
    
    if type(response) ~= "table" or response.status ~= "ok" then
        error("OpenClaw did not return a completed agent result")
    end
    
    local agent_result = response.result
    if type(agent_result) ~= "table" then
        error("OpenClaw returned no agent result")
    end
    
    local meta = agent_result.meta or {}
    if type(meta) ~= "table" or meta.aborted or meta.error then
        error("OpenClaw agent execution did not complete successfully")
    end
    
    local payloads = agent_result.payloads or {}
    if type(payloads) ~= "table" then
        error("OpenClaw agent returned an error")
    end
    
    for _, item in ipairs(payloads) do
        if type(item) ~= "table" or item.isError then
            error("OpenClaw agent returned an error")
        end
    end
    
    local has_text = false
    for _, item in ipairs(payloads) do
        if type(item.text) == "string" and item.text:match("%S") then
            has_text = true
            break
        end
    end
    
    if not has_text then
        error("OpenClaw agent returned no text")
    end
    
    print(json.encode(response))
    return 0
end

-- Main function
function main()
    local args = {}
    for i = 1, #arg do
        if arg[i] == "--task" and i + 1 <= #arg then
            args.task = arg[i + 1]
        elseif arg[i] == "--model" and i + 1 <= #arg then
            args.model = arg[i + 1]
        elseif arg[i] == "--timeout" and i + 1 <= #arg then
            args.timeout = tonumber(arg[i + 1])
        elseif arg[i] == "--gateway-only" then
            args.gateway_only = true
        end
    end
    
    if not args.gateway_only then
        io.stderr:write("agent_runner: no worker/relay transport configured; gateway-only requires --gateway-only\n")
        return 1
    end
    
    if not args.task or not args.model then
        io.stderr:write("Missing required arguments: --task and --model are required\n")
        return 1
    end
    
    args.timeout = args.timeout or 1800
    
    local status, result = pcall(run, args.task, args.model, args.timeout)
    if not status then
        io.stderr:write("agent_runner: " .. tostring(result) .. "\n")
        return 1
    end
    
    return result
end

os.exit(main())
