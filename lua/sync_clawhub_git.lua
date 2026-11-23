#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "f283f1a8cd51d25c8589b284213ff02020125c47b1bdaec38c20bba800efc06c", "source_sha256": "61022646f18bff569b8abac746e220ff7bb0333624b5b9fe62e2210671ee2acc", "target_language": "lua"}
-- sync_clawhub_git.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:scripts/sync_clawhub_git.py
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

--[[
Bidirektionale ClawHub ↔ Git Synchronisation
]]

local fs = require("filesystem")
local shell = require("shell")
local serialization = require("serialization")
local sha256 = require("crypto").sha256
local computer = require("computer")

-- Konfiguration
local CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"
local GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills"
local BACKUP_DIR = "/home/openclaw/.openclaw/workspace/backups/sync"
local LOG_FILE = "/home/openclaw/.openclaw/workspace/logs/sync-agent.log"

-- Hilfsfunktionen für Dateisystemoperationen
local function mkdir_p(path)
  local parts = {}
  for part in path:gmatch("[^/]+") do
    table.insert(parts, part)
    local current_path = "/" .. table.concat(parts, "/")
    if not fs.exists(current_path) then
      fs.makeDirectory(current_path)
    end
  end
end

local function rmdir_recursive(path)
  if fs.isDirectory(path) then
    for file in fs.list(path) do
      local fullPath = path .. "/" .. file
      if fs.isDirectory(fullPath) then
        rmdir_recursive(fullPath)
      else
        fs.remove(fullPath)
      end
    end
    fs.remove(path)
  elseif fs.exists(path) then
    fs.remove(path)
  end
end

local function copy_recursive(source, target, ignore_git)
  if fs.isDirectory(source) then
    if not fs.exists(target) then
      fs.makeDirectory(target)
    end
    for file in fs.list(source) do
      if not (ignore_git and file == ".git") then
        local srcPath = source .. "/" .. file
        local tgtPath = target .. "/" .. file
        copy_recursive(srcPath, tgtPath, ignore_git)
      end
    end
  else
    local srcFile = io.open(source, "rb")
    if srcFile then
      local content = srcFile:read("*all")
      srcFile:close()
      
      local tgtFile = io.open(target, "wb")
      if tgtFile then
        tgtFile:write(content)
        tgtFile:close()
      end
    end
  end
end

-- Erstelle Verzeichnisse
mkdir_p(GIT_DIR)
mkdir_p(BACKUP_DIR)
mkdir_p(LOG_FILE:match("(.+)/[^/]*$"))

-- Logging
local function log(message, level)
  level = level or "INFO"
  local timestamp = os.date('%Y-%m-%d %H:%M:%S')
  local entry = string.format("[%s] [%s] %s", timestamp, level, message)
  print(entry)
  
  local f = io.open(LOG_FILE, "a")
  if f then
    f:write(entry .. "\n")
    f:close()
  end
end

-- Validierung
local function validate_skill(skill_dir)
  -- Prüft Skill-Struktur - SKILL.md required, scripts/ optional
  if not fs.exists(skill_dir .. "/SKILL.md") then
    log(string.format("Validation failed: %s missing SKILL.md", skill_dir:match("[^/]*$")), "ERROR")
    return false
  end
  return true
end

-- Backup
local function create_backup(source, skill_name)
  -- Erstellt Backup eines Skills
  local timestamp = os.date('%Y%m%d_%H%M%S')
  local backup_path = BACKUP_DIR .. "/" .. skill_name .. "_" .. timestamp
  
  -- Backup verzeichnis löschen falls es existiert
  if fs.exists(backup_path) then
    rmdir_recursive(backup_path)
    log("Removed existing backup: " .. backup_path)
  end
  
  if fs.exists(source) then
    copy_recursive(source, backup_path)
    log("Backup created: " .. backup_path)
    return true
  else
    log("Source does not exist for backup: " .. source, "ERROR")
    return false
  end
end

-- Hash-Vergleich
local function get_file_hash(file_path)
  -- SHA256-Hash einer Datei
  local file = io.open(file_path, "rb")
  if not file then return "" end
  
  local content = file:read("*all")
  file:close()
  
  return sha256(content)
end

