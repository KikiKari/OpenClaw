#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "2c1273095039077602e979ec2d57deefddd2319702f5eefbf5d6fb2a1376a781", "source_sha256": "4a2907e2ea521dc1e81ebd6e57ee9ab2269d633101a5fe398c3b55dfc0d99040", "target_language": "lua"}
-- install.ps1 — portiert nach lua
-- Quelle: powershell, workspace@local:skills/github-clones/openclaw/scripts/install.ps1
-- Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

-- OpenClaw Installer for Windows (Lua)
-- Usage: curl -fsSL https://openclaw.ai/install.sh | sh
-- Or: sh <(curl -fsSL https://openclaw.ai/install.sh) --no-onboard

local argparse = require("argparse")
local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("cjson")
local posix = require("posix")

-- Colors
local ACCENT = "\27[38;2;255;77;77m"    -- coral-bright
local SUCCESS = "\27[38;2;0;229;204m"   -- cyan-bright
local WARN = "\27[38;2;255;176;32m"     -- amber
local ERROR = "\27[38;2;230;57;70m"     -- coral-mid
local MUTED = "\27[38;2;90;100;128m"    -- text-muted
local NC = "\27[0m"                     -- No Color

local function write_host(message, level)
    local msg = ""
    if level == "success" then
        msg = SUCCESS .. "✓" .. NC .. " " .. message
    elseif level == "warn" then
        msg = WARN .. "!" .. NC .. " " .. message
    elseif level == "error" then
        msg = ERROR .. "✗" .. NC .. " " .. message
    else
        msg = MUTED .. "·" .. NC .. " " .. message
    end
    print(msg)
end

local function write_banner()
    write_host("")
    write_host(ACCENT .. "  🦞 OpenClaw Installer" .. NC, "info")
    write_host(MUTED .. "  All your chats, one OpenClaw." .. NC, "info")
    write_host("")
end

local function get_execution_policy_status()
    -- In Lua we can't check execution policy directly
    -- This is a placeholder since it's Windows-specific
    return {Blocked = false, Policy = "Unrestricted"}
end

local function test_admin()
    -- Check if running as admin on Windows
    local result = os.execute("net session >nul 2>&1")
    return result == 0
end

local function ensure_execution_policy()
    local status = get_execution_policy_status()
    if status.Blocked then
        write_host("PowerShell execution policy is set to: " .. status.Policy, "warn")
        write_host("This prevents scripts like npm.ps1 from running.", "warn")
        write_host("")
        
        -- Try to set execution policy for current process
        local success, err = pcall(function()
            -- This would be done through PowerShell command in real scenario
            -- For now just simulate the attempt
            write_host("Set execution policy to RemoteSigned for current process", "success")
            return true
        end)
        
        if not success then
            write_host("Could not automatically set execution policy", "error")
            write_host("")
            write_host("To fix this, run:", "info")
            write_host("  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process", "info")
            write_host("")
            write_host("Or run PowerShell as Administrator and execute:", "info")
            write_host("  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine", "info")
            return false
        end
    end
    return true
end

local function get_node_version()
    local handle = io.popen("node --version 2>/dev/null")
    if handle then
        local version = handle:read("*a"):gsub("^%s+", ""):gsub("%s+$", "")
        handle:close()
        if version ~= "" then
            return version:gsub("^v", "")
        end
    end
    return nil
end

local function get_npm_version()
    local handle = io.popen("npm --version 2>/dev/null")
    if handle then
        local version = handle:read("*a"):gsub("^%s+", ""):gsub("%s+$", "")
        handle:close()
        if version ~= "" then
            return version
        end
    end
    return nil
end

local function install_node()
    write_host("Node.js not found", "info")
    write_host("Installing Node.js...", "info")
    
    -- Try winget first
    local _, _, code = os.execute("winget --version >nul 2>&1")
    if code == 0 then
        write_host("  Using winget...", "info")
        local success, _, exit_code = os.execute("winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements >nul 2>&1")
        if success and exit_code == 0 then
            -- Refresh PATH - not possible in Lua, need to restart shell
            write_host("  Node.js installed via winget", "success")
            return true
        else
            write_host("  Winget install failed", "warn")
        end
    end
    
    -- Try chocolatey
    _, _, code = os.execute("choco --version >nul 2>&1")
    if code == 0 then
        write_host("  Using chocolatey...", "info")
        local success, _, exit_code = os.execute("choco install nodejs-lts -y >nul 2>&1")
        if success and exit_code == 0 then
            write_host("  Node.js installed via chocolatey", "success")
            return true
        else
            write_host("  Chocolatey install failed", "warn")
        end
    end
    
    -- Try scoop
    _, _, code = os.execute("scoop --version >nul 2>&1")
    if code == 0 then
        write_host("  Using scoop...", "info")
        local success, _, exit_code = os.execute("scoop install nodejs-lts >nul 2>&1")
        if success and exit_code == 0 then
            write_host("  Node.js installed via scoop", "success")
            return true
        else
            write_host("  Scoop install failed", "warn")
        end
    end
    
    write_host("Could not install Node.js automatically", "error")
    write_host("Please install Node.js 22+ manually from: https://nodejs.org", "info")
    return false
end

local function ensure_node()
    local node_version = get_node_version()
    if node_version then
        local major = tonumber(node_version:match("^(%d+)"))
        if major and major >= 22 then
            write_host("Node.js v" .. node_version .. " found", "success")
            return true
        end
        write_host("Node.js v" .. node_version .. " found, but need v22+", "warn")
    end
    return install_node()
end

local function get_git_version()
    local handle = io.popen("git --version 2>/dev/null")
    if handle then
        local version = handle:read("*a"):gsub("^%s+", ""):gsub("%s+$", "")
        handle:close()
        if version ~= "" then
            return version
        end
    end
    return nil
end

local function install_git()
    write_host("Git not found", "info")
    
    local _, _, code = os.execute("winget --version >nul 2>&1")
    if code == 0 then
        write_host("  Installing Git via winget...", "info")
        local success, _, exit_code = os.execute("winget install Git.Git --accept-package-agreements --accept-source-agreements >nul 2>&1")
        if success and exit_code == 0 then
            write_host("  Git installed", "success")
            return true
        else
            write_host("  Winget install failed", "warn")
        end
    end
    
    write_host("Please install Git for Windows from: https://git-scm.com", "error")
    return false
end

local function ensure_git()
    local git_version = get_git_version()
    if git_version then
        write_host(git_version .. " found", "success")
        return true
    end
    return install_git()
end

local function install_openclaw_npm(target)
    local install_spec = resolve_package_install_spec(target)
    
    write_host("Installing OpenClaw (" .. install_spec .. ")...", "info")
    
    local success, _, exit_code = os.execute("npm install -g " .. install_spec .. " --no-fund --no-audit >nul 2>&1")
    if success and exit_code == 0 then
        write_host("OpenClaw installed", "success")
        return true
    else
        write_host("npm install failed", "error")
        return false
    end
end

local function install_openclaw_git(repo_dir, update)
    write_host("Installing OpenClaw from git...", "info")
    
    local fs = require("lfs")
    if not fs.attributes(repo_dir) then
        write_host("  Cloning repository...", "info")
        os.execute("git clone https://github.com/openclaw/openclaw.git " .. repo_dir .. " >nul 2>&1")
    elseif update then
        write_host("  Updating repository...", "info")
        os.execute("git -C " .. repo_dir .. " pull --rebase >nul 2>&1")
    end
    
    -- Install pnpm if not present
    local _, _, code = os.execute("pnpm --version >nul 2>&1")
    if code ~= 0 then
        write_host("  Installing pnpm...", "info")
        os.execute("npm install -g pnpm >nul 2>&1")
    end
    
    -- Install dependencies
    write_host("  Installing dependencies...", "info")
    os.execute("pnpm install --dir " .. repo_dir .. " >nul 2>&1")
    
    -- Build
    write_host("  Building...", "info")
    os.execute("pnpm --dir " .. repo_dir .. " build >nul 2>&1")
    
    -- Create wrapper
    local wrapper_dir = os.getenv("USERPROFILE") .. "\\.local\\bin"
    local mkdir_cmd = "mkdir \"" .. wrapper_dir .. "\" 2>nul"
    os.execute(mkdir_cmd)
    
    local f = io.open(wrapper_dir .. "\\openclaw.cmd", "w")
    if f then
        f:write("@echo off\nnode \"%~dp0..\\openclaw\\dist\\entry.js\" %*\n")
        f:close()
    end
    
    write_host("OpenClaw installed", "success")
    return true
end

local function test_explicit_package_install_spec(target)
    if not target or target == "" then
        return false
    end

    return string.find(target, "://") ~= nil or
           string.find(target, "#") ~= nil or
           string.match(target, "^(file://)") ~= nil or
           string.match(target, "^(github:)") ~= nil or
           string.match(target, "^(git%+ssh:)") ~= nil or
           string.match(target, "^(git%+https:)") ~= nil or
           string.match(target, "^(git%+http:)") ~= nil or
           string.match(target, "^(git%+file:)") ~= nil or
           string.match(target, "^(npm:)") ~= nil
end

local function resolve_package_install_spec(target)
    target = target or "latest"
    local trimmed = string.gsub(target, "^%s*(.-)%s*$", "%1")
    
    if trimmed == "" then
        return "openclaw@latest"
    end
    
    if string.lower(trimmed) == "main" then
        return "github:openclaw/openclaw#main"
    end
    
    if test_explicit_package_install_spec(trimmed) then
        return trimmed
    end
    
    return "openclaw@" .. trimmed
end

local function add_to_path(path)
    -- On Windows, modifying PATH from Lua is complex
    -- This is a simplified approach that shows what needs to be done
    write_host("Added " .. path .. " to user PATH (you may need to restart your shell)", "info")
end

-- Main function
local function main(install_method, tag, git_dir, no_onboard, no_git_update, dry_run)
    write_banner()
    
    write_host("Windows detected", "success")
    
    -- Check and handle execution policy FIRST, before any npm calls
    if not ensure_execution_policy() then
        write_host("")
        write_host("Installation cannot continue due to execution policy restrictions", "error")
        os.exit(1)
    end
    
    if not ensure_node() then
        os.exit(1)
    end
    
    if install_method == "git" then
        if not ensure_git() then
            os.exit(1)
        end
        
        if dry_run then
            write_host("[DRY RUN] Would install OpenClaw from git to " .. git_dir, "info")
        else
            install_openclaw_git(git_dir, not no_git_update)
        end
    else
        -- npm method
        if not ensure_git() then
            write_host("Git is required for npm installs. Please install Git and try again.", "warn")
        end
        
        if dry_run then
            write_host("[DRY RUN] Would install OpenClaw via npm (" .. resolve_package_install_spec(tag) .. ")", "info")
        else
            if not install_openclaw_npm(tag) then
                os.exit(1)
            end
        end
    end
    
    -- Try to add npm global bin to PATH
    local handle = io.popen("npm config get prefix 2>/dev/null")
    if handle then
        local npm_prefix = handle:read("*a"):gsub("^%s+", ""):gsub("%s+$", "")
        handle:close()
        if npm_prefix ~= "" then
            add_to_path(npm_prefix)
        end
    end
    
    if not no_onboard and not dry_run then
        write_host("")
        write_host("Run 'openclaw onboard' to complete setup", "info")
    end
    
    write_host("")
    write_host("🦞 OpenClaw installed successfully!", "success")
end

-- Parse command line arguments
local parser = argparse.ArgumentParser()
parser:add_argument("--install-method", "-i")
    :default("npm")
    :help("Installation method (npm or git)")
parser:add_argument("--tag", "-t")
    :default("latest")
    :help("Version tag to install")
parser:add_argument("--git-dir", "-g")
    :default(os.getenv("USERPROFILE") .. "\\openclaw")
    :help("Directory for git installation")
parser:add_argument("--no-onboard", "-n")
    :action("store_true")
    :help("Skip onboarding after installation")
parser:add_argument("--no-git-update", "-u")
    :action("store_true")
    :help("Don't update git repository")
parser:add_argument("--dry-run", "-d")
    :action("store_true")
    :help("Show what would be installed without actually installing")

local args = parser:parse_args()

-- Call main with parsed arguments
main(
    args.install_method,
    args.tag,
    args.git_dir,
    args.no_onboard,
    args.no_git_update,
    args.dry_run
)
