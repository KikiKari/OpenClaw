#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "5222cf6256e9a44803b769b919bdf753655250aa4db59ae782bb8908edbd1be3", "source_sha256": "f1fb75db28e47070c42c0b401c9bdae5ac468bcd98550232038e409983691fad", "target_language": "ruby"}
# chat.css — portiert nach ruby
# Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat.css
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'

# Funktion zum Erstellen der CSS-Imports
def create_chat_css(output_file)
  # CSS-Inhalt erstellen
  css_content = <<~CSS
  @import "./chat/layout.css";
  @import "./chat/text.css";
  @import "./chat/grouped.css";
  @import "./chat/tool-cards.css";
  @import "./chat/sidebar.css";
  CSS

  # Verzeichnis erstellen falls nicht vorhanden
  dir = File.dirname(output_file)
  FileUtils.mkdir_p(dir) unless Dir.exist?(dir)

  # CSS-Datei schreiben
  File.write(output_file, css_content.strip + "\n")
  
  puts "CSS file created: #{output_file}"
end

# Hauptprogramm
if __FILE__ == $0
  # Parameterprüfung
  if ARGV.length != 1
    puts "Usage: #{$0} <output_file>"
    exit 1
  end

  output_file = ARGV[0]
  create_chat_css(output_file)
end
