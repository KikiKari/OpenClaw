#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "f0d2b45c5a6898bf9011c9b999dc713867dbc52dc54dd36ae1ddb57f77f16439", "source_sha256": "d5eb18db536b690023fd61c3dfa4d99f899ec602247f48fb044c53baebb78556", "target_language": "lua"}
-- serve_compare_transfer.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:scripts/serve_compare_transfer.sh
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare"
local TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer"
local HOST_IP = "152.53.145.65"
local PORT = "80"
local SELF_PATH = arg[0]

-- Function to get sorted files excluding self
local function get_files()
    local files = {}
    local handle = io.popen('find "' .. COMPARE_DIR .. '" -maxdepth 1 -type f -print0 | sort -z')
    if not handle then
        error("Failed to execute find command")
    end
    
    local result = handle:read("*a")
    handle:close()
    
    -- Split by null byte and filter out self path
    for file in string.gmatch(result, "[^\0]+") do
        if file ~= SELF_PATH then
            table.insert(files, file)
        end
    end
    
    return files
end

local files = get_files()

if #files == 0 then
    print("Keine Dateien in " .. COMPARE_DIR .. " gefunden.")
    os.exit(1)
end

print()
print("Bereitgestellte Dateien aus " .. COMPARE_DIR .. ":")
for _, src in ipairs(files) do
    local basename = src:match("([^/]+)$")
    print("- " .. basename)
end

print()
print("Copy/Paste auf anderem Gateway (Download nach " .. TRANSFER_DIR .. "):")
for _, src in ipairs(files) do
    local file = src:match("([^/]+)$")
    print("curl -fL --retry 3 --connect-timeout 10 -o " .. TRANSFER_DIR .. "/" .. file .. " http://" .. HOST_IP .. ":" .. PORT .. "/" .. file)
end

print()
print("Server auf Port " .. PORT .. " aktiv. Beenden mit STRG+C.")
print()

-- Change directory and start HTTP server
os.execute("cd " .. COMPARE_DIR .. " && python3 -m http.server " .. PORT .. " --bind 0.0.0.0")
