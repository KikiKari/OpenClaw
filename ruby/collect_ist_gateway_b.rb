#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "f5451c6a79c5795489163e89acb2db02c6d4de49ebc3d3b86524fb0a6cdefbfe", "source_sha256": "da890cc26fb848b78b6a85373d6cfa4e08f6e7c2002921e1c0247960b8b361d7", "target_language": "ruby"}
# collect_ist_gateway_b.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway2:scripts/collect_ist_gateway_b.sh
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'
require 'json'
require 'open3'

# Konfiguration
BASE_DIR = "#{ENV['HOME']}/.openclaw"
OUT_DIR = "#{BASE_DIR}/workspace/vscode"
NOW_UTC = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
NOW_LOCAL = Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")
TS = Time.now.strftime("%Y%m%d-%H%M%S")

# Ausgabeverzeichnis erstellen
FileUtils.mkdir_p(OUT_DIR)

# Dateipfade
IST_FILE = "#{OUT_DIR}/IST-ZUSTAND_GATEWAY-B_NODE7.md"
INV_FILE = "#{OUT_DIR}/ARTEFAKT-INVENTAR_GATEWAY-B_NODE7.md"
CFG_FILE = "#{OUT_DIR}/OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-B_NODE7.md"
ENV_FILE = "#{OUT_DIR}/ENV-STATUS_GATEWAY-B_NODE7.md"
RUN_FILE = "#{OUT_DIR}/RUN-#{TS}.md"

OPENCLAW_JSON = "#{BASE_DIR}/openclaw.json"
ENV_DOT = "#{BASE_DIR}/.env"
ENV_SYSTEMD = "#{BASE_DIR}/gateway.systemd.env"
VSCODE_DIR = "#{BASE_DIR}/.vscode"

# Systeminformationen sammeln
def safe_execute(command)
  stdout, stderr, status = Open3.capture3(command)
  status.success? ? stdout.strip : ""
rescue
  ""
end

def get_os_pretty_name
  if File.exist?("/etc/os-release")
    File.readlines("/etc/os-release").each do |line|
      if line.start_with?("PRETTY_NAME=")
        return line.split("=", 2)[1].strip.delete('"')
      end
    end
  end
  ""
rescue
  ""
end

HOSTNAME_FQDN = safe_execute("hostname -f")
HOSTNAME_SHORT = safe_execute("hostname")
ARCH = safe_execute("uname -m")
KERNEL = safe_execute("uname -r")
OS_PRETTY = get_os_pretty_name
IPV4_ALL = safe_execute("hostname -I").split(" ").join(" ")
PUBLIC_IP = safe_execute("curl -4 -s --max-time 4 ifconfig.me")
TAILSCALE_IP = safe_execute("tailscale ip -4").lines.first&.strip || ""

OPENCLAW_VER = safe_execute("openclaw --version")
NODE_VER = safe_execute("node -v")

# Fallback-Werte setzen
PUBLIC_IP = "(nicht ermittelt)" if PUBLIC_IP.empty?
TAILSCALE_IP = "(nicht ermittelt)" if TAILSCALE_IP.empty?
OPENCLAW_VER = "(nicht ermittelt)" if OPENCLAW_VER.empty?
NODE_VER = "(nicht ermittelt)" if NODE_VER.empty?

