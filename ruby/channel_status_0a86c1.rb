#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "64f5689c779671bdb672f2eb10ddbd7f574e1f20d395674b3bca48abbba00a06", "source_sha256": "0a86c190e36a7131252f54b73542b2e9f42f2b23547cdb5530f47c8477226123", "target_language": "ruby"}
# channel_status.py — portiert nach ruby
# Quelle: python, workspace@local:skills/channel-status-agent/scripts/channel_status.py
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

# Channel Status Agent - Automatische Status-Updates

require 'json'
require 'time'
require 'fileutils'

# Konfiguration
WORKSPACE = Pathname.new("/home/openclaw/.openclaw/workspace")
LOGS_DB = WORKSPACE / "db/logs.db"
CONFIG_FILE = WORKSPACE / "config/channel-status.json"
LOG_FILE = WORKSPACE / "logs/channel-status.log"

def log(message, level = "INFO")
  # Logging
  timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
  entry = "[#{timestamp}] [#{level}] #{message}"
  puts entry
  File.open(LOG_FILE, 'a') { |f| f.puts entry }
end

NODE_NAMES = {
  "node2" => Set.new(["openclaw-node2", "arm64-node", "v2202604104722449961", "v2202604104722449961.taild25fea.ts.net", "100.82.198.122"]),
  "node3" => Set.new(["openclaw-node3", "openclaw-node3.taild25fea.ts.net", "100.73.154.125"]),
  "node4" => Set.new(["openclaw-node4", "redmi-note-11s", "redmi-note-11s.taild25fea.ts.net", "100.94.134.39"]),
  "node5" => Set.new(["openclaw-node5"]),
  "node6" => Set.new(["openclaw-node6"]),
}.freeze

def fetch_node_status
  # Return mapped OpenClaw connection states; nil indicates lookup failure.
  begin
    result = Open3.capture3("openclaw", "nodes", "status", "--json")
    raise unless result[1].success?

    payload = JSON.parse(result[0])
    return nil unless payload.is_a?(Hash) && payload["nodes"].is_a?(Array)

    states = Hash[NODE_NAMES.keys.map { |node| [node, false] }]
    payload["nodes"].each do |item|
      next unless item.is_a?(Hash)

      names = Set.new(%w[displayName nodeId remoteIp].map { |key| item[key]&.to_s&.downcase }.compact)
      NODE_NAMES.each do |node, aliases|
        if !(names & aliases).empty? && item["connected"] == true
          states[node] = true
        end
      end
    end
    states["node1"] = true # successful Gateway status request
    states
  rescue StandardError
    nil
  end
end

def get_system_status
  # Sammelt System-Status
  status = {
    "timestamp" => Time.now.iso8601,
    "nodes" => {},
    "agents" => {},
    "system" => {}
  }

  # Verbindungslage aus der Gateway-Statusliste; keine statischen Online-Werte.
  states = fetch_node_status
  names = {
    "node1" => "Gateway",
    "node2" => "Node2",
    "node3" => "Node3",
    "node4" => "Redmi",
    "node5" => "Lenovo",
    "node6" => "Lenovo (Docker)"
  }
  status["nodes"] = names.each_with_object({}) do |(node, name), hash|
    hash[node] = {
      "name" => name,
      "status" => if states.nil?
                     "unknown"
                   elsif states[node]
                     "online"
                   else
                     "offline"
                   end
    }
  end

  # Agent-Status aus Cron
  begin
    result = `crontab -l`
    cron_lines = result.lines.count { |line| !line.start_with?('#') }
    status["agents"]["active_crons"] = cron_lines
  rescue StandardError
    status["agents"]["active_crons"] = "unknown"
  end

  # System-Metriken
  begin
    # Disk usage
    df = `df -h /`
    df.lines.each do |line|
      if line.include?('/') && line.include?('%')
        parts = line.split
        status["system"]["disk_used"] = parts[4]
        break
      end
    end

    # RAM usage
    free = `free -h`
    free.lines.each do |line|
      if line.include?('Mem:')
        parts = line.split
        status["system"]["ram_total"] = parts[1]
        status["system"]["ram_used"] = parts[2]
        break
      end
    end
  rescue StandardError
    nil
  end

  status
