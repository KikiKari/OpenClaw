#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "7b4017ed84267ded667c3307e36be9286f8c523ff821abcc6ffaa7d5506357f1", "source_sha256": "47064dbc7b32c01d57d42222f8cc3ac7caf9c8d82b98029dc5fc6ecb0d32f2c9", "target_language": "ruby"}
# collect_ist_gateway_a.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway1:scripts/collect_ist_gateway_a.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'
require 'pathname'
require 'open3'
require 'net/http'
require 'uri'

def run_command(cmd)
  stdout, stderr, status = Open3.capture3(cmd)
  return stdout.strip if status.success?
  ""
rescue
  ""
end

def get_public_ip
  uri = URI('http://ifconfig.me')
  Net::HTTP.start(uri.host, uri.port, open_timeout: 4, read_timeout: 4) do |http|
    request = Net::HTTP::Get.new(uri)
    response = http.request(request)
    return response.body.strip if response.code == '200'
  end
  "(nicht ermittelt)"
rescue
  "(nicht ermittelt)"
end

def get_tailscale_ip
  stdout, stderr, status = Open3.capture3("tailscale ip -4")
  return stdout.lines.first.strip if status.success? && !stdout.empty?
  "(nicht ermittelt)"
rescue
  "(nicht ermittelt)"
end

BASE_DIR = "#{ENV['HOME']}/.openclaw"
OUT_DIR = "#{BASE_DIR}/workspace/vscode"
NOW_UTC = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
NOW_LOCAL = Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")
TS = Time.now.strftime("%Y%m%d-%H%M%S")

FileUtils.mkdir_p(OUT_DIR)

IST_FILE = "#{OUT_DIR}/IST-ZUSTAND_GATEWAY-A_NODE1.md"
INV_FILE = "#{OUT_DIR}/ARTEFAKT-INVENTAR_GATEWAY-A_NODE1.md"
CFG_FILE = "#{OUT_DIR}/OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-A_NODE1.md"
ENV_FILE = "#{OUT_DIR}/ENV-STATUS_GATEWAY-A_NODE1.md"
RUN_FILE = "#{OUT_DIR}/RUN-#{TS}.md"

OPENCLAW_JSON = "#{BASE_DIR}/openclaw.json"
ENV_DOT = "#{BASE_DIR}/.env"
ENV_SYSTEMD = "#{BASE_DIR}/gateway.systemd.env"
VSCODE_DIR = "#{BASE_DIR}/.vscode"

HOSTNAME_FQDN = run_command("hostname -f").empty? ? run_command("hostname") : run_command("hostname -f")
HOSTNAME_SHORT = run_command("hostname")
ARCH = run_command("uname -m")
KERNEL = run_command("uname -r")
OS_PRETTY = begin
  line = File.readlines("/etc/os-release").find { |l| l.start_with?("PRETTY_NAME=") }
  line ? line.split("=", 2)[1].gsub('"', '').strip : ""
rescue
  ""
end
IPV4_ALL = run_command("hostname -I").gsub(/\s+/, " ").strip
PUBLIC_IP = get_public_ip
TAILSCALE_IP = get_tailscale_ip
OPENCLAW_VER = run_command("openclaw --version")
NODE_VER = run_command("node -v")

PUBLIC_IP = "(nicht ermittelt)" if PUBLIC_IP.empty?
TAILSCALE_IP = "(nicht ermittelt)" if TAILSCALE_IP.empty?
OPENCLAW_VER = "(nicht ermittelt)" if OPENCLAW_VER.empty?
NODE_VER = "(nicht ermittelt)" if NODE_VER.empty?

File.open(IST_FILE, 'w') do |f|
  f.puts "# IST-Zustand: Gateway A / Node 1"
  f.puts
  f.puts "Stand (lokal): #{NOW_LOCAL}  "
  f.puts "Stand (UTC): #{NOW_UTC}"
  f.puts
  f.puts "## 1) Identitaet & System"
  f.puts
  f.puts "- Gateway: **A**"
  f.puts "- Node: **1**"
  f.puts "- Hostname (short): `#{HOSTNAME_SHORT}`"
  f.puts "- Hostname (FQDN): `#{HOSTNAME_FQDN}`"
  f.puts "- Architektur: `#{ARCH}`"
  f.puts "- Kernel: `#{KERNEL}`"
  f.puts "- OS: `#{OS_PRETTY}`"
  f.puts "- IPv4 (lokal): `#{IPV4_ALL}`"
  f.puts "- Public IPv4: `#{PUBLIC_IP}`"
  f.puts "- Tailscale IPv4: `#{TAILSCALE_IP}`"
  f.puts "- OpenClaw Version: `#{OPENCLAW_VER}`"
  f.puts "- Node.js Version: `#{NODE_VER}`"
  f.puts
  f.puts "## 2) Arbeitsverzeichnisse"
  f.puts
  f.puts "- Basis: `#{BASE_DIR}`"
  f.puts "- Funktionell VSCode: `#{VSCODE_DIR}`"
  f.puts "- Workspace Doku: `#{OUT_DIR}`"
  f.puts
  f.puts "## 3) Kernartefakte (Existenz)"
  f.puts
  f.puts "- `#{OPENCLAW_JSON}`: #{File.exist?(OPENCLAW_JSON) ? 'vorhanden' : 'fehlt'}"
  f.puts "- `#{ENV_DOT}`: #{File.exist?(ENV_DOT) ? 'vorhanden' : 'fehlt'}"
  f.puts "- `#{ENV_SYSTEMD}`: #{File.exist?(ENV_SYSTEMD) ? 'vorhanden' : 'fehlt'}"
  f.puts "- `#{BASE_DIR}/plugins/installs.json`: #{File.exist?("#{BASE_DIR}/plugins/installs.json") ? 'vorhanden' : 'fehlt'}"
  f.puts "- `#{BASE_DIR}/plugin-skills`: #{File.directory?("#{BASE_DIR}/plugin-skills") ? 'vorhanden' : 'fehlt'}"
