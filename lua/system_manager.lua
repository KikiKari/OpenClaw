#!/usr/bin/env lua
-- abstraction-provenance: {"artifact_sha256": "2040caa98cc6e8a92207a306da0e8e49dbbd42ce2d21ea8d5c6a626660778177", "source_sha256": "195cda6929663d9049e84b5a94d9261e0632f316438d3dd21c0f4282262a559b", "target_language": "lua"}
-- system_manager.py — portiert nach lua
-- Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/system_manager.py
-- auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/system_manager.py
-- auch in: workspace@local:git/skills/scripting-utils/scripts/system_manager.py
-- auch in: workspace@local:skills/scripting-utils/scripts/system_manager.py
-- Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

--[[
System management abstraction for Ubuntu and CentOS 8.
Provides command matrix for packages, services, networking.
]]

local SystemManager = {}
SystemManager.__index = SystemManager

-- Command matrix for Ubuntu vs CentOS 8
SystemManager.COMMANDS = {
    install = {
        ubuntu = "apt-get install -y {package}",
        centos = "dnf install -y {package}",
        description = "Install a package"
    },
    remove = {
        ubuntu = "apt-get remove -y {package}",
        centos = "dnf remove -y {package}",
        description = "Remove a package"
    },
    update = {
        ubuntu = "apt-get update && apt-get upgrade -y",
        centos = "dnf update -y",
        description = "Update all packages"
    },
    search = {
        ubuntu = "apt-cache search {package}",
        centos = "dnf search {package}",
        description = "Search for package"
    },
    service_start = {
        ubuntu = "systemctl start {service}",
        centos = "systemctl start {service}",
        description = "Start a service"
    },
    service_stop = {
        ubuntu = "systemctl stop {service}",
        centos = "systemctl stop {service}",
        description = "Stop a service"
    },
    service_enable = {
        ubuntu = "systemctl enable {service}",
        centos = "systemctl enable {service}",
        description = "Enable service at boot"
    },
    service_status = {
        ubuntu = "systemctl status {service}",
        centos = "systemctl status {service}",
        description = "Check service status"
    },
    firewall_allow = {
        ubuntu = "ufw allow {port}/{proto}",
        centos = "firewall-cmd --add-port={port}/{proto} --permanent && firewall-cmd --reload",
        description = "Open firewall port"
    },
    firewall_status = {
        ubuntu = "ufw status",
        centos = "firewall-cmd --list-all",
        description = "Check firewall status"
    },
    add_user = {
        ubuntu = "adduser --disabled-password --gecos '' {username}",
        centos = "adduser {username}",
        description = "Add system user"
    },
    add_to_sudo = {
        ubuntu = "usermod -aG sudo {username}",
        centos = "usermod -aG wheel {username}",
        description = "Add user to sudoers"
    },
}

-- Package name mappings (same software, different package names)
SystemManager.PACKAGE_MAP = {
    apache = {ubuntu = "apache2", centos = "httpd"},
    mysql = {ubuntu = "mysql-server", centos = "mysql-server"},
    php = {ubuntu = "php", centos = "php"},
    nodejs = {ubuntu = "nodejs", centos = "nodejs"},
    nginx = {ubuntu = "nginx", centos = "nginx"},
}

function SystemManager:new(os_type)
    local obj = {
        os = string.lower(os_type)
    }
    
    if obj.os ~= "ubuntu" and obj.os ~= "centos" then
        error("Unsupported OS: " .. os_type)
    end
    
    setmetatable(obj, SystemManager)
    return obj
end

function SystemManager:get_command(action, kwargs)
    -- Get the command for an action
    local cmd_template = self.COMMANDS[action]
    if not cmd_template then
        error("Unknown action: " .. action)
    end
    
    -- Get OS-specific command
    local cmd
    if self.os == "ubuntu" then
        cmd = cmd_template.ubuntu
    else
        cmd = cmd_template.centos
    end
    
    -- Format with arguments
    if kwargs then
        for key, value in pairs(kwargs) do
            cmd = string.gsub(cmd, "{" .. key .. "}", value)
        end
    end
    
    return cmd
end

function SystemManager:get_package_name(software)
    -- Get correct package name for OS
    local mapping = self.PACKAGE_MAP[string.lower(software)] or {}
    return mapping[self.os] or software
end

function SystemManager:detect_os()
    -- Auto-detect OS type
    local success, file = pcall(io.open, "/etc/os-release", "r")
    if success and file then
        local content = file:read("*a"):lower()
        file:close()
        
        if string.find(content, "ubuntu") or string.find(content, "debian") then
            return "ubuntu"
        elseif string.find(content, "centos") or string.find(content, "rhel") or string.find(content, "fedora") then
            return "centos"
        end
    end
    return nil
end

function SystemManager:generate_script(actions)
    -- Generate a shell script for multiple actions
    local lines = {"#!/bin/bash", "set -e", ""}
    
    for _, action in ipairs(actions) do
        local cmd_name = action.action
        table.remove(action, 1) -- Remove 'action' from the table
        
        table.insert(lines, "# " .. self.COMMANDS[cmd_name].description)
        table.insert(lines, self:get_command(cmd_name, action))
        table.insert(lines, "")
    end
    
    return table.concat(lines, "\n")
end

function string.split(str, sep)
    local fields = {}
    local pattern = string.format("([^%s]+)", sep)
    str:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

function main()
    -- Simple argument parsing
    local args = {}
    local i = 1
    while i <= #arg do
        if arg[i] == "--os" and arg[i+1] then
            args.os = arg[i+1]
            i = i + 2
        elseif arg[i] == "--action" and arg[i+1] then
            args.action = arg[i+1]
            i = i + 2
        elseif arg[i] == "--package" and arg[i+1] then
            args.package = arg[i+1]
            i = i + 2
        elseif arg[i] == "--service" and arg[i+1] then
            args.service = arg[i+1]
            i = i + 2
        elseif arg[i] == "--port" and arg[i+1] then
            args.port = arg[i+1]
            i = i + 2
        elseif arg[i] == "--proto" and arg[i+1] then
            args.proto = arg[i+1]
            i = i + 2
        elseif arg[i] == "--username" and arg[i+1] then
            args.username = arg[i+1]
            i = i + 2
        elseif arg[i] == "--generate" then
            args.generate = true
            i = i + 1
        else
            i = i + 1
        end
    end
    
    if not args.os or not args.action then
        print("Error: --os and --action are required")
        return
    end
    
    local manager = SystemManager:new(args.os)
    
    -- Build kwargs from args
    local kwargs = {}
    if args.package then
        kwargs.package = manager:get_package_name(args.package)
    end
    if args.service then
        kwargs.service = args.service
    end
    if args.port then
        kwargs.port = args.port
        kwargs.proto = args.proto or "tcp"
    end
    if args.username then
        kwargs.username = args.username
    end
    
    local cmd = manager:get_command(args.action, kwargs)
    
    if args.generate then
        print(cmd)
    else
        print("Executing: " .. cmd)
        -- os.execute(cmd)  -- Uncomment to actually execute
    end
end

if arg and #arg > 0 then
    main()
end

return SystemManager
