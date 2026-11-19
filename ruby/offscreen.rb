#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "f8cc1338bc1361e7ca2cbba5d58fe97d7fa9f689ed224b47f7d25de0ecc61173", "source_sha256": "a5de51b02b40bbdeafb7fb0f4da19091ec351b10a9160307085ebcef403cdd67", "target_language": "ruby"}
# offscreen.html — portiert nach ruby
# Quelle: html, Projects@TikTok-Live-Companion:release/0.7.1/tiktok-live-companion-extension-0.7.1/offscreen.html
# auch in: Projects@TikTok-Live-Companion-Android:release/0.7.1/tiktok-live-companion-extension-0.7.1/offscreen.html
# auch in: Projects@TikTok-Live-Companion-iOS:release/0.7.1/tiktok-live-companion-extension-0.7.1/offscreen.html
# auch in: Projects@vercel/install-and-configure-vercel-w-98sxlo:plugin-source/browser-extension/offscreen.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# Methode zum Erstellen des HTML-Dokuments
def create_html_document
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

# Hauptprogramm
if __FILE__ == $0
  # Prüfe ob ein Parameter übergeben wurde
  if ARGV.length != 1
    puts "Verwendung: #{$0} <dateiname>"
    puts "Erstellt ein HTML-Dokument und speichert es in die angegebene Datei"
    exit 1
  end

  # Hole den Dateinamen aus den Parametern
  filename = ARGV[0]

  # Erstelle den HTML-Inhalt
  html_content = create_html_document

  # Schreibe den Inhalt in die Datei
  File.open(filename, 'w') do |file|
    file.write(html_content)
  end

  puts "HTML-Dokument wurde erfolgreich erstellt und in '#{filename}' gespeichert."
end
