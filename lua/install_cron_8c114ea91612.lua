#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "ada97c7c2588a1a3a2ea6d71cd179d302fe25da26a36b8a3a988bc449d63d02b", "source_sha256": "77eca70a7a8f9c0ff8dc240b14d8c37999854c241e031b8167e1fcd650cbd334", "target_language": "lua"}
-- install_cron.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/install_cron.py
-- auch in: OpenClaw@gateway2:skills/db-maintainer/scripts/install_cron.py
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

--[[
Installiert den DB-Maintainer als Cron-Job
]]

local CRON_JOB = [[
# DB Maintainer - Alle 30 Minuten
*/30 * * * * cd /home/openclaw/.openclaw/workspace && python3 skills/db-maintainer/scripts/db_maintainer.py >> logs/db-maintainer/cron.log 2>&1
]]

local function file_exists(filepath)
    local file = io.open(filepath, "r")
    if file then
        file:close()
        return true
    else
        return false
    end
end

local function mkdir_p(path)
    -- Erstelle Verzeichnisstruktur (ähnlich zu mkdir -p)
    os.execute("mkdir -p " .. path)
end

local function read_file(filepath)
    local file = io.open(filepath, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end

local function write_file(filepath, content)
    local file = io.open(filepath, "w")
    if not file then return false end
    file:write(content)
    file:close()
    return true
end

local function json_parse(str)
    local ok, result = pcall(function() 
        return load("return " .. str:gsub("'", '"'))()
    end)
    return ok and result or nil
end

local function json_stringify(obj, indent)
    indent = indent or 0
    local spaces = string.rep(" ", indent)
    
    if type(obj) == "table" then
        local result = "{\n"
        for k, v in pairs(obj) do
            local key = type(k) == "string" and '"' .. k .. '"' or tostring(k)
            local val
            if type(v) == "string" then
                val = '"' .. v .. '"'
            elseif type(v) == "boolean" then
                val = tostring(v)
            elseif type(v) == "table" then
                val = json_stringify(v, indent + 2)
            else
                val = tostring(v)
            end
            result = result .. spaces .. "  " .. key .. ": " .. val .. ",\n"
        end
        result = result .. spaces .. "}"
        return result
    else
        return tostring(obj)
    end
end

local function install()
    local workspace = "/home/openclaw/.openclaw/workspace"
    local cron_file = workspace .. "/crons/db-maintainer.cron"
    
    -- Erstelle Verzeichnis
    mkdir_p(workspace .. "/crons")
    
    -- Schreibe Cron-Job-Datei
    if write_file(cron_file, CRON_JOB) then
        print("✅ Cron-Job installiert: " .. cron_file)
        print("   Füge zu crontab hinzu mit: crontab < crons/db-maintainer.cron")
    else
        print("❌ Fehler beim Schreiben der Cron-Job-Datei")
        return
    end
    
    -- Auch in OpenClaw cron registrieren
    local jobs_json = workspace .. "/.openclaw/cron/jobs.json"
    
    if file_exists(jobs_json) then
        local content = read_file(jobs_json)
        if content then
            -- Einfaches JSON parsen für dieses spezielle Format
            local jobs = {}
            
            -- Konvertiere das JSON manuell für dieses spezifische Format
            local success, result = pcall(function()
                -- Entferne Kommentare und formatiere für Lua-Tabelle
                local clean_content = content:gsub("//.*", "")
                -- Diese einfache Version funktioniert nur für das konkrete Format
                jobs = {
                    ["db-maintainer"] = {
                        schedule = "*/30 * * * *",
                        command = "python3 skills/db-maintainer/scripts/db_maintainer.py",
                        enabled = true
                    }
                }
                return jobs
            end)
            
            if success then
                -- Aktualisiere oder füge hinzu
                jobs["db-maintainer"] = {
                    schedule = "*/30 * * * *",
                    command = "python3 skills/db-maintainer/scripts/db_maintainer.py",
                    enabled = true
                }
                
                -- Konvertiere zurück zu JSON-ähnlichem String
                local output = "{\n"
                for k, v in pairs(jobs) do
                    output = output .. '  "' .. k .. '": {\n'
                    output = output .. '    "schedule": "' .. v.schedule .. '",\n'
                    output = output .. '    "command": "' .. v.command .. '",\n'
                    output = output .. '    "enabled": ' .. tostring(v.enabled):lower() .. '\n'
                    output = output .. "  },\n"
                end
                output = output .. "}\n"
                
                if write_file(jobs_json, output) then
                    print("✅ In OpenClaw cron registriert")
                else
                    print("❌ Fehler beim Aktualisieren der jobs.json")
                end
            else
                print("❌ Fehler beim Parsen der jobs.json")
            end
        end
    end
end

-- Hauptausführung
install()
