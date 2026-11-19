#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "ee2d64d1cd66b6ba55f534196443b4b19dbdd508ed27b2fde05b2b5fbea699d1", "source_sha256": "d5eb18db536b690023fd61c3dfa4d99f899ec602247f48fb044c53baebb78556", "target_language": "ruby"}
# serve_compare_transfer.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway1:scripts/serve_compare_transfer.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require 'find'
require 'pathname'

COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare"
TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer"
HOST_IP = "152.53.145.65"
PORT = "80"
SELF_PATH = File.realpath(__FILE__)

files = []
Find.find(COMPARE_DIR) do |path|
  if File.file?(path) && path != SELF_PATH
    files << path
  end
  Find.prune if File.dirname(path) != COMPARE_DIR
end

files.sort!

if files.empty?
  puts "Keine Dateien in #{COMPARE_DIR} gefunden."
  exit 1
end

puts
puts "Bereitgestellte Dateien aus #{COMPARE_DIR}:"
files.each do |src|
  puts "- #{File.basename(src)}"
end

puts
puts "Copy/Paste auf anderem Gateway (Download nach #{TRANSFER_DIR}):"
files.each do |src|
  file = File.basename(src)
  puts "curl -fL --retry 3 --connect-timeout 10 -o #{TRANSFER_DIR}/#{file} http://#{HOST_IP}:#{PORT}/#{file}"
end

puts
puts "Server auf Port #{PORT} aktiv. Beenden mit STRG+C."
puts

Dir.chdir(COMPARE_DIR)
exec("python3", "-m", "http.server", PORT, "--bind", "0.0.0.0")
