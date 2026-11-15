#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "8a81ce6366a2090b92a523703d44ea59d9d7941811f7860a909795d201f12fa1", "source_sha256": "77eca70a7a8f9c0ff8dc240b14d8c37999854c241e031b8167e1fcd650cbd334", "target_language": "lua"}
-- install_cron.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/db-maintainer/scripts/install_cron.py
-- auch in: OpenClaw@gateway2:skills/db-maintainer/scripts/install_cron.py
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

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

local function mkdir_p(path)
    -- Erstelle Verzeichnisstruktur (vereinfacht für dieses Beispiel)
    -- In echtem Code bräuchte man eine rekursive mkdir-Funktion
    os.execute("mkdir -p " .. path)
end

local function json_decode(str)
    local json = require("cjson")
    return json.decode(str)
end

local function json_encode(obj)
    local json = require("cjson")
    return json.encode(obj)
end

local function install()
    local workspace = "/home/openclaw/.openclaw/workspace"
    local cron_file = workspace .. "/crons/db-maintainer.cron"
    
    mkdir_p(workspace .. "/crons")
    
    if not write_file(cron_file, CRON_JOB) then
        print("❌ Fehler beim Schreiben der Cron-Datei")
        return
    end
    
    print("✅ Cron-Job installiert: " .. cron_file)
    print("   Füge zu crontab hinzu mit: crontab < crons/db-maintainer.cron")
    
    -- Auch in OpenClaw cron registrieren
    local jobs_json = workspace .. "/.openclaw/cron/jobs.json"
    if file_exists(jobs_json) then
        local content = read_file(jobs_json)
        if not content then
            print("❌ Fehler beim Lesen der jobs.json")
            return
        end
        
        local jobs = json_decode(content)
        
        jobs["db-maintainer"] = {
            schedule = "*/30 * * * *",
            command = "python3 skills/db-maintainer/scripts/db_maintainer.py",
            enabled = true
        }
        
        local new_content = json_encode(jobs)
        if not write_file(jobs_json, new_content) then
            print("❌ Fehler beim Schreiben der jobs.json")
            return
        end
        
        print("✅ In OpenClaw cron registriert")
    end
end

install()
