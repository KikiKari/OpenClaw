#!/data/data/com.termux/files/usr/bin/ruby
# abstraction-provenance: {"artifact_sha256": "0fd02c450c93a2296ad20a93d0a596789a725fb4df2a6ca1e21fe9b00d60a229", "source_sha256": "5a61490f9c6c3ae52acdce976cbcad0d09396f906ddb85d7ae357ab98e762893", "target_language": "ruby"}
# termux-sync-widget.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/termux-sync-widget.sh
# Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

# OpenClaw OAuth Sync Widget
# Syncs Claude Code tokens to OpenClaw on l36 server
# Place in ~/.shortcuts/ on phone for Termux:Widget

def termux_toast(message)
  system("termux-toast", message)
end

def termux_vibrate(duration)
  system("termux-vibrate", "-d", duration.to_s)
end

def run_command(command)
  result = `#{command} 2>&1`
  exit_code = $?.exitstatus
  [result, exit_code]
end

termux_toast("Syncing OpenClaw auth...")

# Run sync on l36 server
server = ENV['OPENCLAW_SERVER'] || 'l36'
sync_command = "ssh #{server} '/home/admin/openclaw/scripts/sync-claude-code-auth.sh'"
result, exit_code = run_command(sync_command)

if exit_code == 0
  # Extract expiry time from output
  expiry_line = result.lines.find { |line| line.include?("Token expires:") }
  expiry = expiry_line ? expiry_line.split(":", 2).last.strip : ""

  termux_vibrate(100)
  termux_toast("OpenClaw synced! Expires:#{expiry}")

  # Optional: restart openclaw service
  run_command("ssh #{server} 'systemctl --user restart openclaw' >/dev/null 2>&1")
else
  termux_vibrate(300)
  termux_toast("Sync failed: #{result}")
end
