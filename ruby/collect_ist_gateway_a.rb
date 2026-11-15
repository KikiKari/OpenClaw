#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "5c72c5e79601a4d6ba156b28df52235e90c1a7672e8aae3e97ebad7db44df65d", "source_sha256": "47064dbc7b32c01d57d42222f8cc3ac7caf9c8d82b98029dc5fc6ecb0d32f2c9", "target_language": "ruby"}
# collect_ist_gateway_a.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway1:scripts/collect_ist_gateway_a.sh
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'
require 'json'
require 'open3'

# Konfiguration und Zeitstempel
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

# Systeminformationen sammeln
def safe_cmd(cmd)
  stdout, stderr, status = Open3.capture3(cmd)
  status.success? ? stdout.strip : "(nicht ermittelt)"
rescue
  "(nicht ermittelt)"
end

HOSTNAME_FQDN = safe_cmd("hostname -f")
HOSTNAME_SHORT = safe_cmd("hostname")
ARCH = safe_cmd("uname -m")
KERNEL = safe_cmd("uname -r")
OS_PRETTY = File.exist?("/etc/os-release") ? 
  File.readlines("/etc/os-release").find { |line| line.start_with?("PRETTY_NAME=") }&.split("=", 2)[1]&.gsub('"', '') || "" : ""
IPV4_ALL = safe_cmd("hostname -I")
PUBLIC_IP = safe_cmd("curl -4 -s --max-time 4 ifconfig.me")
TAILSCALE_IP = safe_cmd("tailscale ip -4")
OPENCLAW_VER = safe_cmd("openclaw --version")
NODE_VER = safe_cmd("node -v")

# Hilfsfunktion für Dateiexistenz
def file_status(path)
  File.exist?(path) ? "vorhanden" : "fehlt"
end

# IST-Zustand erstellen
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
  f.puts "- `#{OPENCLAW_JSON}`: #{file_status(OPENCLAW_JSON)}"
  f.puts "- `#{ENV_DOT}`: #{file_status(ENV_DOT)}"
  f.puts "- `#{ENV_SYSTEMD}`: #{file_status(ENV_SYSTEMD)}"
  f.puts "- `#{BASE_DIR}/plugins/installs.json`: #{file_status("#{BASE_DIR}/plugins/installs.json")}"
  f.puts "- `#{BASE_DIR}/plugin-skills`: #{file_status("#{BASE_DIR}/plugin-skills")}"
end

# Artefakt-Inventar erstellen
File.open(INV_FILE, 'w') do |f|
  f.puts "# Artefakt-Inventar: Gateway A / Node 1"
  f.puts
  f.puts "Stand: #{NOW_LOCAL}"
  f.puts
  f.puts "## Top-Level in ~/.openclaw"
  f.puts
  f.puts '```text'
  if Dir.exist?(BASE_DIR)
    Dir.entries(BASE_DIR).sort.each { |entry| f.puts entry unless entry.start_with?('.') }
  end
  f.puts '```'
  f.puts
  f.puts "## ~/.openclaw/.vscode"
  f.puts
  f.puts '```text'
  if Dir.exist?(VSCODE_DIR)
    Dir.entries(VSCODE_DIR).each { |entry| f.puts entry unless entry == '.' || entry == '..' }
  else
    f.puts "(nicht vorhanden)"
  end
  f.puts '```'
  f.puts
  f.puts "## plugin-skills/"
  f.puts
  f.puts '```text'
  plugin_skills_dir = "#{BASE_DIR}/plugin-skills"
  if Dir.exist?(plugin_skills_dir)
    Dir.entries(plugin_skills_dir).each { |entry| f.puts entry unless entry == '.' || entry == '..' }
  else
    f.puts "(nicht vorhanden)"
  end
  f.puts '```'
  f.puts
  f.puts "## openclaw.json Backups"
  f.puts
  f.puts '```text'
  backup_files = Dir.glob("#{BASE_DIR}/openclaw.json.bak*").sort
  if backup_files.empty?
    f.puts "(keine gefunden)"
  else
    backup_files.each { |file| f.puts File.basename(file) }
  end
  f.puts '```'
end

# OpenClaw Config Snapshot erstellen
File.open(CFG_FILE, 'w') do |f|
  f.puts "# OpenClaw Config Snapshot: Gateway A / Node 1"
  f.puts
  f.puts "Stand: #{NOW_LOCAL}"
  f.puts
  f.puts "## Schluesselpositionen (grep)"
  f.puts
  f.puts '```text'
  if File.exist?(OPENCLAW_JSON)
    begin
      content = File.read(OPENCLAW_JSON)
      keywords = ["gateway", "session", "dmScope", "auth", "secrets", "tools", "plugins", "profile", "alsoAllow", "denyCommands"]
      lines = content.lines
      lines.each_with_index do |line, index|
        if keywords.any? { |keyword| line.include?("\"#{keyword}\"") }
          f.puts "#{index + 1}: #{line.rstrip}"
        end
      end
    rescue => e
      f.puts "Fehler beim Lesen: #{e.message}"
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
    begin
      lines = File.readlines(OPENCLAW_JSON)
      start_line = 579 # 580 - 1 wegen 0-basierter Index
      end_line = 779   # 780 - 1 wegen 0-basierter Index
      start_line = [start_line, lines.length - 1].min
      end_line = [end_line, lines.length - 1].min
      
      (start_line..end_line).each do |i|
        f.puts lines[i] if i < lines.length
      end
    rescue => e
      f.puts "{ \"error\": \"Fehler beim Lesen: #{e.message}\" }"
    end
  else
    f.puts '{ "error": "openclaw.json fehlt" }'
  end
  f.puts '```'
end

# ENV-Status erstellen
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
      f.puts sprintf("%s %s %s %s", 
                     stat.mode.to_s(8)[-3..-1], 
                     stat.uid, 
                     stat.mtime.strftime("%Y-%m-%d %H:%M"),
                     File.basename(file))
    end
  end
  f.puts '```'
  f.puts
  f.puts "## .env (vollstaendig)"
  f.puts
  f.puts '```dotenv'
  if File.exist?(ENV_DOT)
    f.write(File.read(ENV_DOT))
  else
    f.puts "# .env fehlt"
  end
  f.puts '```'
  f.puts
  f.puts "## gateway.systemd.env (vollstaendig)"
  f.puts
  f.puts '```dotenv'
  if File.exist?(ENV_SYSTEMD)
    f.write(File.read(ENV_SYSTEMD))
  else
    f.puts "# gateway.systemd.env fehlt"
  end
  f.puts '```'
end

# Laufprotokoll erstellen
File.open(RUN_FILE, 'w') do |f|
  f.puts "# Laufprotokoll Gateway A / Node 1"
  f.puts
  f.puts "- Zeit (lokal): #{NOW_LOCAL}"
  f.puts "- Zeit (UTC): #{NOW_UTC}"
  f.puts "- Script: #{File.expand_path(__FILE__)}"
  f.puts
  f.puts "## Erzeugte Dateien"
  f.puts
  f.puts "- #{File.basename(IST_FILE)}"
  f.puts "- #{File.basename(INV_FILE)}"
  f.puts "- #{File.basename(CFG_FILE)}"
  f.puts "- #{File.basename(ENV_FILE)}"
end

# Erfolgsmeldung ausgeben
puts "OK: IST-Zustand erfasst."
Dir.entries(OUT_DIR).select { |f| File.file?("#{OUT_DIR}/#{f}") }.sort.each do |file|
  puts "- #{file}"
end
