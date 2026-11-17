#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "4937e9979bf970a83a1d85dc67fba2a5ad0aac11115bf663f46273a58310b8b8", "source_sha256": "da890cc26fb848b78b6a85373d6cfa4e08f6e7c2002921e1c0247960b8b361d7", "target_language": "ruby"}
# collect_ist_gateway_b.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway2:scripts/collect_ist_gateway_b.sh
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'pathname'
require 'fileutils'
require 'socket'
require 'open3'

# Konfiguration und Zeitstempel
base_dir = File.expand_path("~/.openclaw")
out_dir = File.join(base_dir, "workspace", "vscode")
now_utc = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
now_local = Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")
ts = Time.now.strftime("%Y%m%d-%H%M%S")

FileUtils.mkdir_p(out_dir)

# Dateipfade
ist_file = File.join(out_dir, "IST-ZUSTAND_GATEWAY-B_NODE7.md")
inv_file = File.join(out_dir, "ARTEFAKT-INVENTAR_GATEWAY-B_NODE7.md")
cfg_file = File.join(out_dir, "OPENCLAW-CONFIG-SNAPSHOT_GATEWAY-B_NODE7.md")
env_file = File.join(out_dir, "ENV-STATUS_GATEWAY-B_NODE7.md")
run_file = File.join(out_dir, "RUN-#{ts}.md")

openclaw_json = File.join(base_dir, "openclaw.json")
env_dot = File.join(base_dir, ".env")
env_systemd = File.join(base_dir, "gateway.systemd.env")
vscode_dir = File.join(base_dir, ".vscode")

# Systeminformationen sammeln
def safe_cmd(cmd)
  stdout, stderr, status = Open3.capture3(cmd)
  status.success? ? stdout.strip : ""
rescue
  ""
end

hostname_fqdn = safe_cmd("hostname -f").empty? ? Socket.gethostname : safe_cmd("hostname -f")
hostname_short = Socket.gethostname
arch = safe_cmd("uname -m")
kernel = safe_cmd("uname -r")
os_pretty = File.readlines("/etc/os-release").grep(/^PRETTY_NAME=/).first&.split("=", 2)[1]&.gsub('"', '') rescue ""
ipv4_all = safe_cmd("hostname -I").split(" ").join(", ")
public_ip = safe_cmd("timeout 4 curl -4 -s ifconfig.me")
tailscale_ip = safe_cmd("timeout 4 tailscale ip -4").lines.first&.strip rescue ""
openclaw_ver = safe_cmd("openclaw --version")
node_ver = safe_cmd("node -v")

public_ip = "(nicht ermittelt)" if public_ip.empty?
tailscale_ip = "(nicht ermittelt)" if tailscale_ip.empty?
openclaw_ver = "(nicht ermittelt)" if openclaw_ver.empty?
node_ver = "(nicht ermittelt)" if node_ver.empty?

# IST-Zustand erstellen
File.open(ist_file, "w") do |f|
  f.puts "# IST-Zustand: Gateway B / Node 7"
  f.puts
  f.puts "Stand (lokal): #{now_local}  "
  f.puts "Stand (UTC): #{now_utc}"
  f.puts
  f.puts "## 1) Identität & System"
  f.puts
  f.puts "- Gateway: **B**"
  f.puts "- Node: **7**"
  f.puts "- Hostname (short): `#{hostname_short}`"
  f.puts "- Hostname (FQDN): `#{hostname_fqdn}`"
  f.puts "- Architektur: `#{arch}`"
  f.puts "- Kernel: `#{kernel}`"
  f.puts "- OS: `#{os_pretty}`"
  f.puts "- IPv4 (lokal): `#{ipv4_all}`"
  f.puts "- Public IPv4: `#{public_ip}`"
  f.puts "- Tailscale IPv4: `#{tailscale_ip}`"
  f.puts "- OpenClaw Version: `#{openclaw_ver}`"
  f.puts "- Node.js Version: `#{node_ver}`"
  f.puts
  f.puts "## 2) Arbeitsverzeichnisse"
  f.puts
  f.puts "- Basis: `#{base_dir}`"
  f.puts "- Funktionell VSCode: `#{vscode_dir}`"
  f.puts "- Workspace Doku: `#{out_dir}`"
  f.puts
  f.puts "## 3) Kernartefakte (Existenz)"
  f.puts
  f.puts "- `#{openclaw_json}`: #{File.exist?(openclaw_json) ? "vorhanden" : "fehlt"}"
  f.puts "- `#{env_dot}`: #{File.exist?(env_dot) ? "vorhanden" : "fehlt"}"
  f.puts "- `#{env_systemd}`: #{File.exist?(env_systemd) ? "vorhanden" : "fehlt"}"
  f.puts "- `#{File.join(base_dir, "plugins/installs.json")}`: #{File.exist?(File.join(base_dir, "plugins/installs.json")) ? "vorhanden" : "fehlt"}"
  f.puts "- `#{File.join(base_dir, "plugin-skills")}`: #{Dir.exist?(File.join(base_dir, "plugin-skills")) ? "vorhanden" : "fehlt"}"
  f.puts
  f.puts "## 4) Hinweis"
  f.puts
  f.puts "Diese Datei wird bei jedem Lauf neu geschrieben."
  f.puts "Zusätzlich wird ein Laufprotokoll als `RUN-*.md` erzeugt."
