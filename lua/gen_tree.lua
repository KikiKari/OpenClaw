#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "22f6076bd523a958d9f2f31381268bb4b4e4363e5ffce233a384894c475051b0", "source_sha256": "0a55a33f11db266892b50c887fd8d01783f387e3072c8c5b9ed86ca6788a8c52", "target_language": "lua"}
-- gen_tree.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway2:scripts/gen_tree.py
-- Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

--[[Replicates `tree -a -L 6` output for /workspace into important/openclaw-tree.txt
(used because the `tree` binary is unavailable in this sandbox).]]
local ROOT = "/workspace"
local OUT = "/workspace/important/openclaw-tree.txt"
local MAX_DEPTH = 6

function collect(path, prefix, depth)
    prefix = prefix or ""
    depth = depth or 1
    local lines = {}
    local entries = {}
    local handle = io.popen("ls -1 \"" .. path .. "\" 2>/dev/null")
    if not handle then
        return lines
    end
    for line in handle:lines() do
        table.insert(entries, line)
    end
    handle:close()
    table.sort(entries)
    local total = #entries
    for i, name in ipairs(entries) do
        local is_last = (i == total)
        local connector = is_last and "└── " or "├── "
        table.insert(lines, prefix .. connector .. name)
        local full = path .. "/" .. name
        -- Check if it's a directory (not a symlink) and within depth limit
        local stat_handle = io.popen("test -d \"" .. full .. "\" && echo 'dir'")
        local is_dir = stat_handle:read("*line")
        stat_handle:close()
        local link_handle = io.popen("test -L \"" .. full .. "\" && echo 'link'")
        local is_link = link_handle:read("*line")
        link_handle:close()
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
local timestamp = os.date("%Y-%m-%dT%H:%M:%S")
local header = (
    "# OpenClaw Workspace Tree\n" ..
    "# Generiert: " .. timestamp .. "\n" ..
    "# Befehl: tree -a -L 6 " .. ROOT .. " (emuliert via gen_tree.lua)\n" ..
    "# Diese Datei wird automatisch von db-maintainer aktualisiert\n\n"
)
local content = header .. ".\n" .. table.concat(body, "\n") .. "\n"

local f = io.open(OUT, "w")
if f then
    f:write(content)
    f:close()
    print(string.format("written %s: %d lines, %d bytes", OUT, #body + 1, #content))
else
    print("Error: Could not write to " .. OUT)
end
