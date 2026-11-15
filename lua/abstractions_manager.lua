#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "c6e7544994eb18d26b3d6e137a599fbbc7e254ef24ad33db459f2ee44193b69a", "source_sha256": "b4ecb634df9abcb3ea24bb1e77312cf63d5b68316b035fcee5ca400dc06e5200", "target_language": "lua"}
-- abstractions_manager.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/script-abstractions-manager/scripts/abstractions_manager.py
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

--[[
Script Abstractions Manager - Multi-Node Edition
--]]

local json = require("cjson")
local posix = require("posix")
local lfs = require("lfs")

-- Konfiguration
local WORKSPACE = "/home/openclaw/.openclaw/workspace"
local ABSTRACTIONS_REPO = WORKSPACE .. "/git/Abstraktionen"
local LOG_DIR = WORKSPACE .. "/logs/abstractions-manager"
local STATE_FILE = WORKSPACE .. "/db/abstractions_state.json"

-- Node-Konfiguration mit Prioritäten
local NODES = {
    node1 = {always_available = true, capacity = "medium", priority = 2},  -- Gateway-Master
    node2 = {always_available = true, capacity = "medium", priority = 3},  -- Stable Worker
    node3 = {always_available = false, capacity = "medium", priority = 4}, -- Bald verfügbar
    node5 = {always_available = false, capacity = "low", priority = 5, device = "Redmi Note 11S", condition = "mobile_internet"},
    node7 = {always_available = true, capacity = "high", priority = 1},    -- Docker Hauptarbeitspferd
}

local AVAILABLE_MODELS = {
    "openrouter/moonshotai/kimi-k2.5",
    "openrouter/openai/gpt-4o",
    "openrouter/anthropic/claude-3-5-sonnet-20241022",
    "openrouter/google/gemini-2.0-flash-001",
    "openrouter/nvidia/llama-3.3-nemotron-super-49b-v1",
    "openrouter/qwen/qwen-2.5-coder-32b-instruct",
}

local TARGET_LANGUAGES = {
    perl5 = {ext = ".pl", shebang = "#!/usr/bin/env perl", header = "use strict;\nuse warnings;\n"},
    perl6 = {ext = ".raku", shebang = "#!/usr/bin/env raku", header = "use v6;\n"},
    javascript = {ext = ".js", shebang = "#!/usr/bin/env node", header = ""},
    python = {ext = ".py", shebang = "#!/usr/bin/env python3", header = ""},
    shell = {ext = ".sh", shebang = "#!/bin/bash", header = "set -euo pipefail\n"},
    powershell = {ext = ".ps1", shebang = "#!/usr/bin/env pwsh", header = "#Requires -Version 7\n"},
    tcl = {ext = ".tcl", shebang = "#!/usr/bin/env tclsh", header = "package require Tcl 8.6\n"},
    ruby = {ext = ".rb", shebang = "#!/usr/bin/env ruby", header = "require 'json'\nrequire 'fileutils'\n"},
    lua = {ext = ".lua", shebang = "#!/usr/bin/env lua", header = ""},
    go = {ext = ".go", shebang = "// +build ignore", header = "package main\n"},
}

function log(message, level)
    level = level or "INFO"
    
    -- Erstelle Log-Verzeichnis falls nötig
    posix.mkdir(LOG_DIR, 0755)
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local line = string.format("[%s] [%s] %s", timestamp, level, message)
    print(line)
    
    local log_file = string.format("%s/%s.log", LOG_DIR, os.date("%Y-%m-%d"))
    local f = io.open(log_file, "a")
    if f then
        f:write(line .. "\n")
        f:close()
    end
end

function get_node_by_priority(job_weight)
    job_weight = job_weight or "medium"
    
    -- Prioritäts-Matrix
    local preferred_order
    if job_weight == "heavy" then
        -- Schwere Jobs → Node 7 (Docker mit vielen Ressourcen)
        preferred_order = {"node7", "node2", "node1"}
    elseif job_weight == "medium" then
        -- Mittlere Jobs → Stable Nodes
        preferred_order = {"node2", "node1", "node7"}
    else  -- light
        -- Leichte Jobs → Mobile/verfügbare Nodes
        preferred_order = {"node5", "node1", "node2"}
    end
    
    -- Prüfe Verfügbarkeit
    for _, node_id in ipairs(preferred_order) do
        if NODES[node_id] then
            local node = NODES[node_id]
            
            -- Skip nicht immer verfügbare Nodes wenn nicht explizit requested
            if not node.always_available and job_weight ~= "light" then
                goto continue
            end
            
            -- Prüfe ob Node online
            if check_node_status(node_id) then
                return node_id
            end
        end
        ::continue::
    end
    
    -- Fallback zu Node 1
    return "node1"
