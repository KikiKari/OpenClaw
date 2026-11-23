#!/data/data/com.termux/files/usr/bin/ruby
# abstraction-provenance: {"artifact_sha256": "99bf0b038f435c44c92f3d71994164a64fa4e269da5d0e2a93fe4d41dbdb28f2", "source_sha256": "5633c73683c9a3e413c1958a2736550b913651537faccecaa22df360eec1c69e", "target_language": "ruby"}
# termux-auth-widget.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-auth-widget.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# OpenClaw Auth Widget for Termux
# Place in ~/.shortcuts/ for Termux:Widget
#
# This widget checks auth status and helps with re-auth if needed.
# It's designed for quick one-tap checking from phone home screen.

require 'json'
require 'open3'

# Server hostname (via Tailscale or SSH config)
SERVER = ENV['OPENCLAW_SERVER'] || 'l36'

# Check auth status
`termux-toast "Checking OpenClaw auth..."`

status, exit_status = Open3.capture2e("ssh", SERVER, '$HOME/openclaw/scripts/claude-auth-status.sh simple')
STATUS = status.strip
EXIT_CODE = exit_status.exitstatus

case STATUS
when "OK"
  # Get remaining time
  details, _ = Open3.capture2e("ssh", SERVER, '$HOME/openclaw/scripts/claude-auth-status.sh json')
  
  begin
    parsed_details = JSON.parse(details)
    status_text = parsed_details.dig('claude_code', 'status') || ""
    hours_match = status_text.match(/(\d+)h/)
    HOURS = hours_match ? hours_match[1] : "?"
  rescue JSON::ParserError
    HOURS = "?"
  end

  `termux-vibrate -d 50`
  `termux-toast "Auth OK (#{HOURS}h left)"`
  
when "CLAUDE_EXPIRING", "OPENCLAW_EXPIRING"
  `termux-vibrate -d 100`

  # Ask if user wants to re-auth now
  choice_json, _ = Open3.capture2e("termux-dialog", "radio", "-t", "Auth Expiring Soon", "-v", "Re-auth now,Check later,Dismiss")
  
  begin
    choice_data = JSON.parse(choice_json)
    SELECTED = choice_data['text'] || "Dismiss"
  rescue JSON::ParserError
    SELECTED = "Dismiss"
  end

  case SELECTED
  when "Re-auth now"
    `termux-toast "Opening auth page..."`
    `termux-open-url "https://console.anthropic.com/settings/api-keys"`

    # Show instructions
    `termux-dialog confirm -t "Re-auth Instructions" -i "1. Create/copy API key from browser\n2. Return here and tap OK\n3. SSH to server and paste key"`

    # Open terminal to server
    `am start -n com.termux/com.termux.app.TermuxActivity -a android.intent.action.MAIN`
    `termux-toast "Run: ssh #{SERVER} '\$HOME/openclaw/scripts/mobile-reauth.sh'"`
  else
    `termux-toast "Reminder: Auth expires soon"`
  end
  
when "CLAUDE_EXPIRED", "OPENCLAW_EXPIRED"
  `termux-vibrate -d 300`

  choice_json, _ = Open3.capture2e("termux-dialog", "radio", "-t", "Auth Expired!", "-v", "Re-auth now,Dismiss")
  
  begin
    choice_data = JSON.parse(choice_json)
    SELECTED = choice_data['text'] || "Dismiss"
  rescue JSON::ParserError
    SELECTED = "Dismiss"
  end

  case SELECTED
  when "Re-auth now"
    `termux-toast "Opening auth page..."`
    `termux-open-url "https://console.anthropic.com/settings/api-keys"`

    `termux-dialog confirm -t "Re-auth Steps" -i "1. Create/copy API key from browser\n2. Return here and tap OK to SSH"`

    `am start -n com.termux/com.termux.app.TermuxActivity -a android.intent.action.MAIN`
    `termux-toast "Run: ssh #{SERVER} '\$HOME/openclaw/scripts/mobile-reauth.sh'"`
  else
    `termux-toast "Warning: OpenClaw won't work until re-auth"`
  end
  
else
  `termux-vibrate -d 200`
  `termux-toast "Error: #{STATUS}"`
end
