// abstraction-provenance: {"artifact_sha256": "e0d129695d7308edbdf89551b7d50e1e1b066df61209729b08766227e8ca6620", "source_sha256": "195cda6929663d9049e84b5a94d9261e0632f316438d3dd21c0f4282262a559b", "target_language": "go"}
// system_manager.py — portiert nach go
// Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/system_manager.py
// auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/system_manager.py
// auch in: workspace@local:git/skills/scripting-utils/scripts/system_manager.py
// auch in: workspace@local:skills/scripting-utils/scripts/system_manager.py
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

/*
System management abstraction for Ubuntu and CentOS 8.
Provides command matrix for packages, services, networking.
*/

package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// SystemCommand represents commands for different operating systems
type SystemCommand struct {
	Ubuntu      string
	Centos      string
	Description string
}

// SystemManager holds the OS type and provides methods to manage system operations
type SystemManager struct {
	Os string
}

// COMMANDS maps action names to their corresponding system commands
var COMMANDS = map[string]SystemCommand{
	"install": {
		Ubuntu:      "apt-get install -y {package}",
		Centos:      "dnf install -y {package}",
		Description: "Install a package",
	},
	"remove": {
		Ubuntu:      "apt-get remove -y {package}",
		Centos:      "dnf remove -y {package}",
		Description: "Remove a package",
	},
	"update": {
		Ubuntu:      "apt-get update && apt-get upgrade -y",
		Centos:      "dnf update -y",
		Description: "Update all packages",
	},
	"search": {
		Ubuntu:      "apt-cache search {package}",
		Centos:      "dnf search {package}",
		Description: "Search for package",
	},
	"service_start": {
		Ubuntu:      "systemctl start {service}",
		Centos:      "systemctl start {service}",
		Description: "Start a service",
	},
	"service_stop": {
		Ubuntu:      "systemctl stop {service}",
		Centos:      "systemctl stop {service}",
		Description: "Stop a service",
	},
	"service_enable": {
		Ubuntu:      "systemctl enable {service}",
		Centos:      "systemctl enable {service}",
		Description: "Enable service at boot",
	},
	"service_status": {
		Ubuntu:      "systemctl status {service}",
		Centos:      "systemctl status {service}",
		Description: "Check service status",
	},
	"firewall_allow": {
		Ubuntu:      "ufw allow {port}/{proto}",
		Centos:      "firewall-cmd --add-port={port}/{proto} --permanent && firewall-cmd --reload",
		Description: "Open firewall port",
	},
	"firewall_status": {
		Ubuntu:      "ufw status",
		Centos:      "firewall-cmd --list-all",
		Description: "Check firewall status",
	},
	"add_user": {
		Ubuntu:      "adduser --disabled-password --gecos '' {username}",
		Centos:      "adduser {username}",
		Description: "Add system user",
	},
	"add_to_sudo": {
		Ubuntu:      "usermod -aG sudo {username}",
		Centos:      "usermod -aG wheel {username}",
		Description: "Add user to sudoers",
	},
}

// PACKAGE_MAP maps software names to their OS-specific package names
var PACKAGE_MAP = map[string]map[string]string{
	"apache": {"ubuntu": "apache2", "centos": "httpd"},
	"mysql":  {"ubuntu": "mysql-server", "centos": "mysql-server"},
	"php":    {"ubuntu": "php", "centos": "php"},
	"nodejs": {"ubuntu": "nodejs", "centos": "nodejs"},
	"nginx":  {"ubuntu": "nginx", "centos": "nginx"},
}

// NewSystemManager creates a new SystemManager instance
func NewSystemManager(osType string) (*SystemManager, error) {
	osLower := strings.ToLower(osType)
	if osLower != "ubuntu" && osLower != "centos" {
		return nil, fmt.Errorf("unsupported OS: %s", osType)
	}
	return &SystemManager{Os: osLower}, nil
}