# IST-Zustand Datei erstellen
File.open(IST_FILE, 'w') do |file|
  file.puts "# IST-Zustand: Gateway B / Node 7"
  file.puts
  file.puts "Stand (lokal): #{NOW_LOCAL}  "
  file.puts "Stand (UTC): #{NOW_UTC}"
  file.puts
  file.puts "## 1) Identität & System"
  file.puts
  file.puts "- Gateway: **B**"
  file.puts "- Node: **7**"
  file.puts "- Hostname (short): `#{HOSTNAME_SHORT}`"
  file.puts "- Hostname (FQDN): `#{HOSTNAME_FQDN}`"
  file.puts "- Architektur: `#{ARCH}`"
  file.puts "- Kernel: `#{KERNEL}`"
  file.puts "- OS: `#{OS_PRETTY}`"
  file.puts "- IPv4 (lokal): `#{IPV4_ALL}`"
  file.puts "- Public IPv4: `#{PUBLIC_IP}`"
  file.puts "- Tailscale IPv4: `#{TAILSCALE_IP}`"
  file.puts "- OpenClaw Version: `#{OPENCLAW_VER}`"
  file.puts "- Node.js Version: `#{NODE_VER}`"
  file.puts
  file.puts "## 2) Arbeitsverzeichnisse"
  file.puts
  file.puts "- Basis: `#{BASE_DIR}`"
  file.puts "- Funktionell VSCode: `#{VSCODE_DIR}`"
  file.puts "- Workspace Doku: `#{OUT_DIR}`"
  file.puts
  file.puts "## 3) Kernartefakte (Existenz)"
  file.puts
  file.puts "- `#{OPENCLAW_JSON}`: #{File.exist?(OPENCLAW_JSON) ? 'vorhanden' : 'fehlt'}"
  file.puts "- `#{ENV_DOT}`: #{File.exist?(ENV_DOT) ? 'vorhanden' : 'fehlt'}"
  file.puts "- `#{ENV_SYSTEMD}`: #{File.exist?(ENV_SYSTEMD) ? 'vorhanden' : 'fehlt'}"
  file.puts "- `#{BASE_DIR}/plugins/installs.json`: #{File.exist?("#{BASE_DIR}/plugins/installs.json") ? 'vorhanden' : 'fehlt'}"
  file.puts "- `#{BASE_DIR}/plugin-skills`: #{File.directory?("#{BASE_DIR}/plugin-skills") ? 'vorhanden' : 'fehlt'}"
  file.puts
  file.puts "## 4) Hinweis"
  file.puts
  file.puts "Diese Datei wird bei jedem Lauf neu geschrieben."
  file.puts "Zusätzlich wird ein Laufprotokoll als `RUN-*.md` erzeugt."
end

# Artefakt-Inventar erstellen
File.open(INV_FILE, 'w') do |file|
  file.puts "# Artefakt-Inventar: Gateway B / Node 7"
  file.puts
  file.puts "Stand: #{NOW_LOCAL}"
  file.puts
  file.puts "## Top-Level in ~/.openclaw"
  file.puts
  file.puts '```text'
  if Dir.exist?(BASE_DIR)
    Dir.entries(BASE_DIR).sort.each { |entry| file.puts entry unless entry.start_with?('.') }
  end
  file.puts '```'
  file.puts
  file.puts "## ~/.openclaw/.vscode"
  file.puts
  file.puts '```text'
  if Dir.exist?(VSCODE_DIR)
    Dir.entries(VSCODE_DIR).each { |entry| file.puts entry unless entry == '.' || entry == '..' }
  else
    file.puts "(nicht vorhanden)"
  end
  file.puts '```'
  file.puts
  file.puts "## plugin-skills/"
  file.puts
  file.puts '```text'
  plugin_skills_dir = "#{BASE_DIR}/plugin-skills"
  if Dir.exist?(plugin_skills_dir)
    Dir.entries(plugin_skills_dir).each { |entry| file.puts entry unless entry == '.' || entry == '..' }
  else
    file.puts "(nicht vorhanden)"
  end
  file.puts '```'
  file.puts
  file.puts "## openclaw.json Backups"
  file.puts
  file.puts '```text'
  backup_files = Dir.glob("#{BASE_DIR}/openclaw.json.bak*").sort
  if backup_files.any?
    backup_files.each { |f| file.puts File.basename(f) }
  else
    file.puts "(keine gefunden)"
  end
  file.puts '```'
end

