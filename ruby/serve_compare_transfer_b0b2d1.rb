#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "b8085c93ad1d10b553247987fb9a289e279d264a194ead6787d1c0b7a30c6d4b", "source_sha256": "b0b2d14634c78d492d814989a9bf887ffef50ac058176565e0d55191bb8ac787", "target_language": "ruby"}
# serve_compare_transfer.sh — portiert nach ruby
# Quelle: shell, OpenClaw@gateway2:scripts/serve_compare_transfer.sh
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require 'find'
require 'pathname'
require 'webrick'

COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare"
TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer"
HOST_IP = "89.58.15.220"
PORT = 80
SELF_PATH = File.realpath(__FILE__)

# Find all files in COMPARE_DIR except this script itself
files = []
Find.find(COMPARE_DIR) do |path|
  if File.file?(path) && path != SELF_PATH
    files << path
  end
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

# Change to the directory to serve
Dir.chdir(COMPARE_DIR)

# Create and start HTTP server
server = WEBrick::HTTPServer.new(
  :Port => PORT,
  :BindAddress => "0.0.0.0",
  :DocumentRoot => "."
)

# Handle interrupt signal gracefully
trap("INT") { server.shutdown }

# Start the server
server.start
