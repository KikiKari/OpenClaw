#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "d7a5af093efe37e20f7c838d83f8f4895e71031133cefebbac7d36ed48d98224", "source_sha256": "5d90ebcd250a3cb80a0de664d94397af7ec03343d9d9fa64a28a9a11ad880754", "target_language": "lua"}
-- check_conflicts.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/check_conflicts.py
-- auch in: OpenClaw@gateway2:skills/sync-utils/scripts/check_conflicts.py
-- Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

--[[
Check Conflicts - Erkennt Sync-Konflikte
]]

local socket = require("socket")
local lfs = require("lfs")

-- Configuration
local CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"
local GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills"

-- Helper function to calculate file hash (MD5)
local function get_file_hash(filepath)
    local file = io.open(filepath, "rb")
    if not file then return nil end
    
    local content = file:read("*all")
    file:close()
    
    local md5 = require("md5")
    return md5.sumhexa(content)
end

-- Helper function to get modification time
local function get_modification_time(filepath)
    local attr = lfs.attributes(filepath)
    if attr then
        return os.date("%Y-%m-%d %H:%M:%S", attr.modification)
    end
    return nil
end

-- Helper function to compare modification times
local function compare_modification_times(filepath1, filepath2)
    local attr1 = lfs.attributes(filepath1)
    local attr2 = lfs.attributes(filepath2)
    
    if attr1 and attr2 then
        if attr1.modification > attr2.modification then
            return "clawhub"
        else
            return "git"
        end
    end
    return "unknown"
end

-- Recursive directory traversal
local function scan_directory(dirpath, basepath, files)
    for file in lfs.dir(dirpath) do
        if file ~= "." and file ~= ".." and not string.find(file, "%.git") then
            local filepath = dirpath .. "/" .. file
            local attr = lfs.attributes(filepath)
            
            if attr then
                if attr.mode == "directory" then
                    scan_directory(filepath, basepath, files)
                elseif attr.mode == "file" then
                    local rel_path = string.gsub(filepath, basepath .. "/", "")
                    files[rel_path] = filepath
                end
            end
        end
    end
end

-- Main conflict checking function
local function check_conflicts()
    local conflicts = {}
    
    -- Get list of skills from both directories
    local clawhub_skills = {}
    local git_skills = {}
    
    if lfs.attributes(CLAWHUB_DIR) and lfs.attributes(GIT_DIR) then
        for skill in lfs.dir(CLAWHUB_DIR) do
            if skill ~= "." and skill ~= ".." then
                local attr = lfs.attributes(CLAWHUB_DIR .. "/" .. skill)
                if attr and attr.mode == "directory" then
                    clawhub_skills[skill] = true
                end
            end
        end
        
        for skill in lfs.dir(GIT_DIR) do
            if skill ~= "." and skill ~= ".." then
                local attr = lfs.attributes(GIT_DIR .. "/" .. skill)
                if attr and attr.mode == "directory" then
                    git_skills[skill] = true
                end
            end
        end
    end
    
    -- Find common skills
    local common_skills = {}
    for skill, _ in pairs(clawhub_skills) do
        if git_skills[skill] then
            table.insert(common_skills, skill)
        end
    end
    
    table.sort(common_skills)
    
    print("Prüfe " .. #common_skills .. " Skills auf Konflikte...\n")
    
    for _, skill in ipairs(common_skills) do
        local clawhub_path = CLAWHUB_DIR .. "/" .. skill
        local git_path = GIT_DIR .. "/" .. skill
        
        -- Scan files in both directories
        local clawhub_files = {}
        local git_files = {}
        
        scan_directory(clawhub_path, clawhub_path, clawhub_files)
        scan_directory(git_path, git_path, git_files)
        
        -- Compare common files
        local skill_conflicts = {}
        
        for rel_path, clawhub_file in pairs(clawhub_files) do
            local git_file = git_files[rel_path]
            
            if git_file then
                local clawhub_hash = get_file_hash(clawhub_file)
                local git_hash = get_file_hash(git_file)
                
                if clawhub_hash ~= git_hash then
                    local clawhub_mtime = get_modification_time(clawhub_file)
                    local git_mtime = get_modification_time(git_file)
                    local newer = compare_modification_times(clawhub_file, git_file)
                    
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
    
    -- Output results
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

-- Main function
local function main()
    check_conflicts()
end

main()
