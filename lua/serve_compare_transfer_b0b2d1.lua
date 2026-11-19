#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "be533239de86adb37160d9f255cef5a91f8dbc07c0a676ab795f8cde04adc2d1", "source_sha256": "b0b2d14634c78d492d814989a9bf887ffef50ac058176565e0d55191bb8ac787", "target_language": "lua"}
-- serve_compare_transfer.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway2:scripts/serve_compare_transfer.sh
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

local COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare"
local TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer"
local HOST_IP = "89.58.15.220"
local PORT = "80"
local SELF_PATH = arg[0]

-- Function to get files in directory
local function get_files(dir)
    local files = {}
    local handle = io.popen('find "' .. dir .. '" -maxdepth 1 -type f -print0 | sort -z')
    if handle then
        local result = handle:read("*a")
        handle:close()
        
        -- Split by null character
        for file in string.gmatch(result, "[^\0]+") do
            if file ~= "" and file ~= SELF_PATH then
                table.insert(files, file)
            end
        end
    end
    return files
end

local files = get_files(COMPARE_DIR)

if #files == 0 then
    print("Keine Dateien in " .. COMPARE_DIR .. " gefunden.")
    os.exit(1)
end

table.sort(files)

print()
print("Bereitgestellte Dateien aus " .. COMPARE_DIR .. ":")
for _, src in ipairs(files) do
    print("- " .. src:match("([^/]+)/?$"))
end

print()
print("Copy/Paste auf anderem Gateway (Download nach " .. TRANSFER_DIR .. "):")
for _, src in ipairs(files) do
    local file = src:match("([^/]+)/?$")
    print("curl -fL --retry 3 --connect-timeout 10 -o " .. TRANSFER_DIR .. "/" .. file .. " http://" .. HOST_IP .. ":" .. PORT .. "/" .. file)
end

print()
print("Server auf Port " .. PORT .. " aktiv. Beenden mit STRG+C.")
print()

-- Change directory and start server
os.execute("cd " .. COMPARE_DIR .. " && python3 -m http.server " .. PORT .. " --bind 0.0.0.0")
