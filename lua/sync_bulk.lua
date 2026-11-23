#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "742c50ab9478e1a5755151dadbd934928ef7fac4b25ad528d3acab22187581e7", "source_sha256": "e86a7b42e9bd3c3d2f9321883c9d29b0e6b2774e4eb99056dd5093ca64b5b5c8", "target_language": "lua"}
-- sync_bulk.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/sync_bulk.py
-- auch in: OpenClaw@gateway2:skills/sync-utils/scripts/sync_bulk.py
-- auch in: workspace@local:git/skills/sync-utils/scripts/sync_bulk.py
-- auch in: workspace@local:skills/sync-utils/scripts/sync_bulk.py
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

--[[
Bulk Sync - Synchronisiert alle Skills
]]

local Path = require("pl.path")
local dir = require("pl.dir")
local tablex = require("pl.tablex")
local stringx = require("pl.stringx")
local lapp = require("pl.lapp")

-- Füge das Verzeichnis zum Suchpfad hinzu
package.path = package.path .. ";/home/openclaw/.openclaw/workspace/scripts/?.lua"

-- Importiere sync Funktionen
local sync_module = require("sync_clawhub_git")
local sync_to_git = sync_module.sync_to_git
local sync_to_clawhub = sync_module.sync_to_clawhub
local log = sync_module.log
local validate_skill = sync_module.validate_skill

local CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"
local GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills"

-- Hilfsfunktion um maximale Mtime zu finden
local function get_max_mtime(path)
    local max_time = 0
    if Path.exists(path) then
        for file in dir.walk(path) do
            if Path.isfile(file) and not string.find(file, "%.git") then
                local attr = Path.getmtime(file)
                if attr and attr > max_time then
                    max_time = attr
                end
            end
        end
    end
    return max_time
end

local function sync_all_skills(dry_run)
    dry_run = dry_run or true
    
    -- Alle Skills finden
    local all_skills = {}
    
    -- Skills aus ClawHub Verzeichnis
    if Path.exists(CLAWHUB_DIR) then
        for d in dir.dirs(CLAWHUB_DIR) do
            local skill_name = Path.basename(d)
            if not stringx.startswith(skill_name, ".") then
                all_skills[skill_name] = true
            end
        end
    end
    
    -- Skills aus Git Verzeichnis
    if Path.exists(GIT_DIR) then
        for d in dir.dirs(GIT_DIR) do
            local skill_name = Path.basename(d)
            if not stringx.startswith(skill_name, ".") then
                all_skills[skill_name] = true
            end
        end
    end
    
    local skill_list = {}
    for skill_name, _ in pairs(all_skills) do
        table.insert(skill_list, skill_name)
    end
    table.sort(skill_list)
    
    log("Bulk Sync: " .. #skill_list .. " Skills gefunden")
    
    local results = {
        synced = {},
        skipped = {},
        failed = {}
    }
    
    for _, skill in ipairs(skill_list) do
        local clawhub_path = Path.join(CLAWHUB_DIR, skill)
        local git_path = Path.join(GIT_DIR, skill)
        
        local clawhub_exists = Path.exists(clawhub_path) and Path.isdir(clawhub_path)
        local git_exists = Path.exists(git_path) and Path.isdir(git_path)
        
        local success, err = pcall(function()
            -- Nur in ClawHub → zu Git
            if clawhub_exists and not git_exists then
                if validate_skill(clawhub_path) then
                    log("Syncing " .. skill .. " to Git...")
                    if sync_to_git(skill, dry_run) then
                        table.insert(results.synced, skill .. " → Git")
                    else
                        table.insert(results.failed, skill)
                    end
                else
                    table.insert(results.skipped, skill .. " (validation failed)")
                end
            
            -- Nur in Git → zu ClawHub
            elseif git_exists and not clawhub_exists then
                if validate_skill(git_path) then
                    log("Syncing " .. skill .. " to ClawHub...")
                    if sync_to_clawhub(skill, dry_run) then
                        table.insert(results.synced, skill .. " → ClawHub")
                    else
                        table.insert(results.failed, skill)
                    end
                else
                    table.insert(results.skipped, skill .. " (validation failed)")
                end
            
            -- In beiden - prüfe ob Update nötig
            elseif clawhub_exists and git_exists then
                -- Vereinfachte Prüfung
                local clawhub_mtime = get_max_mtime(clawhub_path)
                local git_mtime = get_max_mtime(git_path)
                
                if math.abs(clawhub_mtime - git_mtime) > 60 then
                    if clawhub_mtime > git_mtime then
                        log("Updating " .. skill .. " in Git...")
                        if sync_to_git(skill, dry_run) then
                            table.insert(results.synced, skill .. " → Git (update)")
                        else
                            table.insert(results.failed, skill)
                        end
                    else
                        log("Updating " .. skill .. " in ClawHub...")
                        if sync_to_clawhub(skill, dry_run) then
                            table.insert(results.synced, skill .. " → ClawHub (update)")
                        else
                            table.insert(results.failed, skill)
                        end
                    end
                else
                    table.insert(results.skipped, skill .. " (already synced)")
                end
            end
        end)
        
        if not success then
            log("Error processing " .. skill .. ": " .. tostring(err), "ERROR")
            table.insert(results.failed, skill)
        end
    end
    
    -- Zusammenfassung
    print("\n" .. string.rep("=", 60))
    print("Bulk Sync " .. (dry_run and "DRY-RUN" or "EXECUTED") .. " - Zusammenfassung")
    print(string.rep("=", 60))
    print("✅ Synchronisiert: " .. #results.synced)
    for _, item in ipairs(results.synced) do
        print("   - " .. item)
    end
    print("\n⏭️  Übersprungen: " .. #results.skipped)
    if #results.skipped <= 10 then
        for _, item in ipairs(results.skipped) do
            print("   - " .. item)
        end
    else
        print("   - " .. #results.skipped .. " Skills (bereits synchron oder Validierung fehlgeschlagen)")
    end
    print("\n❌ Fehlgeschlagen: " .. #results.failed)
    for _, item in ipairs(results.failed) do
        print("   - " .. item)
    end
    print(string.rep("=", 60))
end

local function main()
    local args = lapp [[
Bulk Sync für alle Skills
    -d,--dry-run (boolean)  Nur Änderungen anzeigen
    -e,--execute (boolean)  Sync ausführen
]]
    
    if not args.dry_run and not args.execute then
        print("Bitte --dry-run oder --execute angeben")
        os.exit(1)
    end
    
    sync_all_skills(not args.execute) -- Wenn execute angegeben ist, ist dry_run false
end

main()