end

# Artefakt-Inventar erstellen
File.open(inv_file, "w") do |f|
  f.puts "# Artefakt-Inventar: Gateway B / Node 7"
  f.puts
  f.puts "Stand: #{now_local}"
  f.puts
  f.puts "## Top-Level in ~/.openclaw"
  f.puts
  f.puts '```text'
  if Dir.exist?(base_dir)
    Dir.entries(base_dir).sort.each { |entry| f.puts entry unless entry.start_with?('.') }
  end
  f.puts '```'
  f.puts
  f.puts "## ~/.openclaw/.vscode"
  f.puts
  f.puts '```text'
  if Dir.exist?(vscode_dir)
    Dir.entries(vscode_dir).each { |entry| f.puts entry unless ['.', '..'].include?(entry) }
  else
    f.puts "(nicht vorhanden)"
  end
  f.puts '```'
  f.puts
  f.puts "## plugin-skills/"
  f.puts
  f.puts '```text'
  plugin_skills_dir = File.join(base_dir, "plugin-skills")
  if Dir.exist?(plugin_skills_dir)
    Dir.entries(plugin_skills_dir).each { |entry| f.puts entry unless ['.', '..'].include?(entry) }
  else
    f.puts "(nicht vorhanden)"
  end
  f.puts '```'
  f.puts
  f.puts "## openclaw.json Backups"
  f.puts
  f.puts '```text'
  backup_files = Dir.glob(File.join(base_dir, "openclaw.json.bak*")).sort
  if backup_files.any?
    backup_files.each { |file| f.puts File.basename(file) }
  else
    f.puts "(keine gefunden)"
  end
  f.puts '```'
end

# OpenClaw Config Snapshot erstellen
File.open(cfg_file, "w") do |f|
  f.puts "# OpenClaw Config Snapshot: Gateway B / Node 7"
  f.puts
  f.puts "Stand: #{now_local}"
  f.puts
  f.puts "## Schlüsselpositionen (grep)"
  f.puts
  f.puts '```text'
  if File.exist?(openclaw_json)
    File.readlines(openclaw_json).each_with_index do |line, index|
      if line.match(/"(gateway|session|dmScope|auth|secrets|tools|plugins|profile|alsoAllow|denyCommands)"/)
        f.puts "#{index + 1}: #{line.rstrip}"
      end
    end
  else
    f.puts "openclaw.json fehlt"
  end
  f.puts '```'
  f.puts
  f.puts "## Ausschnitt gateway/session/auth (ungefiltert, betriebsnah)"
  f.puts
  f.puts '```json'
  if File.exist?(openclaw_json)
    lines = File.readlines(openclaw_json)
    start_line = 579 # 580. Zeile (0-basiert)
    end_line = 779   # 780. Zeile (0-basiert)
    (start_line..end_line).each do |i|
      f.puts lines[i] if i < lines.length
    end
  else
    f.puts '{ "error": "openclaw.json fehlt" }'
  end
  f.puts '```'
end

# ENV-Status erstellen
File.open(env_file, "w") do |f|
  f.puts "# ENV-Status: Gateway B / Node 7"
  f.puts
  f.puts "Stand: #{now_local}"
  f.puts
  f.puts "## Dateien"
  f.puts
  f.puts '```text'
  [env_dot, env_systemd].each do |file|
    if File.exist?(file)
      stat = File.stat(file)
      f.puts sprintf("%s %s %s %s", 
                     stat.mode.to_s(8)[-3..-1], 
                     stat.uid, 
                     stat.gid, 
                     file)
    end
  end
  f.puts '```'
  f.puts
  f.puts "## .env (vollständig, ungefiltert)"
  f.puts
  f.puts '```dotenv'
  if File.exist?(env_dot)
    File.readlines(env_dot).each { |line| f.puts line.rstrip }
  else
    f.puts "# .env fehlt"
  end
  f.puts '```'
  f.puts
  f.puts "## gateway.systemd.env (vollständig, ungefiltert)"
  f.puts
  f.puts '```dotenv'
  if File.exist?(env_systemd)
    File.readlines(env_systemd).each { |line| f.puts line.rstrip }
  else
    f.puts "# gateway.systemd.env fehlt"
  end
  f.puts '```'
end

# Laufprotokoll erstellen
File.open(run_file, "w") do |f|
  f.puts "# Laufprotokoll Gateway B / Node 7"
  f.puts
  f.puts "- Zeit (lokal): #{now_local}"
  f.puts "- Zeit (UTC): #{now_utc}"
  f.puts "- Script: #{__FILE__}"
  f.puts
  f.puts "## Erzeugte Dateien"
  f.puts
  f.puts "- #{File.basename(ist_file)}"
  f.puts "- #{File.basename(inv_file)}"
  f.puts "- #{File.basename(cfg_file)}"
  f.puts "- #{File.basename(env_file)}"
end

# Erfolgsmeldung ausgeben
puts "OK: IST-Zustand erfasst."
puts "Ausgabeordner: #{out_dir}"
puts "Dateien:"
Dir.entries(out_dir).sort.each do |file|
  puts "- #{file}" unless ['.', '..'].include?(file)
end
