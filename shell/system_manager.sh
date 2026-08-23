#!/usr/bin/env bash
# system_manager.py — portiert nach shell
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/system_manager.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/system_manager.py
# Erzeugt: 2026-08-23 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# System management abstraction for Ubuntu and CentOS 8.
# Provides command matrix for packages, services, networking.

# Global variables
declare -A COMMANDS_UBUNTU COMMANDS_CENTOS PACKAGE_MAP

# Initialize command matrices
init_commands() {
    # Package management commands
    COMMANDS_UBUNTU["install"]="apt-get install -y {package}"
    COMMANDS_CENTOS["install"]="dnf install -y {package}"
    
    COMMANDS_UBUNTU["remove"]="apt-get remove -y {package}"
    COMMANDS_CENTOS["remove"]="dnf remove -y {package}"
    
    COMMANDS_UBUNTU["update"]="apt-get update && apt-get upgrade -y"
    COMMANDS_CENTOS["update"]="dnf update -y"
    
    COMMANDS_UBUNTU["search"]="apt-cache search {package}"
    COMMANDS_CENTOS["search"]="dnf search {package}"
    
    # Service management commands
    COMMANDS_UBUNTU["service_start"]="systemctl start {service}"
    COMMANDS_CENTOS["service_start"]="systemctl start {service}"
    
    COMMANDS_UBUNTU["service_stop"]="systemctl stop {service}"
    COMMANDS_CENTOS["service_stop"]="systemctl stop {service}"
    
    COMMANDS_UBUNTU["service_enable"]="systemctl enable {service}"
    COMMANDS_CENTOS["service_enable"]="systemctl enable {service}"
    
    COMMANDS_UBUNTU["service_status"]="systemctl status {service}"
    COMMANDS_CENTOS["service_status"]="systemctl status {service}"
    
    # Firewall commands
    COMMANDS_UBUNTU["firewall_allow"]="ufw allow {port}/{proto}"
    COMMANDS_CENTOS["firewall_allow"]="firewall-cmd --add-port={port}/{proto} --permanent && firewall-cmd --reload"
    
    COMMANDS_UBUNTU["firewall_status"]="ufw status"
    COMMANDS_CENTOS["firewall_status"]="firewall-cmd --list-all"
    
    # User management commands
    COMMANDS_UBUNTU["add_user"]="adduser --disabled-password --gecos '' {username}"
    COMMANDS_CENTOS["add_user"]="adduser {username}"
    
    COMMANDS_UBUNTU["add_to_sudo"]="usermod -aG sudo {username}"
    COMMANDS_CENTOS["add_to_sudo"]="usermod -aG wheel {username}"
    
    # Package name mappings
    PACKAGE_MAP["apache_ubuntu"]="apache2"
    PACKAGE_MAP["apache_centos"]="httpd"
    PACKAGE_MAP["mysql_ubuntu"]="mysql-server"
    PACKAGE_MAP["mysql_centos"]="mysql-server"
    PACKAGE_MAP["php_ubuntu"]="php"
    PACKAGE_MAP["php_centos"]="php"
    PACKAGE_MAP["nodejs_ubuntu"]="nodejs"
    PACKAGE_MAP["nodejs_centos"]="nodejs"
    PACKAGE_MAP["nginx_ubuntu"]="nginx"
    PACKAGE_MAP["nginx_centos"]="nginx"
}

# Get OS type
detect_os() {
    if [[ -f /etc/os-release ]]; then
        local content
        content=$(cat /etc/os-release | tr '[:upper:]' '[:lower:]')
        if [[ $content == *"ubuntu"* ]] || [[ $content == *"debian"* ]]; then
            echo "ubuntu"
            return
        elif [[ $content == *"centos"* ]] || [[ $content == *"rhel"* ]] || [[ $content == *"fedora"* ]]; then
            echo "centos"
            return
        fi
    fi
    echo ""
}

# Get correct package name for OS
get_package_name() {
    local software="$1"
    local os="$2"
    local key="${software}_${os}"
    
    if [[ -n "${PACKAGE_MAP[$key]:-}" ]]; then
        echo "${PACKAGE_MAP[$key]}"
    else
        echo "$software"
    fi
}

