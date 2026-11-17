#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "4799e2fe7df1015482b46fcc96f01bbce866e1244ffdef6b1760c7570ed4168f", "source_sha256": "e51b94641336291974fe14bf4bb7299a75ec7dcce49e1d413282c8043e9f09f1", "target_language": "ruby"}
# openclaw-audit.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway1:scripts/openclaw-audit.sh
# auch in: OpenClaw@gateway2:scripts/openclaw-audit.sh
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

# OpenClaw read-only audit/diagnostic sweep
# Output: openclaw-audit-YYYY-MM-DD.log im selben Verzeichnis wie dieses Script

require 'pathname'
require 'date'

script_dir = Pathname.new(__FILE__).dirname.expand_path
date_stamp = DateTime.now.strftime('%Y-%m-%d')
out = script_dir.join("openclaw-audit-#{date_stamp}.log")

oc = ['openclaw', '--no-color']

File.open(out, 'w') do |file|
  file.puts "================================================================"
  file.puts "OpenClaw audit run"
  file.puts "Started:  #{DateTime.now.iso8601}"
  file.puts "Host:     #{`hostname`.strip}"
  file.puts "User:     #{`whoami`.strip}"
  version_output = `openclaw --version 2>/dev/null`
  file.puts "Version:  #{version_output.empty? ? 'unknown' : version_output.strip}"
  file.puts "Output:   #{out}"
  file.puts "================================================================"
end

def run_cmd(title, out, *cmd)
  File.open(out, 'a') do |file|
    file.puts
    file.puts "----------------------------------------------------------------"
    file.puts "### #{title}"
    file.puts "### $ #{cmd.join(' ')}"
    file.puts "### #{DateTime.now.iso8601}"
    file.puts "----------------------------------------------------------------"
    begin
      output = `#{cmd.shelljoin} 2>&1`
      file.puts output
      rc = $?.exitstatus
      file.puts "[exit: #{rc}]"
    rescue => e
      file.puts "[error: #{e.message}]"
    end
  end
end

run_cmd("tasks audit --severity error", out, *oc, 'tasks', 'audit', '--severity', 'error')
run_cmd("secrets audit", out, *oc, 'secrets', 'audit')
run_cmd("security audit", out, *oc, 'security', 'audit')
run_cmd("plugins doctor", out, *oc, 'plugins', 'doctor')
run_cmd("plugins deps", out, *oc, 'plugins', 'deps')
run_cmd("plugins registry", out, *oc, 'plugins', 'registry')
run_cmd("skills check", out, *oc, 'skills', 'check')
run_cmd("hooks check", out, *oc, 'hooks', 'check')
run_cmd("gateway status --deep", out, *oc, 'gateway', 'status', '--deep')
run_cmd("channels status --probe", out, *oc, 'channels', 'status', '--probe')
run_cmd("memory status --deep", out, *oc, 'memory', 'status', '--deep')
run_cmd("sessions --all-agents", out, *oc, 'sessions', '--all-agents')
run_cmd("tasks list", out, *oc, 'tasks', 'list')
run_cmd("cron list", out, *oc, 'cron', 'list')

File.open(out, 'a') do |file|
  file.puts
  file.puts "================================================================"
  file.puts "Audit complete: #{DateTime.now.iso8601}"
  file.puts "================================================================"
end

puts "Audit complete. Output: #{out}"
