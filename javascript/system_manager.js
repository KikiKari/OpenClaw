#!/usr/bin/env node
// system_manager.py — portiert nach javascript
// Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/system_manager.py
// auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/system_manager.py
// Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

/**
 * System management abstraction for Ubuntu and CentOS 8.
 * Provides command matrix for packages, services, networking.
 */

const fs = require('fs');
const { spawnSync } = require('child_process');

class SystemCommand {
    constructor(ubuntu, centos, description) {
        this.ubuntu = ubuntu;
        this.centos = centos;
        this.description = description;
    }
}

class SystemManager {
    /**
     * Ubuntu vs CentOS 8 command matrix.
     */
    
    static COMMANDS = {
        "install": new SystemCommand(
            "apt-get install -y {package}",
            "dnf install -y {package}",
            "Install a package"
        ),
        "remove": new SystemCommand(
            "apt-get remove -y {package}",
            "dnf remove -y {package}",
            "Remove a package"
        ),
        "update": new SystemCommand(
            "apt-get update && apt-get upgrade -y",
            "dnf update -y",
            "Update all packages"
        ),
        "search": new SystemCommand(
            "apt-cache search {package}",
            "dnf search {package}",
            "Search for package"
        ),
        "service_start": new SystemCommand(
            "systemctl start {service}",
            "systemctl start {service}",
            "Start a service"
        ),
        "service_stop": new SystemCommand(
            "systemctl stop {service}",
            "systemctl stop {service}",
            "Stop a service"
        ),
        "service_enable": new SystemCommand(
            "systemctl enable {service}",
            "systemctl enable {service}",
            "Enable service at boot"
        ),
        "service_status": new SystemCommand(
            "systemctl status {service}",
            "systemctl status {service}",
            "Check service status"
        ),
        "firewall_allow": new SystemCommand(
            "ufw allow {port}/{proto}",
            "firewall-cmd --add-port={port}/{proto} --permanent && firewall-cmd --reload",
            "Open firewall port"
        ),
        "firewall_status": new SystemCommand(
            "ufw status",
            "firewall-cmd --list-all",
            "Check firewall status"
        ),
        "add_user": new SystemCommand(
            "adduser --disabled-password --gecos '' {username}",
            "adduser {username}",
            "Add system user"
        ),
        "add_to_sudo": new SystemCommand(
            "usermod -aG sudo {username}",
            "usermod -aG wheel {username}",
            "Add user to sudoers"
        ),
    };
    
    // Package name mappings (same software, different package names)
    static PACKAGE_MAP = {
        "apache": {"ubuntu": "apache2", "centos": "httpd"},
        "mysql": {"ubuntu": "mysql-server", "centos": "mysql-server"},
        "php": {"ubuntu": "php", "centos": "php"},
        "nodejs": {"ubuntu": "nodejs", "centos": "nodejs"},
        "nginx": {"ubuntu": "nginx", "centos": "nginx"},
    };
    
    constructor(osType) {
        this.os = osType.toLowerCase();
        if (this.os !== "ubuntu" && this.os !== "centos") {
            throw new Error(`Unsupported OS: ${osType}`);
        }
    }
    
    /**
     * Get the command for an action.
     */
    getCommand(action, kwargs = {}) {
        const cmdTemplate = SystemManager.COMMANDS[action];
        if (!cmdTemplate) {
            throw new Error(`Unknown action: ${action}`);
        }
        
        // Get OS-specific command
        let cmd;
        if (this.os === "ubuntu") {
            cmd = cmdTemplate.ubuntu;
        } else {
            cmd = cmdTemplate.centos;
        }
        
        // Format with arguments
        for (const [key, value] of Object.entries(kwargs)) {
            cmd = cmd.replace(new RegExp(`{${key}}`, 'g'), value);
        }
        
        return cmd;
    }
    
    /**
     * Get correct package name for OS.
     */
    getPackageName(software) {
        const mapping = SystemManager.PACKAGE_MAP[software.toLowerCase()] || {};
        return mapping[this.os] || software;
    }
    
    /**
     * Auto-detect OS type.
     */
    detectOs() {
        try {
            const content = fs.readFileSync("/etc/os-release", 'utf8').toLowerCase();
            if (content.includes("ubuntu") || content.includes("debian")) {
                return "ubuntu";
            } else if (content.includes("centos") || content.includes("rhel") || content.includes("fedora")) {
                return "centos";
            }
        } catch (err) {
            // File not found or other error
        }
        return null;
    }
    
    /**
     * Generate a shell script for multiple actions.
     */
    generateScript(actions) {
        const lines = ["#!/bin/bash", "set -e", ""];
        
        for (const action of actions) {
            const cmdName = action.action;
            const actionParams = {...action};
            delete actionParams.action;
            
            lines.push(`# ${SystemManager.COMMANDS[cmdName].description}`);
            lines.push(this.getCommand(cmdName, actionParams));
            lines.push("");
        }
        
        return lines.join("\n");
    }
}

function main() {
    const args = process.argv.slice(2);
    const parsedArgs = {};
    
    for (let i = 0; i < args.length; i++) {
        const arg = args[i];
        if (arg.startsWith('--')) {
            const key = arg.substring(2);
            if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
                parsedArgs[key] = args[i + 1];
                i++;
            } else {
                parsedArgs[key] = true;
            }
        }
    }
    
    if (!parsedArgs.os || !parsedArgs.action) {
        console.error("Usage: node system_manager.js --os [ubuntu|centos] --action <action> [options]");
        process.exit(1);
    }
    
    const manager = new SystemManager(parsedArgs.os);
    
    // Build kwargs from args
    const kwargs = {};
    if (parsedArgs.package) {
        kwargs.package = manager.getPackageName(parsedArgs.package);
    }
    if (parsedArgs.service) {
        kwargs.service = parsedArgs.service;
    }
    if (parsedArgs.port) {
        kwargs.port = parsedArgs.port;
        kwargs.proto = parsedArgs.proto || "tcp";
    }
    if (parsedArgs.username) {
        kwargs.username = parsedArgs.username;
    }
    
    const cmd = manager.getCommand(parsedArgs.action, kwargs);
    
    if (parsedArgs.generate) {
        console.log(cmd);
    } else {
        console.log(`Executing: ${cmd}`);
        // To actually execute, uncomment the following:
        // const result = spawnSync(cmd, { shell: true, stdio: 'inherit' });
        // if (result.error) {
        //     console.error(result.error);
        //     process.exit(1);
        // }
    }
}

if (require.main === module) {
    main();
}

module.exports = { SystemManager };