-- Sync Richtung ClawHub → Git
local function sync_to_git(skill_name, dry_run)
  -- Synchronisiert ClawHub Skill zu Git
  local source = CLAWHUB_DIR .. "/" .. skill_name
  local target = GIT_DIR .. "/" .. skill_name
  
  if not validate_skill(source) then
    return false
  end
  
  -- Backup vor Änderungen (nur wenn target existiert)
  if not dry_run and fs.exists(target) then
    create_backup(target, skill_name)
  end
  
  -- Änderungen erkennen
  local changes = {}
  
  local function scan_directory(dir_path, rel_base)
    if not fs.exists(dir_path) or not fs.isDirectory(dir_path) then return end
    
    for item in fs.list(dir_path) do
      local full_item = dir_path .. "/" .. item
      local rel_item = rel_base .. (rel_base ~= "" and "/" or "") .. item
      
      if fs.isDirectory(full_item) then
        scan_directory(full_item, rel_item)
      else
        local src_file = source .. "/" .. rel_item
        local tgt_file = target .. "/" .. rel_item
        
        -- Vergleich
        if not fs.exists(tgt_file) then
          table.insert(changes, "ADD " .. rel_item)
        elseif get_file_hash(src_file) ~= get_file_hash(tgt_file) then
          table.insert(changes, "UPDATE " .. rel_item)
        end
      end
    end
  end
  
  scan_directory(source, "")
  
  -- Dry-Run Report
  if dry_run then
    log(string.format("DRY-RUN: %s - %d changes", skill_name, #changes))
    for _, change in ipairs(changes) do
      log("  " .. change)
    end
    return true
  end
  
  -- Echte Synchronisation
  log(string.format("SYNC: %s - Applying %d changes", skill_name, #changes))
  if fs.exists(target) then
    copy_recursive(source, target, true) -- ignore .git
  else
    copy_recursive(source, target, true) -- ignore .git
  end
  log(string.format("SYNC: %s - Complete", skill_name))
  return true
end

-- Sync Richtung Git → ClawHub
local function sync_to_clawhub(skill_name, dry_run)
  -- Synchronisiert Git Skill zu ClawHub
  local source = GIT_DIR .. "/" .. skill_name
  local target = CLAWHUB_DIR .. "/" .. skill_name
  
  if not validate_skill(source) then
    return false
  end
  
  -- Backup vor Änderungen (nur wenn target existiert)
  if not dry_run and fs.exists(target) then
    create_backup(target, skill_name)
  end
  
  -- Änderungen erkennen (gleiche Logik wie oben)
  local changes = {}
  
  local function scan_directory(dir_path, rel_base)
    if not fs.exists(dir_path) or not fs.isDirectory(dir_path) then return end
    
    for item in fs.list(dir_path) do
      local full_item = dir_path .. "/" .. item
      local rel_item = rel_base .. (rel_base ~= "" and "/" or "") .. item
      
      if fs.isDirectory(full_item) then
        scan_directory(full_item, rel_item)
      else
        local src_file = source .. "/" .. rel_item
        local tgt_file = target .. "/" .. rel_item
        
        if not fs.exists(tgt_file) then
          table.insert(changes, "ADD " .. rel_item)
        elseif get_file_hash(src_file) ~= get_file_hash(tgt_file) then
          table.insert(changes, "UPDATE " .. rel_item)
        end
      end
    end
  end
  
  scan_directory(source, "")
  
  -- Dry-Run Report
  if dry_run then
    log(string.format("DRY-RUN: %s - %d changes", skill_name, #changes))
    for _, change in ipairs(changes) do
      log("  " .. change)
    end
    return true
  end
  
  -- Echte Synchronisation
  log(string.format("SYNC: %s - Applying %d changes", skill_name, #changes))
  if fs.exists(target) then
    copy_recursive(source, target, true) -- ignore .git
  else
    copy_recursive(source, target, true) -- ignore .git
  end
  log(string.format("SYNC: %s - Complete", skill_name))
  return true
end

-- Argument Parsing (vereinfacht)
local function parse_args()
  local args = {
    skill = nil,
    direction = nil,
    dry_run = false,
    force = false
  }
  
  local i = 1
  while i <= #arg do
    if arg[i] == "--skill" and arg[i+1] then
      args.skill = arg[i+1]
      i = i + 2
    elseif arg[i] == "--direction" and arg[i+1] then
      args.direction = arg[i+1]
      i = i + 2
    elseif arg[i] == "--dry-run" then
      args.dry_run = true
      i = i + 1
    elseif arg[i] == "--force" then
      args.force = true
      i = i + 1
    else
      i = i + 1
    end
  end
  
  return args
end

-- Hauptfunktion
local function main()
  local args = parse_args()
  
  if not args.skill or not args.direction then
    print("Usage: sync_clawhub_git.lua --skill <skill> --direction [to-git|to-clawhub] [--dry-run] [--force]")
    return 1
  end
  
  log(string.format("Starting sync: %s (%s)", args.skill, args.direction))
  
  local success
  if args.direction == "to-git" then
    success = sync_to_git(args.skill, args.dry_run)
  elseif args.direction == "to-clawhub" then
    success = sync_to_clawhub(args.skill, args.dry_run)
  else
    print("Invalid direction. Use 'to-git' or 'to-clawhub'")
    return 1
  end
  
  if not success then
    log("Sync failed", "ERROR")
    return 1
  end
  
  log("Sync completed")
  return 0
end

-- Start the program
os.exit(main())
