#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "9311f1a9f0555e1a3913d6abd5320f166fe8dd60d44e06f1643cd072d0845a96", "source_sha256": "5aa602a80e57cbc63f54485d4cd66e205c54bd9f32bc03434218ff9bd388b3ab", "target_language": "ruby"}
# collect_compare_bundle.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway1:scripts/collect_compare_bundle.sh
# auch in: OpenClaw@gateway2:scripts/collect_compare_bundle.sh
# Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'
require 'pathname'
require 'time'

ROOT = "/home/openclaw/.openclaw"
OUT_DIR = "#{ROOT}/workspace/vscode/compare"
TRANSFER_DIR = "#{OUT_DIR}/transfer"
MD_FILE = "#{OUT_DIR}/local-gateway-config.md"
TREE_FILE = "#{OUT_DIR}/tree.txt"
BACKUP_FILE = "/home/openclaw/openclaw-backup.tar.gz"
NOW_LOCAL = Time.now.strftime('%Y-%m-%d %H:%M:%S %Z')
NOW_UTC = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
HOST = begin
         `hostname -f`.strip
       rescue
         `hostname`.strip
       end

OPENCLAW_JSON = "#{ROOT}/openclaw.json"
EXEC_APPROVALS_JSON = "#{ROOT}/exec-approvals.json"
GATEWAY_SYSTEMD_ENV = "#{ROOT}/gateway.systemd.env"
DOT_ENV = "#{ROOT}/.env"
CONFIG_DIR = "#{ROOT}/.config"
AGENTS_DIR = "#{ROOT}/agents"

FileUtils.mkdir_p(OUT_DIR)
FileUtils.mkdir_p(TRANSFER_DIR)

unless system("which tree > /dev/null 2>&1")
  puts "Fehler: 'tree' ist nicht installiert."
  exit 1
end

def append_file_verbatim(label, path, lang = "text")
  File.open(MD_FILE, "a") do |f|
    f.puts
    f.puts "## #{label}"
    f.puts
    f.puts "Pfad: `#{path}`"
    f.puts
    f.puts "```#{lang}"
    if File.exist?(path)
      File.foreach(path) { |line| f.write(line) }
    else
      f.puts "[FEHLT] #{path}"
    end
    f.puts
    f.puts "```"
  end
end

def append_env_verbatim
  File.open(MD_FILE, "a") do |f|
    f.puts
    f.puts "## Umgebungsvariablen (env)"
    f.puts
    f.puts "```text"
    ENV.each { |key, value| f.puts "#{key}=#{value}" }
    f.puts "```"
  end
end

def append_dir_files_verbatim(section, dir)
  File.open(MD_FILE, "a") do |f|
    f.puts
    f.puts "## #{section}"
    f.puts
    unless Dir.exist?(dir)
      f.puts "[FEHLT] #{dir}"
      return
    end
    f.puts "Basisverzeichnis: `#{dir}`"
  end

  Dir.glob("#{dir}/**/*", File::FNM_DOTMATCH).select { |f| File.file?(f) }.sort.each do |file|
    File.open(MD_FILE, "a") do |f|
      f.puts
      f.puts "### Datei: `#{file}`"
      f.puts
      f.puts "```text"
      File.foreach(file) { |line| f.write(line) }
      f.puts
      f.puts "```"
    end
  end
end

File.open(MD_FILE, "w") do |f|
  f.puts "# Lokaler Gateway-Konfigurationsstand"
  f.puts
  f.puts "Generiert: #{NOW_LOCAL}"
  f.puts "UTC: #{NOW_UTC}"
  f.puts "Host: #{HOST}"
  f.puts
  f.puts "Diese Datei enthaelt den lokalen Stand mit unveraenderten Inhalten."
end

append_file_verbatim("openclaw.json", OPENCLAW_JSON, "json")
append_file_verbatim("exec-approvals.json", EXEC_APPROVALS_JSON, "json")
append_file_verbatim("gateway.systemd.env", GATEWAY_SYSTEMD_ENV, "dotenv")
append_file_verbatim(".env", DOT_ENV, "dotenv")
append_env_verbatim
append_dir_files_verbatim(".config (alle Dateien rekursiv)", CONFIG_DIR)
append_dir_files_verbatim("agents (alle Dateien rekursiv)", AGENTS_DIR)

system("tree -a -L 6 #{ROOT.shellescape} > #{TREE_FILE.shellescape}")
system("openclaw backup create --output #{BACKUP_FILE.shellescape} --verify")
FileUtils.cp(BACKUP_FILE, OUT_DIR)

puts "OK"
puts "Erzeugt:"
puts "- #{MD_FILE}"
puts "- #{TREE_FILE}"
puts "- #{BACKUP_FILE}"
puts "- #{TRANSFER_DIR} (leer)"
