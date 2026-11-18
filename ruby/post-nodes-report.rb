#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "0607adc4fc58d44c3f34c157a129f0ed0cf806cbd400827e930577906c755a7e", "source_sha256": "04afaeaf031d1de3a9c71606dba8c1d6ea78b3b575d8ecf94af9256d4dc3886d", "target_language": "ruby"}
# post-nodes-report.js — portiert nach ruby
# Quelle: javascript, OpenClaw@gateway1:scripts/post-nodes-report.js
# auch in: OpenClaw@gateway2:scripts/post-nodes-report.js
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'
require 'json'
require 'open3'
require 'pathname'

# Pfade
DASHBOARD_PATH = File.join(File.dirname(__FILE__), '../dashboards/nodes-overview.md')
REPORT_LOG = File.join(File.dirname(__FILE__), '../logs/nodes-report.log')

# Farbcodes
C = {
  green: "\e[32m",
  yellow: "\e[33m",
  red: "\e[31m",
  reset: "\e[0m"
}

def post_report
  content = nil
  begin
    content = File.read(DASHBOARD_PATH)
  rescue => err
    puts "#{C[:red]}❌ Fehler beim Lesen der Dashboard-Datei:#{C[:reset]} #{err.message}"
    return
  end

  # Nachricht über OpenClaw message senden
  # JSON escapen und newlines maskieren
  escaped_content = JSON.generate(content).gsub('\n', '\\n')
  message_cmd = "openclaw message send --target=main --message \"$(echo #{escaped_content} | sed 's/\\\\n/\\\\\\\\n/g')\""

  begin
    stdout, stderr, status = Open3.capture3(message_cmd)
    if status.success?
      puts "#{C[:green]}✅ Report erfolgreich im 'main'-Channel gepostet.#{C[:reset]}"
      File.open(REPORT_LOG, 'a') { |f| f.puts "[#{Time.now.utc.iso8601}] Report posted." }
    else
      error_msg = stderr.empty? ? "Command failed with exit code #{status.exitstatus}" : stderr.strip
      puts "#{C[:red]}❌ Fehler beim Senden der Nachricht:#{C[:reset]} #{error_msg}"
      File.open(REPORT_LOG, 'a') { |f| f.puts "[#{Time.now.utc.iso8601}] Failed to post: #{error_msg}" }
    end
  rescue => err
    puts "#{C[:red]}❌ Fehler beim Senden der Nachricht:#{C[:reset]} #{err.message}"
    File.open(REPORT_LOG, 'a') { |f| f.puts "[#{Time.now.utc.iso8601}] Failed to post: #{err.message}" }
  end
end

# Hauptausführung
puts "#{C[:yellow]}📤 Sende Nodes-Übersicht in 'main'...#{C[:reset]}"
post_report