# OpenClaw Config Snapshot erstellen
File.open(CFG_FILE, 'w') do |file|
  file.puts "# OpenClaw Config Snapshot: Gateway B / Node 7"
  file.puts
  file.puts "Stand: #{NOW_LOCAL}"
  file.puts
  file.puts "## Schlüsselpositionen (grep)"
  file.puts
  file.puts '```text'
  if File.exist?(OPENCLAW_JSON)
    begin
      content = File.read(OPENCLAW_JSON)
      keywords = ["gateway", "session", "dmScope", "auth", "secrets", "tools", "plugins", "profile", "alsoAllow", "denyCommands"]
      lines = content.lines
      lines.each_with_index do |line, index|
        if keywords.any? { |keyword| line.include?("\"#{keyword}\"") }
          file.puts "#{index + 1}: #{line.rstrip}"
        end
      end
    rescue
      file.puts "Fehler beim Lesen der Datei"
    end
  else
    file.puts "openclaw.json fehlt"
  end
  file.puts '```'
  file.puts
  file.puts "## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)"
  file.puts
  file.puts '```json'
  if File.exist?(OPENCLAW_JSON)
    begin
      lines = File.readlines(OPENCLAW_JSON)
      start_line = 579 # 580. Zeile (0-basiert)
      end_line = 779  # 780. Zeile (0-basiert)
      
      if lines.length > start_line
        actual_end = [end_line, lines.length - 1].min
        (start_line..actual_end).each do |i|
          file.puts lines[i]
        end
      end
    rescue
      file.puts "{ \"error\": \"Fehler beim Lesen der Datei\" }"
    end
  else
    file.puts "{ \"error\": \"openclaw.json fehlt\" }"
  end
  file.puts '```'
end

# ENV-Status erstellen
File.open(ENV_FILE, 'w') do |file|
  file.puts "# ENV-Status: Gateway B / Node 7"
  file.puts
  file.puts "Stand: #{NOW_LOCAL}"
  file.puts
  file.puts "## Dateien"
  file.puts
  file.puts '```text'
  [ENV_DOT, ENV_SYSTEMD].each do |env_file|
    if File.exist?(env_file)
      stat = File.stat(env_file)
      file.puts sprintf("%s %s %s %s", 
                        stat.mode.to_s(8)[-3..-1], 
                        stat.uid, 
                        stat.gid, 
                        File.basename(env_file))
    end
  end
  file.puts '```'
  file.puts
  file.puts "## .env (vollständig, ungefiltert)"
  file.puts
  file.puts '```dotenv'
  if File.exist?(ENV_DOT)
    File.readlines(ENV_DOT).each { |line| file.puts line.rstrip }
  else
    file.puts "# .env fehlt"
  end
  file.puts '```'
  file.puts
  file.puts "## gateway.systemd.env (vollständig, ungefiltert)"
  file.puts
  file.puts '```dotenv'
  if File.exist?(ENV_SYSTEMD)
    File.readlines(ENV_SYSTEMD).each { |line| file.puts line.rstrip }
  else
    file.puts "# gateway.systemd.env fehlt"
  end
  file.puts '```'
end

# Laufprotokoll erstellen
File.open(RUN_FILE, 'w') do |file|
  file.puts "# Laufprotokoll Gateway B / Node 7"
  file.puts
  file.puts "- Zeit (lokal): #{NOW_LOCAL}"
  file.puts "- Zeit (UTC): #{NOW_UTC}"
  file.puts "- Script: #{__FILE__}"
  file.puts
  file.puts "## Erzeugte Dateien"
  file.puts
  file.puts "- #{File.basename(IST_FILE)}"
  file.puts "- #{File.basename(INV_FILE)}"
  file.puts "- #{File.basename(CFG_FILE)}"
  file.puts "- #{File.basename(ENV_FILE)}"
end

# Erfolgsmeldung ausgeben
puts "OK: IST-Zustand erfasst."
puts "Ausgabeordner: #{OUT_DIR}"
puts "Dateien:"
Dir.entries(OUT_DIR).sort.each do |entry|
  puts "- #{entry}" unless entry.start_with?('.')
end
