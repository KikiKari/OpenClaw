#!/data/data/com.termux/files/usr/bin/ruby
# abstraction-provenance: {"artifact_sha256": "f2bdc4f6b9985734901f84878de11e9e9b842f2884ff232b4f1fdd65a889323d", "source_sha256": "32acbaa2d9f84dca0c2fd8f987ab23e0153c0e63d20e7ee9c3e279058ab681c6", "target_language": "ruby"}
# termux-quick-auth.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-quick-auth.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# Quick Auth Check - Minimal widget for Termux
# Place in ~/.shortcuts/ for Termux:Widget
#
# One-tap: shows status toast
# If expired: directly opens auth URL

SERVER = ENV['OPENCLAW_SERVER'] || 'l36'

def execute_command(command)
  result = `#{command} 2>&1`
  $?.success? ? result.strip : nil
end

def termux_toast(message, short=false)
  cmd = "termux-toast"
  cmd += " -s" if short
  cmd += " \"#{message}\""
  system(cmd)
end

def termux_vibrate(duration)
  system("termux-vibrate -d #{duration}")
end

def termux_open_url(url)
  system("termux-open-url \"#{url}\"")
end

def termux_notification(title, content, id)
  system("termux-notification -t \"#{title}\" -c \"#{content}\" --id #{id}")
end

status = execute_command("ssh -o ConnectTimeout=5 \"#{SERVER}\" '$HOME/openclaw/scripts/claude-auth-status.sh simple'")

if status.nil?
  termux_toast("Connection error")
elsif status == "OK"
  termux_toast("Auth OK", true)
elsif status.include?("EXPIRING")
  termux_vibrate(100)
  termux_toast("Auth expiring soon - tap again if needed")
elsif status.include?("EXPIRED") || status.include?("MISSING")
  termux_vibrate(200)
  termux_toast("Auth expired - opening console...")
  termux_open_url("https://console.anthropic.com/settings/api-keys")
  sleep(2)
  termux_notification("OpenClaw Re-Auth", "After getting key, run: ssh #{SERVER} '~/openclaw/scripts/mobile-reauth.sh'", "openclaw-auth")
else
  termux_toast("Connection error")
end
