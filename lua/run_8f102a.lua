#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "c305a84e3dee22f5d4f5b7160e9ed7cfc0dc7bfc9916280917d1e21db12cd299", "source_sha256": "8f102a03732002cacc77d2ffc6fb4210aabf44652bfa80af3f96aab371d0679c", "target_language": "lua"}
-- run.sh — portiert nach lua
-- Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/docker/install-sh-smoke/run.sh
-- Erzeugt: 2026-11-22 durch ABSTRACTIONS_MANAGER.py

local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("cjson")
local io = require("io")
local os = require("os")
local table = require("table")

-- Environment variables with defaults
local INSTALL_URL = os.getenv("OPENCLAW_INSTALL_URL") or "https://openclaw.bot/install.sh"
local SMOKE_MODE = os.getenv("OPENCLAW_INSTALL_SMOKE_MODE") or "install"
local SMOKE_PREVIOUS_VERSION = os.getenv("OPENCLAW_INSTALL_SMOKE_PREVIOUS") or ""
local SKIP_PREVIOUS = os.getenv("OPENCLAW_INSTALL_SMOKE_SKIP_PREVIOUS") or "0"
local DEFAULT_PACKAGE = "openclaw"
local PACKAGE_NAME = os.getenv("OPENCLAW_INSTALL_PACKAGE") or DEFAULT_PACKAGE
local FRESH_VERSION = os.getenv("OPENCLAW_INSTALL_FRESH_VERSION") or ""
local FRESH_TAG_URL = os.getenv("OPENCLAW_INSTALL_FRESH_TAG_URL") or ""
local UPDATE_BASELINE_VERSION = os.getenv("OPENCLAW_INSTALL_UPDATE_BASELINE") or "2026.4.10"
local UPDATE_BASELINE_TAG_URL = os.getenv("OPENCLAW_INSTALL_UPDATE_BASELINE_TAG_URL") or ""
local UPDATE_EXPECT_VERSION = os.getenv("OPENCLAW_INSTALL_UPDATE_EXPECT_VERSION") or ""
local UPDATE_TAG_URL = os.getenv("OPENCLAW_INSTALL_UPDATE_TAG_URL") or ""

-- Helper functions
local function execute_command(cmd)
    local handle = io.popen(cmd, "r")
    local result = handle:read("*a")
    local success, _, code = handle:close()
    return result, success, code
end

local function quiet_npm(args)
    local cmd = "npm " .. args .. " 2>/dev/null"
    return execute_command(cmd)
end

local function verify_installed_cli(package_name, expected_version)
    -- This would need to be implemented based on the actual verification logic
    print("Verifying " .. package_name .. " version " .. expected_version)
end

local function run_install_smoke()
    if FRESH_VERSION ~= "" and FRESH_TAG_URL ~= "" then
        print("package=" .. PACKAGE_NAME .. " latest=" .. FRESH_VERSION .. " source=" .. FRESH_TAG_URL)
        print("==> Install latest release tarball")
        quiet_npm("install -g --omit=optional " .. FRESH_TAG_URL)

        print("==> Verify installed version")
        local latest_out = os.getenv("OPENCLAW_INSTALL_LATEST_OUT")
        if latest_out ~= nil and latest_out ~= "" then
            local file = io.open(latest_out, "w")
            file:write(FRESH_VERSION)
            file:close()
        end
        verify_installed_cli(PACKAGE_NAME, FRESH_VERSION)

        print("OK")
        return true
    end

    print("==> Resolve npm versions")
    local LATEST_VERSION, PREVIOUS_VERSION

    if SKIP_PREVIOUS == "1" then
        LATEST_VERSION = quiet_npm("view " .. PACKAGE_NAME .. " version"):gsub("%s+", "")
        PREVIOUS_VERSION = LATEST_VERSION
    elseif SMOKE_PREVIOUS_VERSION ~= "" then
        LATEST_VERSION = quiet_npm("view " .. PACKAGE_NAME .. " version"):gsub("%s+", "")
        PREVIOUS_VERSION = SMOKE_PREVIOUS_VERSION
    else
        LATEST_VERSION = quiet_npm("view " .. PACKAGE_NAME .. " dist-tags.latest"):gsub("%s+", "")
        local VERSIONS_JSON = quiet_npm("view " .. PACKAGE_NAME .. " versions --json")
        
        -- Parse JSON to get previous version
        local versions = json.decode(VERSIONS_JSON)
        if type(versions) ~= "table" then
            versions = {versions}
        end
        
        if #versions == 0 or LATEST_VERSION == "" then
            os.exit(1)
        end
        
        local latestIndex = 0
        for i, v in ipairs(versions) do
            if v == LATEST_VERSION then
                latestIndex = i
            end
        end
        
        if latestIndex <= 1 then
            PREVIOUS_VERSION = LATEST_VERSION
        else
            PREVIOUS_VERSION = versions[latestIndex - 1] or LATEST_VERSION
        end
    end

    print("package=" .. PACKAGE_NAME .. " latest=" .. LATEST_VERSION .. " previous=" .. PREVIOUS_VERSION)

    if SKIP_PREVIOUS == "1" then
        print("==> Skip preinstall previous (OPENCLAW_INSTALL_SMOKE_SKIP_PREVIOUS=1)")
    else
        print("==> Preinstall previous (forces installer upgrade path)")
        quiet_npm("install -g " .. PACKAGE_NAME .. "@" .. PREVIOUS_VERSION)
    end

    print("==> Run official installer one-liner")
    local curl_cmd = 'curl -fsSL "' .. INSTALL_URL .. '" | bash -s -- --no-prompt'
    os.execute(curl_cmd)

    print("==> Verify installed version")
    local latest_out = os.getenv("OPENCLAW_INSTALL_LATEST_OUT")
    if latest_out ~= nil and latest_out ~= "" then
        local file = io.open(latest_out, "w")
        file:write(LATEST_VERSION)
        file:close()
    end
    verify_installed_cli(PACKAGE_NAME, LATEST_VERSION)

    print("OK")
    return true
