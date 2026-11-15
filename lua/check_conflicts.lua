#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "295b2a946a48db5ac219200c3378465529b89ce4c58aad8743485a4ceb56af1f", "source_sha256": "5d90ebcd250a3cb80a0de664d94397af7ec03343d9d9fa64a28a9a11ad880754", "target_language": "lua"}
-- check_conflicts.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/check_conflicts.py
-- auch in: OpenClaw@gateway2:skills/sync-utils/scripts/check_conflicts.py
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

--[[
Check Conflicts - Erkennt Sync-Konflikte
]]

local socket = require("socket")
local lfs = require("lfs")

-- Globale Konstanten
local CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"
local GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills"

-- Hilfsfunktion um Dateiliste rekursiv zu erhalten
local function scan_directory(dir, base)
    local files = {}
    for file in lfs.dir(dir) do
        if file ~= "." and file ~= ".." then
            local path = dir .. "/" .. file
            local attr = lfs.attributes(path)
            if attr.mode == "directory" then
                if file ~= ".git" then
                    local subfiles = scan_directory(path, base or dir)
                    for k, v in pairs(subfiles) do
                        files[k] = v
                    end
                end
            else
                local relpath
                if base then
                    relpath = string.gsub(path, "^" .. base .. "/", "")
                else
                    relpath = file
                end
                files[relpath] = path
            end
        end
    end
    return files
end

-- Berechnet MD5 Hash einer Datei
local function get_file_hash(filepath)
    local handle = io.popen("md5sum '" .. filepath .. "' 2>/dev/null")
    if not handle then return nil end
    local result = handle:read("*a")
    handle:close()
    if not result or result == "" then return nil end
    return string.match(result, "^[a-f0-9]+")
end

-- Prüft auf Konflikte zwischen ClawHub und Git
local function check_conflicts()
    -- Alle Skills die in beiden Orten existieren
    local common_skills = {}
    
    if lfs.attributes(CLAWHUB_DIR) and lfs.attributes(GIT_DIR) then
        local clawhub_skills = {}
        local git_skills = {}
        
        -- Hole Skill-Namen aus ClawHub
        for item in lfs.dir(CLAWHUB_DIR) do
            if item ~= "." and item ~= ".." then
                local path = CLAWHUB_DIR .. "/" .. item
                local attr = lfs.attributes(path)
                if attr and attr.mode == "directory" then
                    clawhub_skills[item] = true
                end
            end
        end
        
        -- Hole Skill-Namen aus Git
        for item in lfs.dir(GIT_DIR) do
            if item ~= "." and item ~= ".." then
                local path = GIT_DIR .. "/" .. item
                local attr = lfs.attributes(path)
                if attr and attr.mode == "directory" then
                    git_skills[item] = true
                end
            end
        end
        
        -- Finde gemeinsame Skills
        for skill_name, _ in pairs(clawhub_skills) do
            if git_skills[skill_name] then
                table.insert(common_skills, skill_name)
            end
        end
    end
    
    table.sort(common_skills)
    print("Prüfe " .. #common_skills .. " Skills auf Konflikte...\n")
    
    local conflicts = {}
    
    for _, skill in ipairs(common_skills) do
        local clawhub_path = CLAWHUB_DIR .. "/" .. skill
        local git_path = GIT_DIR .. "/" .. skill
        
        -- Alle Dateien vergleichen
        local skill_conflicts = {}
        
        -- Hole Dateien beider Systeme
        local clawhub_files = scan_directory(clawhub_path, clawhub_path)
        local git_files = scan_directory(git_path, git_path)
        
        -- Vergleiche gemeinsame Dateien
        for rel_path, clawhub_file in pairs(clawhub_files) do
            local git_file = git_files[rel_path]
            if git_file then
                local clawhub_hash = get_file_hash(clawhub_file)
                local git_hash = get_file_hash(git_file)
                
                if clawhub_hash ~= git_hash then
                    local clawhub_attr = lfs.attributes(clawhub_file)
                    local git_attr = lfs.attributes(git_file)
                    
                    local clawhub_mtime = os.date("%Y-%m-%d %H:%M:%S", clawhub_attr.modification)
                    local git_mtime = os.date("%Y-%m-%d %H:%M:%S", git_attr.modification)
                    
                    local newer = "git"
                    if clawhub_attr.modification > git_attr.modification then
                        newer = "clawhub"
                    end
                    
                    table.insert(skill_conflicts, {
                        file = rel_path,
                        clawhub_modified = clawhub_mtime,
                        git_modified = git_mtime,
                        newer = newer
                    })
                end
            end
        end
        
        if #skill_conflicts > 0 then
            table.insert(conflicts, {
                skill = skill,
                conflicts = skill_conflicts
            })
        end
    end
    
    -- Ausgabe
    if #conflicts > 0 then
        print("⚠️  KONFLIKTE GEFUNDEN:")
        print(string.rep("=", 80))
        
        for _, conflict in ipairs(conflicts) do
            print("\n📦 Skill: " .. conflict.skill)
            print(string.rep("-", 40))
            
            for _, file_conflict in ipairs(conflict.conflicts) do
                print("  📄 " .. file_conflict.file)
                print("     ClawHub: " .. file_conflict.clawhub_modified)
                print("     Git:     " .. file_conflict.git_modified)
                print("     Neuer:   " .. string.upper(file_conflict.newer))
                print()
            end
        end
        
        print(string.rep("=", 80))
        print("Gesamt: " .. #conflicts .. " Skills mit Konflikten")
        print("\nNutze 'sync_utils/scripts/resolve_conflict.py' zum Auflösen.")
    else
        print("✅ Keine Konflikte gefunden!")
        print("Alle gemeinsamen Skills sind synchron.")
    end
end

-- Hauptfunktion
local function main()
    check_conflicts()
end

main()