// GetCommand returns the formatted command for an action
func (sm *SystemManager) GetCommand(action string, kwargs map[string]string) (string, error) {
	cmdTemplate, exists := COMMANDS[action]
	if !exists {
		return "", fmt.Errorf("unknown action: %s", action)
	}

	var cmd string
	if sm.Os == "ubuntu" {
		cmd = cmdTemplate.Ubuntu
	} else {
		cmd = cmdTemplate.Centos
	}

	// Replace placeholders with actual values
	for key, value := range kwargs {
		placeholder := "{" + key + "}"
		cmd = strings.ReplaceAll(cmd, placeholder, value)
	}

	return cmd, nil
}

// GetPackageName returns the correct package name for the OS
func (sm *SystemManager) GetPackageName(software string) string {
	mapping, exists := PACKAGE_MAP[strings.ToLower(software)]
	if !exists {
		return software
	}
	if pkgName, ok := mapping[sm.Os]; ok {
		return pkgName
	}
	return software
}

// DetectOS auto-detects the OS type
func (sm *SystemManager) DetectOS() string {
	file, err := os.Open("/etc/os-release")
	if err != nil {
		return ""
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	content := ""
	for scanner.Scan() {
		content += strings.ToLower(scanner.Text()) + "\n"
	}

	if strings.Contains(content, "ubuntu") || strings.Contains(content, "debian") {
		return "ubuntu"
	} else if strings.Contains(content, "centos") || strings.Contains(content, "rhel") || strings.Contains(content, "fedora") {
		return "centos"
	}

	return ""
}

// GenerateScript generates a shell script for multiple actions
func (sm *SystemManager) GenerateScript(actions []map[string]string) (string, error) {
	lines := []string{"#!/bin/bash", "set -e", ""}

	for _, action := range actions {
		actionName, exists := action["action"]
		if !exists {
			return "", fmt.Errorf("missing action in action map")
		}

		delete(action, "action")

		cmdTemplate, exists := COMMANDS[actionName]
		if !exists {
			return "", fmt.Errorf("unknown action: %s", actionName)
		}

		lines = append(lines, "# "+cmdTemplate.Description)

		cmd, err := sm.GetCommand(actionName, action)
		if err != nil {
			return "", err
		}

		lines = append(lines, cmd)
		lines = append(lines, "")
	}

	return strings.Join(lines, "\n"), nil
}

func main() {
	// Parse command line arguments manually since we're avoiding external dependencies
	args := make(map[string]string)
	for i := 1; i < len(os.Args); i++ {
		arg := os.Args[i]
		if strings.HasPrefix(arg, "--") {
			key := strings.TrimPrefix(arg, "--")
			if i+1 < len(os.Args) && !strings.HasPrefix(os.Args[i+1], "--") {
				args[key] = os.Args[i+1]
				i++
			} else {
				args[key] = ""
			}
		}
	}

	osType, exists := args["os"]
	if !exists {
		fmt.Println("Error: --os is required")
		return
	}

	manager, err := NewSystemManager(osType)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		return
	}

	action, exists := args["action"]
	if !exists {
		fmt.Println("Error: --action is required")
		return
	}

	// Build kwargs from args
	kwargs := make(map[string]string)
	if pkg, exists := args["package"]; exists {
		kwargs["package"] = manager.GetPackageName(pkg)
	}
	if service, exists := args["service"]; exists {
		kwargs["service"] = service
	}
	if port, exists := args["port"]; exists {
		kwargs["port"] = port
		if proto, exists := args["proto"]; exists {
			kwargs["proto"] = proto
		} else {
			kwargs["proto"] = "tcp"
		}
	}
	if username, exists := args["username"]; exists {
		kwargs["username"] = username
	}

	cmd, err := manager.GetCommand(action, kwargs)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		return
	}

	if _, exists := args["generate"]; exists {
		fmt.Println(cmd)
	} else {
		fmt.Printf("Executing: %s\n", cmd)
		// Uncomment the following lines to actually execute the command
		// execCmd := exec.Command("sh", "-c", cmd)
		// execCmd.Stdout = os.Stdout
		// execCmd.Stderr = os.Stderr
		// err := execCmd.Run()
		// if err != nil {
		//     fmt.Printf("Execution failed: %v\n", err)
		// }
	}
}
