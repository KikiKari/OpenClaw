#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "1dd5be592b7b018afd5992f9c4cb63daf154b524481d9e6f28c04f942034b9cb", "source_sha256": "d23aced948e2cbccfa5bfa57ad3b48adfc5d5f7a42c2fbdf665f8c185b8545eb", "target_language": "ruby"}
# channel_status.py — portiert nach ruby
# Quelle: python, workspace@local:git/skills/channel-status-agent/scripts/channel_status.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# frozen_string_literal: true

#
# Channel Status Agent - Automatische Status-Updates
#

require 'json'
require 'time'
require 'fileutils'

# Konfiguration
WORKSPACE = Pathname.new('/home/openclaw/.openclaw/workspace')
LOGS_DB = WORKSPACE.join('db/logs.db')
CONFIG_FILE = WORKSPACE.join('config/channel-status.json')
LOG_FILE = WORKSPACE.join('logs/channel-status.log')

def log(message, level = 'INFO')
  # Logging
  timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  entry = "[#{timestamp}] [#{level}] #{message}"
  puts entry
  File.open(LOG_FILE, 'a') { |f| f.puts entry }
rescue StandardError => e
  puts "Logging failed: #{e.message}"
end

NODE_NAMES = {
  'node2' => Set.new(%w[openclaw-node2 arm64-node v2202604104722449961 v2202604104722449961.taild25fea.ts.net 100.82.198.122]),
  'node3' => Set.new(%w[openclaw-node3 openclaw-node3.taild25fea.ts.net 100.73.154.125]),
  'node4' => Set.new(%w[openclaw-node4 redmi-note-11s redmi-note-11s.taild25fea.ts.net 100.94.134.39]),
  'node5' => Set.new(%w[openclaw-node5 lenovo-node7 lenovo-node7.taild25fea.ts.net 100.103.140.35])
}.freeze

def fetch_node_status
  # Return mapped OpenClaw connection states; nil indicates lookup failure.
  result = Open3.capture3('openclaw', 'nodes', 'status', '--json', timeout: 10)
  raise unless result[2].success?

  payload = JSON.parse(result[0])
  return nil unless payload.is_a?(Hash) && payload['nodes'].is_a?(Array)

  states = Hash[ NODE_NAMES.keys.map { |node| [node, false] } ]
  payload['nodes'].each do |item|
    next unless item.is_a?(Hash)

    names = Set.new(%w[displayName nodeId remoteIp].map { |key| item[key]&.to_s&.downcase }.compact)
    NODE_NAMES.each do |node, aliases|
      states[node] = true if (names & aliases) && item['connected'] == true
    end
  end
  states['node1'] = true # successful Gateway status request
  states
rescue StandardError
  nil
end

def get_system_status
  # Sammelt System-Status
  status = {
    'timestamp' => Time.now.iso8601,
    'nodes' => {},
    'agents' => {},
    'system' => {}
  }

  # Verbindungslage aus der Gateway-Statusliste; keine statischen Online-Werte.
  states = fetch_node_status
  names = { 'node1' => 'Gateway', 'node2' => 'Node2', 'node3' => 'Node3', 'node4' => 'Redmi', 'node5' => 'Lenovo' }
  status['nodes'] = Hash[names.map do |node, name|
    [
      node,
      {
        'name' => name,
        'status' => if states.nil?
                      'unknown'
                    elsif states[node]
                      'online'
                    else
                      'offline'
                    end
      }
    ]
  end]

  # Agent-Status aus Cron
  begin
    result = Open3.capture3('crontab', '-l')
    cron_lines = result[0].count("\n") - result[0].count('#')
    status['agents']['active_crons'] = cron_lines
  rescue StandardError
    status['agents']['active_crons'] = 'unknown'
  end

  # System-Metriken
  begin
    # Disk usage
    df = Open3.capture3('df', '-h', '/')
    df[0].split("\n").each do |line|
      next unless line.include?('/') && line.include?('%')

      parts = line.split
      status['system']['disk_used'] = parts[4]
      break
    end

    # RAM usage
    free = Open3.capture3('free', '-h')
    free[0].split("\n").each do |line|
      next unless line.include?('Mem:')

      parts = line.split
      status['system']['ram_total'] = parts[1]
      status['system']['ram_used'] = parts[2]
      break
    end
  rescue StandardError
    nil
  end

  status