# Get the command for an action
get_command() {
    local os="$1"
    local action="$2"
    shift 2
    local args=("$@")
    
    local cmd_template=""
    case "$os" in
        ubuntu)
            cmd_template="${COMMANDS_UBUNTU[$action]:-}"
            ;;
        centos)
            cmd_template="${COMMANDS_CENTOS[$action]:-}"
            ;;
        *)
            echo "Error: Unknown OS: $os" >&2
            exit 1
            ;;
    esac
    
    if [[ -z "$cmd_template" ]]; then
        echo "Error: Unknown action: $action" >&2
        exit 1
    fi
    
    # Process arguments and replace placeholders
    local result="$cmd_template"
    local i
    for ((i=0; i<${#args[@]}; i+=2)); do
        local key="${args[i]}"
        local value="${args[i+1]}"
        result="${result//\{$key\}/$value}"
    done
    
    echo "$result"
}

# Generate a shell script for multiple actions
generate_script() {
    local os="$1"
    shift
    local actions=("$@")
    
    echo "#!/bin/bash"
    echo "set -e"
    echo ""
    
    local i
    for ((i=0; i<${#actions[@]}; i+=6)); do
        local action="${actions[i]}"
        local package="${actions[i+1]:-}"
        local service="${actions[i+2]:-}"
        local port="${actions[i+3]:-}"
        local proto="${actions[i+4]:-}"
        local username="${actions[i+5]:-}"
        
        # Print description comment
        case "$action" in
            install) echo "# Install a package" ;;
            remove) echo "# Remove a package" ;;
            update) echo "# Update all packages" ;;
            search) echo "# Search for package" ;;
            service_start) echo "# Start a service" ;;
            service_stop) echo "# Stop a service" ;;
            service_enable) echo "# Enable service at boot" ;;
            service_status) echo "# Check service status" ;;
            firewall_allow) echo "# Open firewall port" ;;
            firewall_status) echo "# Check firewall status" ;;
            add_user) echo "# Add system user" ;;
            add_to_sudo) echo "# Add user to sudoers" ;;
        esac
        
        # Build arguments array
        local args=()
        [[ -n "$package" ]] && args+=("package" "$package")
        [[ -n "$service" ]] && args+=("service" "$service")
        [[ -n "$port" ]] && args+=("port" "$port")
        [[ -n "$proto" ]] && args+=("proto" "$proto")
        [[ -n "$username" ]] && args+=("username" "$username")
        
        get_command "$os" "$action" "${args[@]}"
        echo ""
    done
}

# Main function
main() {
    init_commands
    
    local os=""
    local action=""
    local package=""
    local service=""
    local port=""
    local proto="tcp"
    local username=""
    local generate=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --os)
                os="$2"
                shift 2
                ;;
            --action)
                action="$2"
                shift 2
                ;;
            --package)
                package="$2"
                shift 2
                ;;
            --service)
                service="$2"
                shift 2
                ;;
            --port)
                port="$2"
                shift 2
                ;;
            --proto)
                proto="$2"
                shift 2
                ;;
            --username)
                username="$2"
                shift 2
                ;;
            --generate)
                generate=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 --os [ubuntu|centos] --action ACTION [--package PKG] [--service SVC] [--port PORT] [--proto PROTO] [--username USER] [--generate]"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$os" ]] || [[ -z "$action" ]]; then
        echo "Error: --os and --action are required"
        exit 1
    fi
    
    # Auto-detect OS if not provided
    if [[ "$os" == "auto" ]]; then
        os=$(detect_os)
        if [[ -z "$os" ]]; then
            echo "Error: Could not detect OS"
            exit 1
        fi
    fi
    
    # Validate OS
    if [[ "$os" != "ubuntu" ]] && [[ "$os" != "centos" ]]; then
        echo "Error: Unsupported OS: $os"
        exit 1
    fi
    
    # Process package name if provided
    if [[ -n "$package" ]]; then
        package=$(get_package_name "$package" "$os")
    fi
    
    # Build arguments array
    local args=()
    [[ -n "$package" ]] && args+=("package" "$package")
    [[ -n "$service" ]] && args+=("service" "$service")
    [[ -n "$port" ]] && args+=("port" "$port")
    [[ -n "$proto" ]] && args+=("proto" "$proto")
    [[ -n "$username" ]] && args+=("username" "$username")
    
    # Get command
    local cmd
    cmd=$(get_command "$os" "$action" "${args[@]}")
    
    # Execute or generate
    if [[ "$generate" == true ]]; then
        echo "$cmd"
    else
        echo "Executing: $cmd"
        # eval "$cmd"  # Uncomment to actually execute
    fi
}

# Call main function with all arguments
main "$@"