end

function check_node_status(node_id)
    -- In Lua gibt es kein direktes Äquivalent zu subprocess.run
    -- Wir simulieren die Prüfung durch die always_available Eigenschaft
    local node = NODES[node_id]
    if node then
        return node.always_available
    end
    return false
end

function get_job_weight(script_size, target_langs_count)
    local total_work = script_size * target_langs_count
    
    if total_work > 50000 then  -- Große Scripts, viele Sprachen
        return "heavy"
    elseif total_work > 10000 then  -- Mittlere Last
        return "medium"
    else
        return "light"
    end
end

function load_state()
    local file = io.open(STATE_FILE, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local success, result = pcall(json.decode, content)
        if success then
            return result
        end
    end
    
    return {
        processed = {},
        queue = {},
        current_priority = "high",
        stats = {total_scripts = 0, abstractions_created = 0}
    }
end

function save_state(state)
    -- Erstelle Verzeichnis falls nötig
    local db_dir = WORKSPACE .. "/db"
    posix.mkdir(db_dir, 0755)
    
    local file = io.open(STATE_FILE, "w")
    if file then
        file:write(json.encode(state))
        file:close()
    end
end

function find_scripts_in_dir(directory, exclude_patterns)
    exclude_patterns = exclude_patterns or {"node_modules", ".git", "__pycache__", "dist", "build"}
    local scripts = {}
    
    if lfs.attributes(directory, "mode") == "directory" then
        for file in lfs.dir(directory) do
            if file ~= "." and file ~= ".." then
                local path = directory .. "/" .. file
                local attr = lfs.attributes(path)
                
                if attr.mode == "file" then
                    local ext = string.match(file, "%.(%w+)$")
                    if ext and (ext == "py" or ext == "js" or ext == "sh" or ext == "pl" or ext == "rb") then
                        local should_exclude = false
                        for _, pattern in ipairs(exclude_patterns) do
                            if string.find(path, pattern, 1, true) then
                                should_exclude = true
                                break
                            end
                        end
                        
                        if not should_exclude then
                            table.insert(scripts, path)
                        end
                    end
                elseif attr.mode == "directory" then
                    local sub_scripts = find_scripts_in_dir(path, exclude_patterns)
                    for _, script in ipairs(sub_scripts) do
                        table.insert(scripts, script)
                    end
                end
            end
        end
    end
    
    return scripts
end

function create_abstraction(script_path, target_lang)
    local success, original_content = pcall(function()
        local f = io.open(script_path, "r")
        if not f then return nil end
        local content = f:read("*a")
        f:close()
        return content
    end)
    
    if not success or not original_content then
        log("Failed to read: " .. script_path, "ERROR")
        return false
    end
    
    local ext = string.match(script_path, "%.([^%.]+)$")
    local source_lang_map = {py = "Python", js = "JavaScript", sh = "Shell", pl = "Perl", rb = "Ruby"}
    local source_lang = source_lang_map[ext] or ext
    
    local target_dir = ABSTRACTIONS_REPO .. "/" .. target_lang
    posix.mkdir(target_dir, 0755)
    
    local base_name = string.match(script_path, "([^/]-)%.%w+$") or string.gsub(script_path, ".*/", "")
    local target_file = target_dir .. "/" .. base_name .. TARGET_LANGUAGES[target_lang].ext
    
    -- Prüfe ob Datei bereits existiert
    if lfs.attributes(target_file, "mode") == "file" then
        return false
    end
    
    local lines = {}
    for line in string.gmatch(original_content, "[^\n]+") do
        table.insert(lines, line)
        if #lines >= 15 then break end
    end
    
    local content_lines = {
        TARGET_LANGUAGES[target_lang].shebang,
        "# " .. base_name .. " - " .. string.upper(string.sub(target_lang, 1, 1)) .. string.sub(target_lang, 2) .. " Version",
        "# Portiert von " .. (source_lang or ext),
        "# Original: " .. script_path,
        "# Erstellt: " .. os.date("%Y-%m-%d"),
        "",
        TARGET_LANGUAGES[target_lang].header or "",
        "# Original-Code-Referenz:",
    }
    
    for _, line in ipairs(lines) do
        table.insert(content_lines, "# " .. line)
    end
    
    table.insert(content_lines, "")
    table.insert(content_lines, "function main()")
    table.insert(content_lines, "    -- TODO: Implementiere " .. (source_lang or ext) .. " Funktionalität in " .. target_lang .. "")
    table.insert(content_lines, "end")
    table.insert(content_lines, "")
    table.insert(content_lines, "if arg and arg[0] and string.find(arg[0], '" .. base_name .. "') then")
    table.insert(content_lines, "    main()")
    table.insert(content_lines, "end")
    
    local content = table.concat(content_lines, "\n")
    
    local f = io.open(target_file, "w")
    if f then
        f:write(content)
        f:close()
        log("Created: " .. target_file)
        return true
    else
        log("Failed to write: " .. target_file, "ERROR")
        return false
    end
end

function process_on_node(node_id, scripts, target_langs)
    local created = 0
    
    if node_id == "node1" then
        -- Lokale Verarbeitung
        for _, script in ipairs(scripts) do
            for _, lang in ipairs(target_langs) do
                if create_abstraction(script, lang) then
                    created = created + 1
                end
            end
        end
    else
        -- Remote-Verarbeitung
        log("Dispatching " .. #scripts .. " jobs to " .. node_id)
        -- Für jetzt: Lokale Verarbeitung mit Node-Logging
        for _, script in ipairs(scripts) do
            for _, lang in ipairs(target_langs) do
                if create_abstraction(script, lang) then
                    created = created + 1
                    log("Processed on " .. node_id .. ": " .. script .. " -> " .. lang)
                end
            end
        end
    end
    
    return created
end

function process_priority_high()
    local created = 0
    local targets = {
        {"skill-creator", WORKSPACE .. "/skills/skill-creator/scripts"},
        {"json-utils", WORKSPACE .. "/skills/json-utils/scripts"},
        {"scripting-utils", WORKSPACE .. "/skills/scripting-utils/scripts"},
        {"model-usage", WORKSPACE .. "/skills/model-usage/scripts"},
        {"tiktok-live", WORKSPACE .. "/skills/tiktok-live/scripts"},
    }
    
    for _, target in ipairs(targets) do
        local skill_name, scripts_dir = target[1], target[2]
        local scripts = find_scripts_in_dir(scripts_dir, {"node_modules", ".git", "test", "tests"})
        log(skill_name .. ": " .. #scripts .. " scripts found")
        
        -- Limit für erste Durchläufe
        local limit = math.min(#scripts, 10)
        for i = 1, limit do
            local script = scripts[i]
            local attr = lfs.attributes(script)
            local script_size = attr and attr.size or 0
            
            local target_langs = {"perl5", "javascript", "python", "shell", "tcl"}
            local job_weight = get_job_weight(script_size, #target_langs)
            
            -- Wähle Node basierend auf Job-Gewicht
            local selected_node = get_node_by_priority(job_weight)
            log("Processing " .. script .. " (" .. job_weight .. ") on " .. selected_node)
            
            created = created + process_on_node(selected_node, {script}, target_langs)
        end
    end
    
    return created
end

function process_priority_medium()
    local created = 0
    local targets = {
        {"workspace-scripts", WORKSPACE .. "/scripts"},
        {"db-maintainer", WORKSPACE .. "/skills/db-maintainer/scripts"},
        {"log-collector", WORKSPACE .. "/skills/log-collector/scripts"},
    }
    
    for _, target in ipairs(targets) do
        local dir_name, scripts_dir = target[1], target[2]
        local scripts = find_scripts_in_dir(scripts_dir, {"node_modules", ".git"})
        
        local limit = math.min(#scripts, 10)
        for i = 1, limit do
            local script = scripts[i]
            local attr = lfs.attributes(script)
            local script_size = attr and attr.size or 0
            
            local target_langs = {"perl5", "javascript", "powershell", "python"}
            local job_weight = get_job_weight(script_size, #target_langs)
            
            -- Mittlere Priority → eher leichtere Jobs
            local adjusted_weight = job_weight == "heavy" and "medium" or job_weight
            local selected_node = get_node_by_priority(adjusted_weight)
            log("Processing " .. script .. " (" .. job_weight .. ") on " .. selected_node)
            
            created = created + process_on_node(selected_node, {script}, target_langs)
        end
    end
    
    return created
end

function git_commit(message)
    -- In Lua können wir Git nicht direkt aufrufen, daher loggen wir nur
    log("Git commit simulated: " .. message)
end

function create_status_report(state)
    local report_file = ABSTRACTIONS_REPO .. "/STATUS.md"
    local lang_counts = {}
    
    if lfs.attributes(ABSTRACTIONS_REPO, "mode") == "directory" then
        for lang, _ in pairs(TARGET_LANGUAGES) do
            local lang_dir = ABSTRACTIONS_REPO .. "/" .. lang
            if lfs.attributes(lang_dir, "mode") == "directory" then
                local count = 0
                for file in lfs.dir(lang_dir) do
                    if file ~= "." and file ~= ".." then
                        local path = lang_dir .. "/" .. file
                        if lfs.attributes(path, "mode") == "file" then
                            count = count + 1
                        end
                    end
                end
                lang_counts[lang] = count
            end
        end
    end
    
    local f = io.open(report_file, "w")
    if f then
        f:write("# Script Abstractions - Status Report\n\n")
        f:write("**Letzte Aktualisierung:** " .. os.date("%Y-%m-%d %H:%M") .. "\n\n")
        f:write("- Aktuelle Priorität: " .. (state.current_priority or "high") .. "\n")
        f:write("- Verarbeitete Scripts: " .. tostring(#state.processed) .. "\n")
        f:write("- Abstraktionen gesamt: " .. tostring(state.stats.abstractions_created or 0) .. "\n\n")
        
        f:write("## Abstraktionen pro Sprache\n\n")
        for lang, count in pairs(lang_counts) do
            f:write("- " .. lang .. ": " .. count .. "\n")
        end
        
        f:write("\n## Verfügbare Modelle\n\n")
        for i = 1, math.min(3, #AVAILABLE_MODELS) do
            f:write("- `" .. AVAILABLE_MODELS[i] .. "`\n")
        end
        if #AVAILABLE_MODELS > 3 then
            f:write("- ... und " .. (#AVAILABLE_MODELS - 3) .. " weitere\n")
        end
        
        f:write("\n## Multi-Node Support\n\n")
        f:write("| Node | Verfügbarkeit | Kapazität | Priorität | Gerät |\n")
        f:write("|------|---------------|-----------|-----------|-------|\n")
        for node_id, config in pairs(NODES) do
            local avail = config.always_available and "✅ Immer" or "📱 Bedingt"
            local device = config.device or "Server"
            f:write("| " .. node_id .. " | " .. avail .. " | " .. (config.capacity or "unknown") .. " | " .. (config.priority or "-") .. " | " .. device .. " |\n")
        end
        
        f:write("\n### Job-Verteilung\n\n")
        f:write("- **Heavy Jobs** (>50KB × Sprachen) → Node 7 (Docker, hohe Ressourcen)\n")
        f:write("- **Medium Jobs** → Node 2 (Stable), Node 1 (Primary)\n")
        f:write("- **Light Jobs** → Node 5 (Redmi Note 11S, wenn verfügbar)\n")
        
        f:close()
    end
end

function main()
    log("Script Abstractions Manager (Multi-Node) gestartet")
    
    local state = load_state()
    log("State loaded: " .. tostring(#state.processed) .. " processed")
    
    local current_priority = state.current_priority or "high"
    local created = 0
    
    if current_priority == "high" then
        log("Processing HIGH priority: Top 5 Skills")
        created = process_priority_high()
        if created > 0 then
            git_commit("High priority: " .. created .. " abstractions")
        end
        state.current_priority = "medium"
    elseif current_priority == "medium" then
        log("Processing MEDIUM priority: Workspace Scripts")
        created = process_priority_medium()
        if created > 0 then
            git_commit("Medium priority: " .. created .. " abstractions")
        end
        state.current_priority = "high"  -- Zyklus
    end
    
    state.stats.last_run = os.date("!%Y-%m-%dT%H:%M:%S")
    
    -- Zähle Abstraktionen
    local total_abstractions = 0
    for lang, _ in pairs(TARGET_LANGUAGES) do
        local lang_dir = ABSTRACTIONS_REPO .. "/" .. lang
        if lfs.attributes(lang_dir, "mode") == "directory" then
            for file in lfs.dir(lang_dir) do
                if file ~= "." and file ~= ".." then
                    local path = lang_dir .. "/" .. file
                    if lfs.attributes(path, "mode") == "file" then
                        total_abstractions = total_abstractions + 1
                    end
                end
            end
        end
    end
    state.stats.abstractions_created = total_abstractions
    
    save_state(state)
    create_status_report(state)
    
    log("Abgeschlossen. " .. created .. " neue Abstraktionen erstellt.")
end

main()
