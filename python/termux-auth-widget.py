#!/data/data/com.termux/files/usr/bin/python3
# abstraction-provenance: {"artifact_sha256": "ec66c16d628616df0795624466776d916e77cc9644cbfb3b3eeb0c0e5d9246d3", "source_sha256": "5633c73683c9a3e413c1958a2736550b913651537faccecaa22df360eec1c69e", "target_language": "python"}
# termux-auth-widget.sh — portiert nach python
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-auth-widget.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

import os
import subprocess
import json
import re
import sys

def run_command(command):
    """Execute shell command and return output and exit code"""
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        return result.stdout.strip(), result.returncode
    except Exception as e:
        return str(e), 1

def main():
    # Server hostname (via Tailscale or SSH config)
    SERVER = os.environ.get('OPENCLAW_SERVER', 'l36')

    # Check auth status
    print("Checking OpenClaw auth...")
    status_output, exit_code = run_command(f"ssh {SERVER} '$HOME/openclaw/scripts/claude-auth-status.sh simple'")

    if status_output == "OK":
        # Get remaining time
        details_output, _ = run_command(f"ssh {SERVER} '$HOME/openclaw/scripts/claude-auth-status.sh json'")
        try:
            details_json = json.loads(details_output)
            hours_match = re.search(r'(\d+)h', details_json['claude_code']['status'])
            hours = hours_match.group(1) if hours_match else "?"
        except:
            hours = "?"

        print("Auth OK")
        # Vibrate for 50ms
        run_command("termux-vibrate -d 50")
        run_command(f"termux-toast \"Auth OK ({hours}h left)\"")

    elif status_output in ["CLAUDE_EXPIRING", "OPENCLAW_EXPIRING"]:
        # Vibrate for 100ms
        run_command("termux-vibrate -d 100")

        # Ask if user wants to re-auth now
        choice_output, _ = run_command("termux-dialog radio -t \"Auth Expiring Soon\" -v \"Re-auth now,Check later,Dismiss\"")
        try:
            choice_json = json.loads(choice_output)
            selected = choice_json.get('text', 'Dismiss')
        except:
            selected = 'Dismiss'

        if selected == "Re-auth now":
            print("Opening auth page...")
            run_command("termux-open-url \"https://console.anthropic.com/settings/api-keys\"")

            # Show instructions
            run_command("termux-dialog confirm -t \"Re-auth Instructions\" -i \"1. Create/copy API key from browser\n2. Return here and tap OK\n3. SSH to server and paste key\"")

            # Open terminal to server
            run_command("am start -n com.termux/com.termux.app.TermuxActivity -a android.intent.action.MAIN")
            run_command(f"termux-toast \"Run: ssh {SERVER} '$HOME/openclaw/scripts/mobile-reauth.sh'\"")
        else:
            run_command("termux-toast \"Reminder: Auth expires soon\"")

    elif status_output in ["CLAUDE_EXPIRED", "OPENCLAW_EXPIRED"]:
        # Vibrate for 300ms
        run_command("termux-vibrate -d 300")

        choice_output, _ = run_command("termux-dialog radio -t \"Auth Expired!\" -v \"Re-auth now,Dismiss\"")
        try:
            choice_json = json.loads(choice_output)
            selected = choice_json.get('text', 'Dismiss')
        except:
            selected = 'Dismiss'

        if selected == "Re-auth now":
            print("Opening auth page...")
            run_command("termux-open-url \"https://console.anthropic.com/settings/api-keys\"")

            run_command("termux-dialog confirm -t \"Re-auth Steps\" -i \"1. Create/copy API key from browser\n2. Return here and tap OK to SSH\"")

            run_command("am start -n com.termux/com.termux.app.TermuxActivity -a android.intent.action.MAIN")
            run_command(f"termux-toast \"Run: ssh {SERVER} '$HOME/openclaw/scripts/mobile-reauth.sh'\"")
        else:
            run_command("termux-toast \"Warning: OpenClaw won't work until re-auth\"")

    else:
        # Vibrate for 200ms
        run_command("termux-vibrate -d 200")
        run_command(f"termux-toast \"Error: {status_output}\"")

if __name__ == "__main__":
    main()
