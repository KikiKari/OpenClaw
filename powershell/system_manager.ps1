#!/usr/bin/env pwsh
# system_manager.py — portiert nach powershell
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/system_manager.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/system_manager.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
System management abstraction for Ubuntu and CentOS 8.
Provides command matrix for packages, services, networking.
#>

class SystemCommand {
    [string]$Ubuntu
    [string]$Centos
    [string]$Description

    SystemCommand([string]$Ubuntu, [string]$Centos, [string]$Description) {
        $this.Ubuntu = $Ubuntu
        $this.Centos = $Centos
        $this.Description = $Description
    }
}

class SystemManager {
    <#
    .SYNOPSIS
    Ubuntu vs CentOS 8 command matrix.
    #>
    
    static [hashtable]$COMMANDS = @{
        "install" = [SystemCommand]::new(
            "apt-get install -y {package}",
            "dnf install -y {package}",
            "Install a package"
        )
        "remove" = [SystemCommand]::new(
            "apt-get remove -y {package}",
            "dnf remove -y {package}",
            "Remove a package"
        )
        "update" = [SystemCommand]::new(
            "apt-get update && apt-get upgrade -y",
            "dnf update -y",
            "Update all packages"
        )
        "search" = [SystemCommand]::new(
            "apt-cache search {package}",
            "dnf search {package}",
            "Search for package"
        )
        "service_start" = [SystemCommand]::new(
            "systemctl start {service}",
            "systemctl start {service}",
            "Start a service"
        )
        "service_stop" = [SystemCommand]::new(
            "systemctl stop {service}",
            "systemctl stop {service}",
            "Stop a service"
        )
        "service_enable" = [SystemCommand]::new(
            "systemctl enable {service}",
            "systemctl enable {service}",
            "Enable service at boot"
        )
        "service_status" = [SystemCommand]::new(
            "systemctl status {service}",
            "systemctl status {service}",
            "Check service status"
        )
        "firewall_allow" = [SystemCommand]::new(
            "ufw allow {port}/{proto}",
            "firewall-cmd --add-port={port}/{proto} --permanent && firewall-cmd --reload",
            "Open firewall port"
        )
        "firewall_status" = [SystemCommand]::new(
            "ufw status",
            "firewall-cmd --list-all",
            "Check firewall status"
        )
        "add_user" = [SystemCommand]::new(
            "adduser --disabled-password --gecos '' {username}",
            "adduser {username}",
            "Add system user"
        )
        "add_to_sudo" = [SystemCommand]::new(
            "usermod -aG sudo {username}",
            "usermod -aG wheel {username}",
            "Add user to sudoers"
        )
    }
    
    # Package name mappings (same software, different package names)
    static [hashtable]$PACKAGE_MAP = @{
        "apache" = @{ "ubuntu" = "apache2"; "centos" = "httpd" }
        "mysql" = @{ "ubuntu" = "mysql-server"; "centos" = "mysql-server" }
        "php" = @{ "ubuntu" = "php"; "centos" = "php" }
        "nodejs" = @{ "ubuntu" = "nodejs"; "centos" = "nodejs" }
        "nginx" = @{ "ubuntu" = "nginx"; "centos" = "nginx" }
    }
    
    [string]$OS
    
    SystemManager([string]$OSType) {
        $this.OS = $OSType.ToLower()
        if ($this.OS -notin @("ubuntu", "centos")) {
            throw "Unsupported OS: $OSType"
        }
    }
    
    [string] GetCommand([string]$Action, [hashtable]$Parameters) {
        <#
        .SYNOPSIS
        Get the command for an action.
        #>
        $CmdTemplate = [SystemManager]::COMMANDS[$Action]
        if (-not $CmdTemplate) {
            throw "Unknown action: $Action"
        }
        
        # Get OS-specific command
        $Cmd = ""
        if ($this.OS -eq "ubuntu") {
            $Cmd = $CmdTemplate.Ubuntu
        } else {
            $Cmd = $CmdTemplate.Centos
        }
        
        # Format with arguments
        foreach ($Key in $Parameters.Keys) {
            $Cmd = $Cmd -replace "{$Key}", $Parameters[$Key]
        }
        
        return $Cmd
    }
    