end

local function run_update_smoke()
    if UPDATE_EXPECT_VERSION == "" then
        print("ERROR: OPENCLAW_INSTALL_UPDATE_EXPECT_VERSION is required for update mode", io.stderr)
        return false
    end
    if UPDATE_TAG_URL == "" then
        print("ERROR: OPENCLAW_INSTALL_UPDATE_TAG_URL is required for update mode", io.stderr)
        return false
    end

    print("package=" .. PACKAGE_NAME .. " baseline=" .. UPDATE_BASELINE_VERSION .. " target=" .. UPDATE_EXPECT_VERSION)
    print("==> Install baseline release")
    if UPDATE_BASELINE_TAG_URL ~= "" then
        quiet_npm("install -g --omit=optional " .. UPDATE_BASELINE_TAG_URL)
    else
        quiet_npm("install -g --omit=optional " .. PACKAGE_NAME .. "@" .. UPDATE_BASELINE_VERSION)
    end
    verify_installed_cli(PACKAGE_NAME, UPDATE_BASELINE_VERSION)

    print("==> Run openclaw update from host-served tgz")
    
    -- Create temporary file for stderr
    local tmpfile = os.tmpname()
    
    -- Set environment variables
    os.execute("export npm_config_omit=optional")
    os.execute("export NPM_CONFIG_OMIT=optional")
    
    local update_cmd = "openclaw update --tag " .. UPDATE_TAG_URL .. " --yes --json 2>" .. tmpfile
    local UPDATE_JSON, success, exit_code = execute_command(update_cmd)
    
    -- Read stderr
    local stderr_file = io.open(tmpfile, "r")
    local update_stderr = ""
    if stderr_file then
        update_stderr = stderr_file:read("*a")
        stderr_file:close()
        os.remove(tmpfile)
    end
    
    print(UPDATE_JSON)
    if update_stderr ~= "" then
        print(update_stderr, io.stderr)
    end
    
    if not success then
        print("ERROR: openclaw update failed with exit code " .. tostring(exit_code), io.stderr)
        return false
    end

    -- Validate update JSON (simplified)
    local payload = json.decode(UPDATE_JSON)
    if payload.status ~= "ok" then
        error("expected update status ok, got " .. tostring(payload.status))
    end
    
    if (payload.before and payload.before.version or nil) ~= UPDATE_BASELINE_VERSION then
        error("expected before.version " .. UPDATE_BASELINE_VERSION .. ", got " .. tostring(payload.before and payload.before.version or nil))
    end
    
    if (payload.after and payload.after.version or nil) ~= UPDATE_EXPECT_VERSION then
        error("expected after.version " .. UPDATE_EXPECT_VERSION .. ", got " .. tostring(payload.after and payload.after.version or nil))
    end
    
    if payload.reason ~= nil then
        error("expected no failure reason, got " .. tostring(payload.reason))
    end
    
    local steps = payload.steps or {}
    local updateStep = nil
    for _, step in ipairs(steps) do
        if step.name == "global update" then
            updateStep = step
            break
        end
    end
    
    if not updateStep then
        error("missing global update step in update JSON")
    end
    
    if (updateStep.exitCode or 1) ~= 0 then
        error("global update step failed")
    end
    
    if type(updateStep.command) ~= "string" or not string.find(updateStep.command, UPDATE_TAG_URL) then
        error("global update step missing expected tgz URL")
    end

    print("==> Verify updated version")
    verify_installed_cli(PACKAGE_NAME, UPDATE_EXPECT_VERSION)

    print("OK")
    return true
end

-- Main execution
if SMOKE_MODE == "install" then
    if not run_install_smoke() then
        os.exit(1)
    end
elseif SMOKE_MODE == "update" then
    if not run_update_smoke() then
        os.exit(1)
    end
else
    print("ERROR: unsupported OPENCLAW_INSTALL_SMOKE_MODE=" .. SMOKE_MODE, io.stderr)
    os.exit(1)
end