end

File.open(INV_FILE, 'w') do |f|
  f.puts "# Artefakt-Inventar: Gateway A / Node 1"
  f.puts
  f.puts "Stand: #{NOW_LOCAL}"
  f.puts
  f.puts "## Top-Level in ~/.openclaw"
  f.puts
  f.puts '```text'
  if Dir.exist?(BASE_DIR)
    Dir.entries(BASE_DIR).sort.each do |entry|
      next if ['.', '..'].include?(entry)
      f.puts entry
    end
  end
  f.puts '```'
  f.puts
  f.puts "## ~/.openclaw/.vscode"
  f.puts
  f.puts '```text'
  if Dir.exist?(VSCODE_DIR)
    Dir.entries(VSCODE_DIR).sort.each do |entry|
      next if ['.', '..'].include?(entry)
      stat = File.stat("#{VSCODE_DIR}/#{entry}")
      permissions = "%o" % (stat.mode & 0777)
      f.puts "#{permissions} #{stat.mtime.strftime('%Y-%m-%d %H:%M')} #{entry}"
    end
  else
    f.puts "(nicht vorhanden)"
  end
  f.puts '```'
  f.puts
  f.puts "## plugin-skills/"
  f.puts
  f.puts '```text'
  if Dir.exist?("#{BASE_DIR}/plugin-skills")
    Dir.entries("#{BASE_DIR}/plugin-skills").sort.each do |entry|
      next if ['.', '..'].include?(entry)
      f.puts entry
    end
  else
    f.puts "(nicht vorhanden)"
  end
  f.puts '```'
  f.puts
  f.puts "## openclaw.json Backups"
  f.puts
  f.puts '```text'
  backups = Dir.glob("#{BASE_DIR}/openclaw.json.bak*").sort
  if backups.any?
    backups.each { |backup| f.puts File.basename(backup) }
  else
    f.puts "(keine gefunden)"
  end
  f.puts '```'
end

File.open(CFG_FILE, 'w') do |f|
  f.puts "# OpenClaw Config Snapshot: Gateway A / Node 1"
  f.puts
  f.puts "Stand: #{NOW_LOCAL}"
  f.puts
  f.puts "## Schluesselpositionen (grep)"
  f.puts
  f.puts '```text'
  if File.exist?(OPENCLAW_JSON)
    lines = File.readlines(OPENCLAW_JSON)
    lines.each_with_index do |line, index|
      if line =~ /"gateway"|\"session\"|\"dmScope\"|\"auth\"|\"secrets\"|\"tools\"|\"plugins\"|\"profile\"|\"alsoAllow\"|\"denyCommands\"/
        f.puts "#{index + 1}: #{line.rstrip}"
      end
    end
  else
    f.puts "openclaw.json fehlt"
  end
  f.puts '```'
  f.puts
  f.puts "## Ausschnitt gateway/session/auth"
  f.puts
  f.puts '```json'
  if File.exist?(OPENCLAW_JSON)
    lines = File.readlines(OPENCLAW_JSON)
    start_line = 579
    end_line = 779
    start_line = 0 if start_line >= lines.length
    end_line = lines.length - 1 if end_line >= lines.length
    ((start_line)..[end_line, lines.length - 1].min).each do |i|
      f.puts lines[i] if i < lines.length
    end
  else
    f.puts '{ "error": "openclaw.json fehlt" }'
  end
  f.puts '```'
end

File.open(ENV_FILE, 'w') do |f|
  f.puts "# ENV-Status: Gateway A / Node 1"
  f.puts
  f.puts "Stand: #{NOW_LOCAL}"
  f.puts
  f.puts "## Dateien"
  f.puts
  f.puts '```text'
  [ENV_DOT, ENV_SYSTEMD].each do |file|
    if File.exist?(file)
      stat = File.stat(file)
      permissions = "%o" % (stat.mode & 0777)
      f.puts "#{permissions} #{stat.mtime.strftime('%Y-%m-%d %H:%M')} #{file}"
    end
  end
  f.puts '```'
  f.puts
  f.puts "## .env (vollstaendig)"
  f.puts
  f.puts '```dotenv'
  if File.exist?(ENV_DOT)
    File.readlines(ENV_DOT).each { |line| f.puts line.rstrip }
  else
    f.puts "# .env fehlt"
  end
  f.puts '```'
  f.puts
  f.puts "## gateway.systemd.env (vollstaendig)"
  f.puts
  f.puts '```dotenv'
  if File.exist?(ENV_SYSTEMD)
    File.readlines(ENV_SYSTEMD).each { |line| f.puts line.rstrip }
  else
    f.puts "# gateway.systemd.env fehlt"
  end
  f.puts '```'
end

File.open(RUN_FILE, 'w') do |f|
  f.puts "# Laufprotokoll Gateway A / Node 1"
  f.puts
  f.puts "- Zeit (lokal): #{NOW_LOCAL}"
  f.puts "- Zeit (UTC): #{NOW_UTC}"
  f.puts "- Script: #{File.expand_path($0)}"
  f.puts
  f.puts "## Erzeugte Dateien"
  f.puts
  f.puts "- #{File.basename(IST_FILE)}"
  f.puts "- #{File.basename(INV_FILE)}"
  f.puts "- #{File.basename(CFG_FILE)}"
  f.puts "- #{File.basename(ENV_FILE)}"
end

puts "OK: IST-Zustand erfasst."
Dir.entries(OUT_DIR).sort.each do |entry|
  next if ['.', '..'].include?(entry)
  puts "- #{entry}"
end
