#!/usr/bin/env tclsh8.6
# system_manager.py — portiert nach tcl
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/system_manager.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/system_manager.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

# System management abstraction for Ubuntu and CentOS 8.
# Provides command matrix for packages, services, networking.

# Define SystemCommand structure
proc create_system_command {ubuntu centos description} {
    return [list $ubuntu $centos $description]
}

# SystemManager class equivalent
namespace eval SystemManager {
    variable COMMANDS
    variable PACKAGE_MAP
    variable os
    
    # Initialize COMMANDS
    array set COMMANDS {
        install [list "apt-get install -y {package}" "dnf install -y {package}" "Install a package"]
        remove [list "apt-get remove -y {package}" "dnf remove -y {package}" "Remove a package"]
        update [list "apt-get update && apt-get upgrade -y" "dnf update -y" "Update all packages"]
        search [list "apt-cache search {package}" "dnf search {package}" "Search for package"]
        service_start [list "systemctl start {service}" "systemctl start {service}" "Start a service"]
        service_stop [list "systemctl stop {service}" "systemctl stop {service}" "Stop a service"]
        service_enable [list "systemctl enable {service}" "systemctl enable {service}" "Enable service at boot"]
        service_status [list "systemctl status {service}" "systemctl status {service}" "Check service status"]
        firewall_allow [list "ufw allow {port}/{proto}" "firewall-cmd --add-port={port}/{proto} --permanent && firewall-cmd --reload" "Open firewall port"]
        firewall_status [list "ufw status" "firewall-cmd --list-all" "Check firewall status"]
        add_user [list "adduser --disabled-password --gecos '' {username}" "adduser {username}" "Add system user"]
        add_to_sudo [list "usermod -aG sudo {username}" "usermod -aG wheel {username}" "Add user to sudoers"]
    }
    
    # Initialize PACKAGE_MAP
    array set PACKAGE_MAP {
        apache [list ubuntu apache2 centos httpd]
        mysql [list ubuntu mysql-server centos mysql-server]
        php [list ubuntu php centos php]
        nodejs [list ubuntu nodejs centos nodejs]
        nginx [list ubuntu nginx centos nginx]
    }
    
    # Constructor
    proc new {os_type} {
        variable os
        set os [string tolower $os_type]
        if {$os ni {ubuntu centos}} {
            error "Unsupported OS: $os_type"
        }
        return [namespace current]
    }
    
    # Get the command for an action
    proc get_command {action args} {
        variable COMMANDS
        variable os
        
        if {![info exists COMMANDS($action)]} {
            error "Unknown action: $action"
        }
        
        lassign $COMMANDS($action) ubuntu_cmd centos_cmd description
        
        # Get OS-specific command
        if {$os eq "ubuntu"} {
            set cmd $ubuntu_cmd
        } else {
            set cmd $centos_cmd
        }
        
        # Format with arguments
        set formatted_cmd $cmd
        foreach {key value} $args {
            set formatted_cmd [string map [list "{$key}" $value] $formatted_cmd]
        }
        return $formatted_cmd
    }
    
    # Get correct package name for OS
    proc get_package_name {software} {
        variable PACKAGE_MAP
        variable os
        
        set sw [string tolower $software]
        if {[info exists PACKAGE_MAP($sw)]} {
            set mapping $PACKAGE_MAP($sw)
            set idx [lsearch $mapping $os]
            if {$idx != -1 && $idx < [llength $mapping]-1} {
                return [lindex $mapping $idx+1]
            }
        }
        return $software
    }
    
    # Auto-detect OS type
    proc detect_os {} {
        if {[catch {open "/etc/os-release" r} fh]} {
            return ""
        }
        set content [read $fh]
        close $fh
        set content [string tolower $content]
        if {[string match "*ubuntu*" $content] || [string match "*debian*" $content]} {
            return "ubuntu"
        } elseif {[string match "*centos*" $content] || [string match "*rhel*" $content] || [string match "*fedora*" $content]} {
            return "centos"
        }
        return ""
    }
    
    # Generate a shell script for multiple actions
    proc generate_script {actions} {
        variable COMMANDS
        set lines [list "#!/bin/bash" "set -e" ""]
        
        foreach action_dict $actions {
            set action_dict_copy $action_dict
            set action [dict get $action_dict_copy "action"]
            dict unset action_dict_copy "action"
            
            lappend lines "# [lindex $COMMANDS($action) 2]"
            lappend lines [get_command $action {*}$action_dict_copy]
            lappend lines ""
        }
        
        return [join $lines "\n"]
    }
}

# Main procedure
proc main {} {
    global argc argv
    
    # Simple argument parsing
    set args [parse_args $argv]
    
    if {![dict exists $args "--os"]} {
        puts stderr "Error: --os is required"
        exit 1
    }
    
    set os [dict get $args "--os"]
    set action [dict get $args "--action"]
    
    # Initialize manager
    set manager [SystemManager::new $os]
    
    # Build kwargs from args
    set kwargs [list]
    if {[dict exists $args "--package"]} {
        set pkg [$manager get_package_name [dict get $args "--package"]]
        lappend kwargs "package" $pkg
    }
    if {[dict exists $args "--service"]} {
        lappend kwargs "service" [dict get $args "--service"]
    }
    if {[dict exists $args "--port"]} {
        lappend kwargs "port" [dict get $args "--port"]
        set proto "tcp"
        if {[dict exists $args "--proto"]} {
            set proto [dict get $args "--proto"]
        }
        lappend kwargs "proto" $proto
    }
    if {[dict exists $args "--username"]} {
        lappend kwargs "username" [dict get $args "--username"]
    }
    
    set cmd [$manager get_command $action {*}$kwargs]
    
    if {[dict exists $args "--generate"] && [dict get $args "--generate"] eq "true"} {
        puts $cmd
    } else {
        puts "Executing: $cmd"
        # exec /bin/bash -c $cmd  ;# Uncomment to actually execute
    }
}

# Simple argument parser
proc parse_args {argv} {
    set args [dict create]
    set i 0
    while {$i < [llength $argv]} {
        set arg [lindex $argv $i]
        if {[string match "--*" $arg]} {
            set key $arg
            incr i
            if {$i < [llength $argv] && ![string match "--*" [lindex $argv $i]]} {
                set value [lindex $argv $i]
                dict set args $key $value
            } else {
                dict set args $key "true"
                incr i -1
            }
        }
        incr i
    }
    return $args
}

# Run main if this script is executed directly
if {[info script] eq $argv0} {
    main
}
