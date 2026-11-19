#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "3136930e389969f4a1a2d4e154e845a273df32869742a43825edefe3d2469bf7", "source_sha256": "a243d1fdcbd0c82c97b2771c181438428885fd9c2feaed782f7e9eb8066fed59", "target_language": "ruby"}
# offscreen.html — portiert nach ruby
# Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/offscreen.html
# auch in: Projects@TikTok-Live-Companion-Android:plugin-source/browser-extension/offscreen.html
# auch in: Projects@TikTok-Live-Companion-iOS:plugin-source/browser-extension/offscreen.html
# auch in: Projects@vercel/install-and-configure-vercel-s-8vf8rt:plugin-source/browser-extension/offscreen.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# TikTok LIVE Companion Sprachausgabe

require 'fileutils'

def generate_offscreen_html
  <<~HTML
    <!doctype html>
    <html lang="de">
    <head>
      <meta charset="utf-8">
      <title>TikTok LIVE Companion Sprachausgabe</title>
    </head>
    <body>
      <script src="offscreen.js"></script>
    </body>
    </html>
  HTML
end

def main
  if ARGV.length != 1
    puts "Verwendung: #{$0} <ausgabedatei>"
    exit 1
  end

  output_file = ARGV[0]
  
  # Stelle sicher, dass das Verzeichnis existiert
  FileUtils.mkdir_p(File.dirname(output_file)) rescue nil
  
  # Schreibe die HTML-Struktur in die Datei
  File.open(output_file, 'w') do |file|
    file.write(generate_offscreen_html)
  end
  
  puts "HTML-Dokument wurde erfolgreich erstellt: #{output_file}"
end

main if __FILE__ == $0
