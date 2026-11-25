#!/usr/bin/lua
-- abstraction-provenance: {"artifact_sha256": "d0d8169efae1eeaf46c14549592de869efdd4349cb57facc906dffa3030cfaa7", "source_sha256": "151279ec3dae16c8f81904c36418b5f9c6040036a0a98adef5ec52bfea0b57ab", "target_language": "lua"}
-- test_node3.sh — portiert nach lua
-- Quelle: shell, OpenClaw@gateway1:scripts/test_node3.sh
-- auch in: OpenClaw@gateway2:scripts/test_node3.sh
-- auch in: workspace@local:scripts/test_node3.sh
-- Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

-- Test Node 3 Connection
os.execute("export OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=1")

print("Starting node connection test...")

-- Start the openclaw command in background and kill it after 15 seconds
local cmd = "/usr/local/bin/openclaw node run --host 152.53.145.65 --port 18789"
local exit_code = 0

-- Run with timeout using alarm (POSIX) or simulate timeout behavior
local handle = io.popen("timeout 15 " .. cmd .. " 2>&1; echo $?", "r")
if handle then
    local output = handle:read("*a")
    handle:close()
    
    -- Print all output except the last line which contains exit code
    local lines = {}
    for line in output:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    -- Print all lines except the last one (which is the exit code)
    for i = 1, #lines - 1 do
        print(lines[i])
    end
    
    -- Get exit code from the last line
    if #lines > 0 then
        exit_code = tonumber(lines[#lines]) or 0
    end
end

print("Exit code: " .. exit_code)
