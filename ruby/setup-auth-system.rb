#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "9100fc15acfbf7f4907c846c200aabe2fc6d4be747497703d8243093e05afd98", "source_sha256": "cb5f3c66f2f8ef6dd2ba9a71832aceb3d4c3af596567dad4241cf94d8e3fd8ba", "target_language": "ruby"}
# setup-auth-system.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/setup-auth-system.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Setup OpenClaw Auth Management System
# Run this once to set up:
# 1. Long-lived Claude Code token
# 2. Auth monitoring with notifications
# 3. Instructions for Termux widgets

require 'fileutils'
require 'pathname'

def main
  script_dir = File.dirname(File.realpath(__FILE__))
  
  puts "=== OpenClaw Auth System Setup ==="
  puts
  
  # Step 1: Check current auth status
  puts "Step 1: Checking current auth status..."
  system("#{script_dir}/claude-auth-status.sh", "full")
  puts
  
  # Step 2: Set up long-lived token
  puts "Step 2: Long-lived token setup"
  puts
  puts "Option A: Use 'claude setup-token' (recommended)"
  puts "  - Creates a long-lived API token"
  puts "  - No daily re-auth needed"
  puts "  - Run: claude setup-token"
  puts
  puts "Would you like to set up a long-lived token now? [y/N]"
  setup_token = gets.chomp
  
  if setup_token.match(/^[Yy]/)
    puts
    puts "Opening https://console.anthropic.com/settings/api-keys"
    puts "Create a new key or copy existing one, then paste below."
    puts
    system("claude setup-token")
  end
  
  puts
  
  # Step 3: Set up auth monitoring
  puts "Step 3: Auth monitoring setup"
  puts
  puts "The auth monitor checks expiry every 30 minutes and notifies you."
  puts
  puts "Configure notification channels:"
  puts
  
  # Check for ntfy
  puts "  ntfy.sh: Free push notifications to your phone"
  puts "  1. Install ntfy app on your phone"
  puts "  2. Subscribe to a topic (e.g., 'openclaw-alerts')"
  puts
  puts "Enter ntfy.sh topic (or leave blank to skip):"
  ntfy_topic = gets.chomp
  
  # Phone notification
  puts
  puts "  OpenClaw message: Send warning via OpenClaw itself"
  puts "Enter your phone number for alerts (or leave blank to skip):"
  phone_number = gets.chomp
  
  # Update service file
  service_file = "#{script_dir}/systemd/openclaw-auth-monitor.service"
  if !ntfy_topic.empty?
    content = File.read(service_file)
    content.gsub!(/^# Environment=NOTIFY_NTFY=.*/, "Environment=NOTIFY_NTFY=#{ntfy_topic}")
    File.write(service_file, content)
  end
  if !phone_number.empty?
    content = File.read(service_file)
    content.gsub!(/^# Environment=NOTIFY_PHONE=.*/, "Environment=NOTIFY_PHONE=#{phone_number}")
    File.write(service_file, content)
  end
  
  # Install systemd units
  puts
  puts "Installing systemd timer..."
  user_systemd_dir = File.expand_path("~/.config/systemd/user")
  FileUtils.mkdir_p(user_systemd_dir)
  FileUtils.cp("#{script_dir}/systemd/openclaw-auth-monitor.service", user_systemd_dir)
  FileUtils.cp("#{script_dir}/systemd/openclaw-auth-monitor.timer", user_systemd_dir)
  
  system("systemctl", "--user", "daemon-reload")
  system("systemctl", "--user", "enable", "--now", "openclaw-auth-monitor.timer")
  
  puts "Auth monitor installed and running."
  puts
  
  # Step 4: Termux widget setup
  puts "Step 4: Termux widget setup (for phone)"
  puts
  puts "To set up quick auth from your phone:"
  puts
  puts "1. Install Termux and Termux:Widget from F-Droid"
  puts "2. Create ~/.shortcuts/ directory in Termux:"
  puts "   mkdir -p ~/.shortcuts"
  puts
  puts "3. Copy the widget scripts:"
  puts "   scp #{script_dir}/termux-quick-auth.sh phone:~/.shortcuts/ClawdAuth"
  puts "   scp #{script_dir}/termux-auth-widget.sh phone:~/.shortcuts/ClawdAuth-Full"
  puts
  puts "4. Make them executable on phone:"
  puts "   ssh phone 'chmod +x ~/.shortcuts/Clawd*'"
  puts
  puts "5. Add Termux:Widget to your home screen"
  puts "6. Tap the widget to see your auth scripts"
  puts
  puts "The quick widget (ClawdAuth) shows status and opens auth URL if needed."
  puts "The full widget (ClawdAuth-Full) provides guided re-auth flow."
  puts
  
  # Summary
  puts "=== Setup Complete ==="
  puts
  puts "What's configured:"
  puts "  - Auth status: #{script_dir}/claude-auth-status.sh"
  puts "  - Mobile re-auth: #{script_dir}/mobile-reauth.sh"
  puts "  - Auth monitor: systemctl --user status openclaw-auth-monitor.timer"
  puts
  puts "Quick commands:"
  puts "  Check auth:  #{script_dir}/claude-auth-status.sh"
  puts "  Re-auth:     #{script_dir}/mobile-reauth.sh"
  puts "  Test monitor: #{script_dir}/auth-monitor.sh"
  puts
end

main if __FILE__ == $0