    [string] GetPackageName([string]$Software) {
        <#
        .SYNOPSIS
        Get correct package name for OS.
        #>
        $Mapping = [SystemManager]::PACKAGE_MAP[$Software.ToLower()]
        if ($Mapping -and $Mapping.ContainsKey($this.OS)) {
            return $Mapping[$this.OS]
        }
        return $Software
    }
    
    [string] DetectOS() {
        <#
        .SYNOPSIS
        Auto-detect OS type.
        #>
        try {
            $Content = Get-Content "/etc/os-release" -Raw
            $LowerContent = $Content.ToLower()
            if ($LowerContent.Contains("ubuntu") -or $LowerContent.Contains("debian")) {
                return "ubuntu"
            } elseif ($LowerContent.Contains("centos") -or $LowerContent.Contains("rhel") -or $LowerContent.Contains("fedora")) {
                return "centos"
            }
        } catch {
            # Ignore file not found error
        }
        return $null
    }
    
    [string] GenerateScript([array]$Actions) {
        <#
        .SYNOPSIS
        Generate a shell script for multiple actions.
        #>
        $Lines = @("#!/bin/bash", "set -e", "")
        
        foreach ($Action in $Actions) {
            $ActionName = $Action.action
            $Action.Remove("action")
            
            $Description = [SystemManager]::COMMANDS[$ActionName].Description
            $Lines += "# $Description"
            
            $Parameters = @{}
            foreach ($Key in $Action.Keys) {
                $Parameters[$Key] = $Action[$Key]
            }
            
            $Cmd = $this.GetCommand($ActionName, $Parameters)
            $Lines += $Cmd
            $Lines += ""
        }
        
        return ($Lines -join "`n")
    }
}

function Main {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("ubuntu", "centos")]
        [string]$OS,
        
        [Parameter(Mandatory=$true)]
        [string]$Action,
        
        [string]$Package,
        
        [string]$Service,
        
        [string]$Port,
        
        [string]$Proto = "tcp",
        
        [string]$Username,
        
        [switch]$Generate
    )
    
    $Manager = [SystemManager]::new($OS)
    
    # Build parameters from args
    $Parameters = @{}
    if ($Package) {
        $Parameters["package"] = $Manager.GetPackageName($Package)
    }
    if ($Service) {
        $Parameters["service"] = $Service
    }
    if ($Port) {
        $Parameters["port"] = $Port
        $Parameters["proto"] = $Proto
    }
    if ($Username) {
        $Parameters["username"] = $Username
    }
    
    $Cmd = $Manager.GetCommand($Action, $Parameters)
    
    if ($Generate) {
        Write-Output $Cmd
    } else {
        Write-Host "Executing: $Cmd"
        # Start-Process bash -ArgumentList "-c", $Cmd  # Uncomment to actually execute
    }
}

# Parse command line arguments
$ParamDictionary = @{}
foreach ($Arg in $args) {
    if ($Arg -match "^--(.+?)=(.+)$") {
        $ParamDictionary[$matches[1]] = $matches[2]
    } elseif ($Arg -match "^--(.+)$") {
        $ParamDictionary[$matches[1]] = $true
    }
}

# Convert dictionary to parameters for Main function
$BoundParameters = @{}
if ($ParamDictionary.ContainsKey("os")) { $BoundParameters["OS"] = $ParamDictionary["os"] }
if ($ParamDictionary.ContainsKey("action")) { $BoundParameters["Action"] = $ParamDictionary["action"] }
if ($ParamDictionary.ContainsKey("package")) { $BoundParameters["Package"] = $ParamDictionary["package"] }
if ($ParamDictionary.ContainsKey("service")) { $BoundParameters["Service"] = $ParamDictionary["service"] }
if ($ParamDictionary.ContainsKey("port")) { $BoundParameters["Port"] = $ParamDictionary["port"] }
if ($ParamDictionary.ContainsKey("proto")) { $BoundParameters["Proto"] = $ParamDictionary["proto"] }
if ($ParamDictionary.ContainsKey("username")) { $BoundParameters["Username"] = $ParamDictionary["username"] }
if ($ParamDictionary.ContainsKey("generate")) { $BoundParameters["Generate"] = [switch]::Present }

# Call main function with parsed parameters
Main @BoundParameters
