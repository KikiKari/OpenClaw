#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "f04335117621fe4f2948a59b6ecb2d20661d759873babe9f718cb917cfd5df08", "source_sha256": "47740d82dac30833751ad7e0c569c7c084b01b1468243a6aebaf3f4a526f0a93", "target_language": "lua"}
-- pplx-refresh.sh — portiert nach lua
-- Quelle: shell, OpenClaw@main:scripts/pplx-tools/pplx-refresh.sh
-- Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

-- Refresh the codespace Perplexity session from a locally-exported cookie.
--
-- Usage:
--   ./pplx-refresh.lua [cookie-file]
--
-- cookie-file defaults to ~/pplx-cookies.txt. Put your local browser's
-- __Secure-next-auth.session-token value (raw), or the whole Cookie header,
-- or a JSON cookie export, into that file first.
--
-- Steps: ensure daemon browser -> read daemon passphrase -> inject into vault
--        -> trigger reinit -> verify authenticated.

local os = require("os")
local io = require("io")
local posix = require("posix")

local function exit_with_error(msg, code)
    io.stderr:write(msg .. "\n")
    os.exit(code or 1)
end

local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

local function file_size(path)
    local f = io.open(path, "r")
    if not f then return 0 end
    local size = f:seek("end")
    f:close()
    return size
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function write_file(path, content)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(content)
    f:close()
    return true
end

local function get_env_var(name)
    return os.getenv(name)
end

local function run_command(cmd)
    local handle = io.popen(cmd)
    if not handle then return nil end
    local result = handle:read("*a")
    handle:close()
    return result
end

local function json_parse(str)
    local json = require("cjson")
    return json.decode(str)
end

local function find_npm_dist()
    local home = os.getenv("HOME")
    if not home then return nil end
    
    local find_cmd = "find " .. home .. "/.npm/_npx -type d -path '*perplexity-user-mcp/dist' 2>/dev/null | head -1"
    local result = run_command(find_cmd)
    if result and result:match("%S") then
        return result:gsub("%s+$", "")
    end
    
    run_command("npx -y perplexity-user-mcp --version >/dev/null 2>&1 || true")
    
    result = run_command(find_cmd)
    if result and result:match("%S") then
        return result:gsub("%s+$", "")
    end
    
    return nil
end

local function get_daemon_pid(lock_file)
    if not file_exists(lock_file) then
        exit_with_error("✗ no daemon.lock at " .. lock_file .. " — is the extension running?", 1)
    end
    
    local content = read_file(lock_file)
    if not content then
        exit_with_error("✗ failed to read daemon.lock", 1)
    end
    
    local ok, data = pcall(json_parse, content)
    if not ok or not data or not data.pid then
        exit_with_error("✗ invalid JSON in daemon.lock", 1)
    end
    
    local pid = tonumber(data.pid)
    if not pid then
        exit_with_error("✗ invalid PID in daemon.lock", 1)
    end
    
    local ps_cmd = "ps -p " .. pid .. " -o pid="
    local result = run_command(ps_cmd)
    if not result or not result:match("%d+") then
        exit_with_error("✗ daemon pid " .. pid .. " not running", 1)
    end
    
    return pid
end

local function get_daemon_passphrase(pid)
    local env_file = "/proc/" .. pid .. "/environ"
    if not file_exists(env_file) then
        exit_with_error("✗ cannot access daemon environment", 1)
    end
    
    local content = read_file(env_file)
    if not content then
        exit_with_error("✗ failed to read daemon environment", 1)
    end
    
    for line in content:gmatch("[^%z]+") do
        if line:sub(1, 28) == "PERPLEXITY_VAULT_PASSPHRASE=" then
            return line:sub(29)
        end
    end
    
    exit_with_error("✗ no PERPLEXITY_VAULT_PASSPHRASE in daemon env", 1)
end

local function main()
    local HERE = posix.dirname(arg[0])
    local CFG = get_env_var("PERPLEXITY_CONFIG_DIR") or os.getenv("HOME") .. "/.perplexity-mcp"
    local PROFILE = get_env_var("PERPLEXITY_PROFILE") or "codespace"
    local COOKIE_FILE = arg[1] or os.getenv("HOME") .. "/pplx-cookies.txt"
    
    if file_size(COOKIE_FILE) == 0 then
        exit_with_error("✗ Cookie file empty/missing: " .. COOKIE_FILE .. "\n" ..
                       "  Export __Secure-next-auth.session-token from your local browser\n" ..
                       "  (DevTools → Application → Cookies → www.perplexity.ai) into that file.", 1)
    end
    
    -- 1. ensure the extension daemon has a usable browser (idempotent)
    os.execute("bash \"" .. HERE .. "/pplx-setup.sh\"")
    
    -- 2. daemon pid + vault passphrase
    local LOCK = CFG .. "/daemon.lock"
    local pid = get_daemon_pid(LOCK)
    local pass = get_daemon_passphrase(pid)
    
    -- 3. locate the perplexity-user-mcp dist
    local DIST = find_npm_dist()
    if not DIST then
        exit_with_error("✗ failed to find perplexity-user-mcp dist", 1)
    end
    
    -- 4. inject
    os.setenv("PERPLEXITY_VAULT_PASSPHRASE", pass)
    os.setenv("PERPLEXITY_CONFIG_DIR", CFG)
    os.setenv("PERPLEXITY_PROFILE", PROFILE)
    os.setenv("PPLX_DIST", DIST)
    os.execute("node \"" .. HERE .. "/pplx-inject.mjs\" \"" .. COOKIE_FILE .. "\"")
    
    -- 5. trigger daemon reinit
    local reinit_file = CFG .. "/profiles/" .. PROFILE .. "/.reinit"
    write_file(reinit_file, tostring(os.time()))
    print("→ reinit triggered, waiting for daemon...")
    
    -- 6. verify
    local stat_file = CFG .. "/profiles/" .. PROFILE .. "/daemon-status.json"
    for i = 1, 20 do
        posix.sleep(1.5)
        
        if file_exists(stat_file) then
            local content = read_file(stat_file)
            if content then
                local ok, data = pcall(json_parse, content)
                if ok and data then
                    local auth = data.authenticated
                    local tier = data.tier
                    if auth == true then
                        print("✅ authenticated — tier: " .. tostring(tier))
                        os.exit(0)
                    end
                end
            end
        end
    end
    
    print("⚠️  not authenticated yet. Check: tail -20 " .. CFG .. "/daemon.log")
    os.exit(1)
end

main()
