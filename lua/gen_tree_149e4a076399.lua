#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "b8e611f2b06d4f9d3d53b439793bfd37b80186b8ae6eb1d9b493e0019268c387", "source_sha256": "0a55a33f11db266892b50c887fd8d01783f387e3072c8c5b9ed86ca6788a8c52", "target_language": "lua"}
-- gen_tree.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway2:scripts/gen_tree.py
-- Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

--[[ Replicates `tree -a -L 6` output for /workspace into important/openclaw-tree.txt
(used because the `tree` binary is unavailable in this sandbox). ]]

local ROOT = "/workspace"
local OUT = "/workspace/important/openclaw-tree.txt"
local MAX_DEPTH = 6

-- Helper function to list directory contents
local function list_dir(path)
    local entries = {}
    local handle = io.popen('ls -1 "' .. path .. '" 2>/dev/null')
    if handle then
        for line in handle:lines() do
            table.insert(entries, line)
        end
        handle:close()
    end
    -- Sort entries
    table.sort(entries)
    return entries
end

local function collect(path, prefix, depth)
    prefix = prefix or ""
    depth = depth or 1
    local lines = {}
    
    local entries = list_dir(path)
    local total = #entries
    
    for i, name in ipairs(entries) do
        local is_last = (i == total)
        local connector = is_last and "└── " or "├── "
        table.insert(lines, prefix .. connector .. name)
        
        local full = path .. "/" .. name
        -- Check if it's a directory (and not a symlink) and within depth limit
        -- Using stat to check if it's a directory
        local stat_handle = io.popen('stat -c "%F" "' .. full .. '" 2>/dev/null')
        local file_type = stat_handle:read("*line")
        stat_handle:close()
        
        local is_dir = (file_type == "directory")
        -- Check for symlinks
        local is_link_handle = io.popen('test -L "' .. full .. '" && echo "link" || echo "notlink"')
        local is_link = (is_link_handle:read("*line") == "link")
        is_link_handle:close()
        
        if depth < MAX_DEPTH and is_dir and not is_link then
            local next_prefix = prefix .. (is_last and "    " or "│   ")
            local sub_lines = collect(full, next_prefix, depth + 1)
            for _, line in ipairs(sub_lines) do
                table.insert(lines, line)
            end
        end
    end
    
    return lines
end

local body = collect(ROOT)

-- Get current timestamp
local timestamp = os.date("%Y-%m-%dT%H:%M:%S")

local header = (
    "# OpenClaw Workspace Tree\n" ..
    "# Generiert: " .. timestamp .. "\n" ..
    "# Befehl: tree -a -L 6 " .. ROOT .. " (emuliert via gen_tree.lua)\n" ..
    "# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n"
)

local content = header .. ".\n" .. table.concat(body, "\n") .. "\n"

local file = io.open(OUT, "w")
if file then
    file:write(content)
    file:close()
    print(string.format("written %s: %d lines, %d bytes", OUT, #body + 1, #content))
else
    print("Error: Could not write to " .. OUT)
end