end

def format_daily_status(status)
  # Formatiert täglichen Status
  nodes = status['nodes']
  online = nodes.values.count { |n| n['status'] == 'online' }

  message = <<~MESSAGE
    📊 **Täglicher Status-Report**
    🗓️ #{Time.now.strftime('%Y-%m-%d %H:%M')}

    **🖥️ Nodes (#{online}/#{nodes.length} online):**

  MESSAGE

  nodes.each do |node_id, info|
    emoji = case info['status']
            when 'online'
              '🟢'
            when 'offline'
              '🔴'
            else
              '🟡'
            end
    message += "#{emoji} #{info['name']}: #{info['status']}"
    message += " (#{info['reason']})" if info.key?('reason')
    message += "\n"
  end

  message += "\n**🤖 Agents:**\n"
  message += "Aktive Cron-Jobs: #{status['agents']['active_crons']}\n"

  if status['system'].key?('disk_used')
    message += "\n**💾 System:**\n"
    message += "Disk: #{status['system']['disk_used']} belegt\n"
    message += "RAM: #{status['system']['ram_used']} / #{status['system']['ram_total']}\n"
  end

  message
end

def format_weekly_status(status)
  # Format the weekly report from current node data.
  lines = [
    '📈 **Wöchentlicher Report**',
    "📅 Woche #{Time.now.strftime('%V')} - #{Time.now.strftime('%Y')}",
    '',
    '**Nodes:**'
  ]
  status['nodes'].each_value { |item| lines.push("- #{item['name']}: #{item['status']}") }
  lines.join("\n") + "\n"
end

def send_to_channel(message, channel_type = 'telegram', channel_id = '-1002381931352')
  # Sendet Nachricht an Channel
  cmd = case channel_type
        when 'telegram'
          ['openclaw', 'message', 'send', '--target', channel_id, '--message', message]
        else
          log("Channel type #{channel_type} not implemented", 'WARN')
          return false
        end

  begin
    result = Open3.capture3(*cmd)
    if result[2].success?
      log("Message sent to #{channel_type} #{channel_id}")
      true
    else
      log("Failed to send: #{result[1]}", 'ERROR')
      false
    end
  rescue StandardError => e
    log("Send error: #{e}", 'ERROR')
    false
  end
end

def main
  # Hauptfunktion
  require 'optparse'
  require 'set'
  require 'pathname'
  require 'open3'

  options = {}
  OptionParser.new do |opts|
    opts.banner = 'Usage: channel_status.rb [options]'
    opts.on('--type TYPE', %w[daily weekly alert], 'Type of status update') do |v|
      options[:type] = v
    end
    opts.on('--message MESSAGE', 'Alert message') do |v|
      options[:message] = v
    end
    opts.on('--channel CHANNEL', 'Channel ID') do |v|
      options[:channel] = v
    end
    opts.on('--dry-run', 'Dry run mode') do |v|
      options[:dry_run] = v
    end
  end.parse!

  unless options[:type]
    puts 'Error: --type is required'
    exit 1
  end

  log("Starting #{options[:type]} status update")

  # Status sammeln
  status = get_system_status

  # Message formatieren
  message = case options[:type]
            when 'daily'
              format_daily_status(status)
            when 'weekly'
              format_weekly_status(status)
            when 'alert'
              "🚨 **ALERT**\n#{options[:message] || 'Manual alert'}"
            end

  # Senden oder Dry-Run
  if options[:dry_run]
    puts "\n--- DRY RUN ---"
    puts message
    puts '--- END ---'
  else
    send_to_channel(message, channel_id: options[:channel] || '-1002381931352')
  end

  log('Status update completed')
end

LOG_FILE.dirname.mkpath
main if __FILE__ == $PROGRAM_NAME
