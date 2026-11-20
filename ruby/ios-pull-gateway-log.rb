#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "24ceaaffab410d6cbc8efdb8a751a43b4c4e9c01aa7200e99019e3aba9bdc56b", "source_sha256": "994170e8e95ae7e8bd7564512b31b67821e81c5b77b3b9fd41bad3d0fc2ee46c", "target_language": "ruby"}
# ios-pull-gateway-log.sh — portiert nach ruby
# Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/dev/ios-pull-gateway-log.sh
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

require 'open3'
require 'fileutils'

# Standardwerte setzen
device_udid = ARGV[0] || '00008130-000630CE0146001C'
bundle_id = ARGV[1] || 'ai.openclaw.ios.dev.mariano.test'
dest = ARGV[2] || '/tmp/openclaw-gateway.log'

# xcrun devicectl Befehl ausführen
cmd = [
  'xcrun', 'devicectl', 'device', 'copy', 'from',
  '--device', device_udid,
  '--domain-type', 'appDataContainer',
  '--domain-identifier', bundle_id,
  '--source', 'Documents/openclaw-gateway.log',
  '--destination', dest
]

stdout, stderr, status = Open3.capture3(*cmd)

# Fehler überprüfen
unless status.success?
  STDERR.puts "Fehler beim Kopieren der Datei: #{stderr}"
  exit status.exitstatus
end

# Erfolgsmeldung ausgeben
puts "Pulled to: #{dest}"

# Letzte 200 Zeilen der Datei anzeigen
if File.exist?(dest)
  lines = File.readlines(dest)
  puts lines.last(200)
else
  STDERR.puts "Zieldatei nicht gefunden: #{dest}"
  exit 1
end