end

def format_daily_status(status)
  # Formatiert täglichen Status
  nodes = status["nodes"]
  online = nodes.values.count { |n| n["status"] == "online" }

  message = <<~MESSAGE
    📊 **Täglicher Status-Report**
    🗓️ #{Time.now.strftime('%Y-%m-%d %H:%M')}

    **🖥️ Nodes (#{online}/#{nodes.length} online):**

  MESSAGE

  nodes.each do |node_id, info|
    emoji = case info["status"]
             when "online" then "🟢"
             when "offline" then "🔴"
             else "🟡"
             end
    message += "#{emoji} #{info['name']}: #{info['status']}"
    message += " (#{info['reason']})" if info.key?("reason")
    message += "\n"
  end

  message += "\n**🤖 Agents:**\n"
  message += "Aktive Cron-Jobs: #{status['agents']['active_crons']}\n"

  if status["system"].key?("disk_used")
    message += "\n**💾 System:**\n"
    message += "Disk: #{status['system']['disk_used']} belegt\n"
    message += "RAM: #{status['system']['ram_used']} / #{status['system']['ram_total']}\n"
  end

  message
end

def format_weekly_status(status)
  # Format the weekly report from current node data.
  lines = [
    "📈 **Wöchentlicher Report**",
    "📅 Woche #{Time.now.strftime('%V')} - #{Time.now.strftime('%Y')}",
    "",
    "**Nodes:**"
  ]
  lines.concat(status["nodes"].values.map { |item| "- #{item['name']}: #{item['status']}" })
  lines.join("\n") + "\n"
end

def send_to_channel(message, channel_type = "telegram", channel_id = "-1002381931352")
  # Sendet Nachricht an Channel
  if channel_type == "telegram"
    # Nutze OpenClaw message tool
    cmd = ["openclaw", "message", "send", "--target", channel_id, "--message", message]
  else
    log("Channel type #{channel_type} not implemented", "WARN")
    return false
  end

  begin
    result = Open3.capture3(*cmd)
    if result[1].success?
      log("Message sent to #{channel_type} #{channel_id}")
      true
    else
      log("Failed to send: #{result[2]}", "ERROR")
      false
    end
  rescue StandardError => e
    log("Send error: #{e}", "ERROR")
    false
  end
end

def main
  # Hauptfunktion
  require 'optparse'

  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: channel_status.rb [options]"

    opts.on("--type TYPE", [:daily, :weekly, :alert], "Type of status update") do |v|
      options[:type] = v
    end

    opts.on("--message MESSAGE", "Alert message") do |v|
      options[:message] = v
    end

    opts.on("--channel CHANNEL", "Channel ID") do |v|
      options[:channel] = v
    end

    opts.on("--dry-run", "Dry run mode") do |v|
      options[:dry_run] = v
    end
  end.parse!

  raise OptionParser::MissingArgument, "--type" unless options[:type]

  log("Starting #{options[:type]} status update")

  # Status sammeln
  status = get_system_status

  # Message formatieren
  message = case options[:type]
            when :daily
              format_daily_status(status)
            when :weekly
              format_weekly_status(status)
            when :alert
              "🚨 **ALERT**\n#{options[:message] || 'Manual alert'}"
            end

  # Senden oder Dry-Run
  if options[:dry_run]
    puts "\n--- DRY RUN ---"
    puts message
    puts "--- END ---"
  else
    send_to_channel(message, channel_id: options[:channel] || "-1002381931352")
  end

  log("Status update completed")
end

if __FILE__ == $0
  require 'pathname'
  require 'set'
  require 'open3'

  FileUtils.mkdir_p(LOG_FILE.dirname)
  main
end
