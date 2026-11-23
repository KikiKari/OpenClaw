#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "af6068c44db95547d63fe31a1ac18de02c52c6add421d5dd4031961d4bb0ce5f", "source_sha256": "195cda6929663d9049e84b5a94d9261e0632f316438d3dd21c0f4282262a559b", "target_language": "ruby"}
# system_manager.py — portiert nach ruby
# Quelle: python, OpenClaw@gateway1:skills/scripting-utils/scripts/system_manager.py
# auch in: OpenClaw@gateway2:skills/scripting-utils/scripts/system_manager.py
# auch in: workspace@local:git/skills/scripting-utils/scripts/system_manager.py
# auch in: workspace@local:skills/scripting-utils/scripts/system_manager.py
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# System management abstraction for Ubuntu and CentOS 8.
# Provides command matrix for packages, services, networking.

class SystemCommand
  attr_reader :ubuntu, :centos, :description

  def initialize(ubuntu:, centos:, description:)
    @ubuntu = ubuntu
    @centos = centos
    @description = description
  end
end

class SystemManager
  # Ubuntu vs CentOS 8 command matrix.
  
  COMMANDS = {
    "install" => SystemCommand.new(
      ubuntu: "apt-get install -y {package}",
      centos: "dnf install -y {package}",
      description: "Install a package"
    ),
    "remove" => SystemCommand.new(
      ubuntu: "apt-get remove -y {package}",
      centos: "dnf remove -y {package}",
      description: "Remove a package"
    ),
    "update" => SystemCommand.new(
      ubuntu: "apt-get update && apt-get upgrade -y",
      centos: "dnf update -y",
      description: "Update all packages"
    ),
    "search" => SystemCommand.new(
      ubuntu: "apt-cache search {package}",
      centos: "dnf search {package}",
      description: "Search for package"
    ),
    "service_start" => SystemCommand.new(
      ubuntu: "systemctl start {service}",
      centos: "systemctl start {service}",
      description: "Start a service"
    ),
    "service_stop" => SystemCommand.new(
      ubuntu: "systemctl stop {service}",
      centos: "systemctl stop {service}",
      description: "Stop a service"
    ),
    "service_enable" => SystemCommand.new(
      ubuntu: "systemctl enable {service}",
      centos: "systemctl enable {service}",
      description: "Enable service at boot"
    ),
    "service_status" => SystemCommand.new(
      ubuntu: "systemctl status {service}",
      centos: "systemctl status {service}",
      description: "Check service status"
    ),
    "firewall_allow" => SystemCommand.new(
      ubuntu: "ufw allow {port}/{proto}",
      centos: "firewall-cmd --add-port={port}/{proto} --permanent && firewall-cmd --reload",
      description: "Open firewall port"
    ),
    "firewall_status" => SystemCommand.new(
      ubuntu: "ufw status",
      centos: "firewall-cmd --list-all",
      description: "Check firewall status"
    ),
    "add_user" => SystemCommand.new(
      ubuntu: "adduser --disabled-password --gecos '' {username}",
      centos: "adduser {username}",
      description: "Add system user"
    ),
    "add_to_sudo" => SystemCommand.new(
      ubuntu: "usermod -aG sudo {username}",
      centos: "usermod -aG wheel {username}",
      description: "Add user to sudoers"
    ),
  }.freeze
  
  # Package name mappings (same software, different package names)
  PACKAGE_MAP = {
    "apache" => {"ubuntu" => "apache2", "centos" => "httpd"},
    "mysql" => {"ubuntu" => "mysql-server", "centos" => "mysql-server"},
    "php" => {"ubuntu" => "php", "centos" => "php"},
    "nodejs" => {"ubuntu" => "nodejs", "centos" => "nodejs"},
    "nginx" => {"ubuntu" => "nginx", "centos" => "nginx"},
  }.freeze
  
  def initialize(os_type)
    @os = os_type.downcase
    raise ArgumentError, "Unsupported OS: #{os_type}" unless %w[ubuntu centos].include?(@os)
  end
  
  def get_command(action, **kwargs)
    # Get the command for an action.
    cmd_template = COMMANDS[action]
    raise ArgumentError, "Unknown action: #{action}" unless cmd_template
    
    # Get OS-specific command
    cmd = if @os == "ubuntu"
            cmd_template.ubuntu
          else
            cmd_template.centos
          end
    
    # Format with arguments
    kwargs.each do |key, value|
      cmd = cmd.gsub("{#{key}}", value.to_s)
    end
    cmd
  end
  
  def get_package_name(software)
    # Get correct package name for OS.
    mapping = PACKAGE_MAP[software.downcase] || {}
    mapping[@os] || software
  end
  
  def detect_os
    # Auto-detect OS type.
    begin
      content = File.read("/etc/os-release").downcase
      if content.include?("ubuntu") || content.include?("debian")
        return "ubuntu"
      elsif content.include?("centos") || content.include?("rhel") || content.include?("fedora")
        return "centos"
      end
    rescue Errno::ENOENT
      nil
    end
    nil
  end
  
  def generate_script(actions)
    # Generate a shell script for multiple actions.
    lines = ["#!/bin/bash", "set -e", ""]
    
    actions.each do |action|
      action_copy = action.dup
      cmd_name = action_copy.delete("action")
      lines << "# #{COMMANDS[cmd_name].description}"
      lines << get_command(cmd_name, **action_copy)
      lines << ""
    end
    
    lines.join("\n")
  end
  
  attr_reader :os
end

def main
  require 'optparse'
  
  options = {
    os: nil,
    action: nil,
    package: nil,
    service: nil,
    port: nil,
    proto: "tcp",
    username: nil,
    generate: false
  }
  
  OptionParser.new do |opts|
    opts.banner = "Usage: system_manager.rb [options]"
    opts.on("--os OS", ["ubuntu", "centos"], "Operating system") { |v| options[:os] = v }
    opts.on("--action ACTION", "Action to perform") { |v| options[:action] = v }
    opts.on("--package PACKAGE", "Package name") { |v| options[:package] = v }
    opts.on("--service SERVICE", "Service name") { |v| options[:service] = v }
    opts.on("--port PORT", "Port number") { |v| options[:port] = v }
    opts.on("--proto PROTO", "Protocol (tcp/udp)") { |v| options[:proto] = v }
    opts.on("--username USERNAME", "Username") { |v| options[:username] = v }
    opts.on("--generate", "Generate script instead of execute") { options[:generate] = true }
  end.parse!
  
  manager = SystemManager.new(options[:os])
  
  # Build kwargs from options
  kwargs = {}
  if options[:package]
    kwargs[:package] = manager.get_package_name(options[:package])
  end
  if options[:service]
    kwargs[:service] = options[:service]
  end
  if options[:port]
    kwargs[:port] = options[:port]
    kwargs[:proto] = options[:proto]
  end
  if options[:username]
    kwargs[:username] = options[:username]
  end
  
  cmd = manager.get_command(options[:action], **kwargs)
  
  if options[:generate]
    puts cmd
  else
    puts "Executing: #{cmd}"
    # system(cmd)  # Uncomment to actually execute
  end
end

main if __FILE__ == $0
