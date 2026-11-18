#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "0655962eaefe376fdd941a3c937b24aec0589f91bf0f132c8f80e982862016d1", "source_sha256": "9245a78489adb3949ae2a56f5e0987a465142b9a8ee97bddaca453f5011daef8", "target_language": "ruby"}
# index.html — portiert nach ruby
# Quelle: html, Projects@Program-Derivation:public/index.html
# auch in: Projects@Vision-Check:public/index.html
# auch in: Projects@Weather-Check:public/index.html
# auch in: Projects@abstractions:public/index.html
# auch in: 5 weiteren Fundstellen
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'

def generate_html_document
  html_content = <<~HTML
    <!DOCTYPE html>
    <html lang="de">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="refresh" content="0; url=3d.html">
    <title>Weiterleitung zur 3D-Ansicht</title>
    <link rel="canonical" href="3d.html">
    <script>location.replace('3d.html');</script>
    </head>
    <body>
    <p><a href="3d.html">3D-Ansicht öffnen</a></p>
    </body>
    </html>
  HTML
  
  html_content.strip
end

def write_html_to_file(filename)
  File.write(filename, generate_html_document)
  puts "HTML document written to #{filename}"
end

if __FILE__ == $0
  if ARGV.length != 1
    puts "Usage: #{$0} <output_filename>"
    exit 1
  end
  
  output_filename = ARGV[0]
  write_html_to_file(output_filename)
end
