#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "5cd636d1ae79a3f005d004a40e6ab6ea3fe780dbc10c9566e50abfe784f43768", "source_sha256": "1a67bf0d8a66b56fba5df9f18c7370e48304461313b9611ab6f238f553332b50", "target_language": "ruby"}
# auth-monitor.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/auth-monitor.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Auth Expiry Monitor
# Run via cron or systemd timer to get proactive notifications
# before Claude Code auth expires.
#
# Suggested cron: */30 * * * * /home/admin/openclaw/scripts/auth-monitor.rb
#
# Environment variables:
#   NOTIFY_PHONE - Phone number to send OpenClaw notification (e.g., +1234567890)
#   NOTIFY_NTFY  - ntfy.sh topic for push notifications (e.g., openclaw-alerts)
#   WARN_HOURS   - Hours before expiry to warn (default: 2)

require 'json'
require 'net/http'
require 'uri'
require 'fileutils'

SCRIPT_DIR = File.dirname(File.realpath(__FILE__))
CLAUDE_CREDS = File.expand_path('~/.claude/.credentials.json')
STATE_FILE = File.expand_path('~/.openclaw/auth-monitor-state')

# Configuration
WARN_HOURS = (ENV['WARN_HOURS'] || '2').to_i
NOTIFY_PHONE = ENV['NOTIFY_PHONE'] || ''
NOTIFY_NTFY = ENV['NOTIFY_NTFY'] || ''

# State tracking to avoid spam
FileUtils.mkdir_p(File.dirname(STATE_FILE))
LAST_NOTIFIED = File.exist?(STATE_FILE) ? File.read(STATE_FILE).to_i : 0
NOW = Time.now.to_i

# Only notify once per hour max
MIN_INTERVAL = 3600

def send_notification(message, priority = 'default')
  puts "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} - #{message}"

  # Check if we notified recently
  if (NOW - LAST_NOTIFIED) < MIN_INTERVAL
    puts "Skipping notification (sent recently)"
    return
  end

  # Send via OpenClaw if phone configured and auth still valid
  if !NOTIFY_PHONE.empty?
    # Check if we can still use openclaw
    begin
      status_output = `#{SCRIPT_DIR}/claude-auth-status.sh simple 2>/dev/null`
      if status_output.include?('OK') || status_output.include?('EXPIRING')
        puts "Sending via OpenClaw to #{NOTIFY_PHONE}..."
        system("openclaw", "send", "--to", NOTIFY_PHONE, "--message", message, [:err, :out] => File::NULL)
      end
    rescue => e
      # Ignore errors
    end
  end

  # Send via ntfy.sh if configured
  if !NOTIFY_NTFY.empty?
    puts "Sending via ntfy.sh to #{NOTIFY_NTFY}..."
    begin
      uri = URI("https://ntfy.sh/#{NOTIFY_NTFY}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri)
      request['Title'] = 'OpenClaw Auth Alert'
      request['Priority'] = priority
      request['Tags'] = 'warning,key'
      request.body = message
      http.request(request)
    rescue => e
      # Ignore errors
    end
  end

  # Update state
  File.write(STATE_FILE, NOW.to_s)
end

# Check auth status
if !File.exist?(CLAUDE_CREDS)
  send_notification('Claude Code credentials missing! Run: claude setup-token', 'high')
  exit 1
end

creds_data = JSON.parse(File.read(CLAUDE_CREDS))
EXPIRES_AT = creds_data.dig('claudeAiOauth', 'expiresAt') || 0
NOW_MS = NOW * 1000
DIFF_MS = EXPIRES_AT - NOW_MS
HOURS_LEFT = DIFF_MS / 3_600_000
MINS_LEFT = (DIFF_MS % 3_600_000) / 60_000

if DIFF_MS < 0
  send_notification('Claude Code auth EXPIRED! OpenClaw is down. Run: ssh l36 \'~/openclaw/scripts/mobile-reauth.sh\'', 'urgent')
  exit 1
elsif HOURS_LEFT < WARN_HOURS
  send_notification("Claude Code auth expires in #{HOURS_LEFT}h #{MINS_LEFT}m. Consider re-auth soon.", 'high')
  exit 0
else
  puts "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} - Auth OK: #{HOURS_LEFT}h #{MINS_LEFT}m remaining"
  exit 0
end
