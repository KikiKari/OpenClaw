#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "6c14f93b0c6eef06bab201ce8b25266e6f754d0e4e444ad981966cd06820b05d", "source_sha256": "8621f6f7e524474de82b3d877ee62bbcbd9fa3b247b69c437b063b71fa995f5a", "target_language": "ruby"}
# ops-hub-heartbeat.js — portiert nach ruby
# Quelle: javascript, OpenClaw@gateway1:scripts/ops-hub-heartbeat.js
# auch in: OpenClaw@gateway2:scripts/ops-hub-heartbeat.js
# Erzeugt: 2026-11-17 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'

# Aktualisiere den Statusbericht mit aktueller Zeit
status_path = File.join(File.dirname(__FILE__), '../docs/ops-hub/status.md')

def update_heartbeat(status_path)
  content = nil
  begin
    content = File.read(status_path, encoding: 'UTF-8')
  rescue => err
    puts "❌ Konnte status.md nicht lesen: #{err.message}"
    return
  end

  now = Time.now.localtime('+01:00').strftime('%d.%m.%Y, %H:%M:%S')
  updated = content.gsub(/(Letzter Heartbeat:) [^\n]*/, "\\1 #{now}")

  begin
    File.write(status_path, updated, encoding: 'UTF-8')
    puts "✅ Heartbeat aktualisiert: #{now}"
  rescue => err
    puts "❌ Konnte status.md nicht schreiben: #{err.message}"
  end
end

update_heartbeat(status_path)
