#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "4af56456e2de34a23a8e353a7ce5e4233b8b1928cbf8834148e4ff20216235c0", "source_sha256": "cb5f3c66f2f8ef6dd2ba9a71832aceb3d4c3af596567dad4241cf94d8e3fd8ba", "target_language": "python"}
# setup-auth-system.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/setup-auth-system.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

"""
Setup OpenClaw Auth Management System
Run this once to set up:
1. Long-lived Claude Code token
2. Auth monitoring with notifications
3. Instructions for Termux widgets
"""

import os
import sys
import subprocess
import shutil
from pathlib import Path

def run_command(cmd):
    """Execute a shell command and return result"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.returncode == 0, result.stdout, result.stderr
    except Exception as e:
        return False, "", str(e)

def main():
    script_dir = Path(__file__).parent.resolve()
    
    print("=== OpenClaw Auth System Setup ===")
    print("")
    
    # Step 1: Check current auth status
    print("Step 1: Checking current auth status...")
    status_script = script_dir / "claude-auth-status.sh"
    if status_script.exists():
        run_command(f"{status_script} full")
    print("")
    
    # Step 2: Set up long-lived token
    print("Step 2: Long-lived token setup")
    print("")
    print("Option A: Use 'claude setup-token' (recommended)")
    print("  - Creates a long-lived API token")
    print("  - No daily re-auth needed")
    print("  - Run: claude setup-token")
    print("")
    setup_token = input("Would you like to set up a long-lived token now? [y/N]: ").strip()
    
    if setup_token.lower().startswith('y'):
        print("")
        print("Opening https://console.anthropic.com/settings/api-keys")
        print("Create a new key or copy existing one, then paste below.")
        print("")
        
        # Try to open browser
        run_command("xdg-open https://console.anthropic.com/settings/api-keys 2>/dev/null || open https://console.anthropic.com/settings/api-keys 2>/dev/null || true")
        
        # Run setup-token command
        setup_cmd = script_dir / "claude"
        if setup_cmd.exists():
            run_command(f"{setup_cmd} setup-token")
    
    print("")
    
    # Step 3: Set up auth monitoring
    print("Step 3: Auth monitoring setup")
    print("")
    print("The auth monitor checks expiry every 30 minutes and notifies you.")
    print("")
    print("Configure notification channels:")
    print("")
    
    # Check for ntfy
    print("  ntfy.sh: Free push notifications to your phone")
    print("  1. Install ntfy app on your phone")
    print("  2. Subscribe to a topic (e.g., 'openclaw-alerts')")
    print("")
    ntfy_topic = input("Enter ntfy.sh topic (or leave blank to skip): ").strip()
    
    # Phone notification
    print("")
    print("  OpenClaw message: Send warning via OpenClaw itself")
    phone_number = input("Enter your phone number for alerts (or leave blank to skip): ").strip()
    
    # Update service file
    service_file = script_dir / "systemd" / "openclaw-auth-monitor.service"
    if service_file.exists():
        # Read and modify service file content
        content = service_file.read_text()
        
        if ntfy_topic:
            content = content.replace(
                "# Environment=NOTIFY_NTFY=", 
                f"Environment=NOTIFY_NTFY={ntfy_topic}"
            )
        
        if phone_number:
            content = content.replace(
                "# Environment=NOTIFY_PHONE=", 
                f"Environment=NOTIFY_PHONE={phone_number}"
            )
        
        # Write back modified content
        temp_service = service_file.with_suffix('.service.tmp')
        temp_service.write_text(content)
        shutil.move(temp_service, service_file)
    
    # Install systemd units
    print("")
    print("Installing systemd timer...")
    
    systemd_user_dir = Path.home() / ".config" / "systemd" / "user"
    systemd_user_dir.mkdir(parents=True, exist_ok=True)
    
    # Copy service and timer files
    source_service = script_dir / "systemd" / "openclaw-auth-monitor.service"
    source_timer = script_dir / "systemd" / "openclaw-auth-monitor.timer"
    dest_service = systemd_user_dir / "openclaw-auth-monitor.service"
    dest_timer = systemd_user_dir / "openclaw-auth-monitor.timer"
    
    if source_service.exists():
        shutil.copy2(source_service, dest_service)
    if source_timer.exists():
        shutil.copy2(source_timer, dest_timer)
    
    # Reload systemd and enable timer
    run_command("systemctl --user daemon-reload")
    run_command("systemctl --user enable --now openclaw-auth-monitor.timer")
    
    print("Auth monitor installed and running.")
    print("")
    
    # Step 4: Termux widget setup
    print("Step 4: Termux widget setup (for phone)")
    print("")
    print("To set up quick auth from your phone:")
    print("")
    print("1. Install Termux and Termux:Widget from F-Droid")
    print("2. Create ~/.shortcuts/ directory in Termux:")
    print("   mkdir -p ~/.shortcuts")
    print("")
    print("3. Copy the widget scripts:")
    print(f"   scp {script_dir}/termux-quick-auth.sh phone:~/.shortcuts/ClawdAuth")
    print(f"   scp {script_dir}/termux-auth-widget.sh phone:~/.shortcuts/ClawdAuth-Full")
    print("")
    print("4. Make them executable on phone:")
    print("   ssh phone 'chmod +x ~/.shortcuts/Clawd*'")
    print("")
    print("5. Add Termux:Widget to your home screen")
    print("6. Tap the widget to see your auth scripts")
    print("")
    print("The quick widget (ClawdAuth) shows status and opens auth URL if needed.")
    print("The full widget (ClawdAuth-Full) provides guided re-auth flow.")
    print("")
    
    # Summary
    print("=== Setup Complete ===")
    print("")
    print("What's configured:")
    print(f"  - Auth status: {script_dir}/claude-auth-status.sh")
    print(f"  - Mobile re-auth: {script_dir}/mobile-reauth.sh")
    print("  - Auth monitor: systemctl --user status openclaw-auth-monitor.timer")
    print("")
    print("Quick commands:")
    print(f"  Check auth:  {script_dir}/claude-auth-status.sh")
    print(f"  Re-auth:     {script_dir}/mobile-reauth.sh")
    print(f"  Test monitor: {script_dir}/auth-monitor.sh")
    print("")

if __name__ == "__main__":
    main()
