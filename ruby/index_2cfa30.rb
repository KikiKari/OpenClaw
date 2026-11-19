#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "bc3c67a34a93dfa84028516e167b7b9a6b0e40f55412163c9fce27a7d541a923", "source_sha256": "2cfa301efe20d60c29e0e9f0746e5a99d405ea44a5d03839c72e6b525451fe07", "target_language": "ruby"}
# index.html — portiert nach ruby
# Quelle: html, Projects@TikTok-Live-Companion-Android:site/index.html
# auch in: Projects@TikTok-Live-Companion-iOS:site/index.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require 'optparse'

# Erzeugt die index.html fuer TikTok LIVE Companion Dokumentation
def generate_html
  <<~HTML
  <!doctype html>
  <html lang="de">
    <head>
      <meta charset="UTF-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1.0" />
      <meta name="description" content="Dokumentation f\u{fc}r TikTok LIVE Companion 0.8.0 \u{2013} Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser." />
      <meta name="theme-color" content="#ffffff" />
      <link rel="icon" type="image/png" href="/branding/staenderglobus-ios.png" />
      <link rel="apple-touch-icon" href="/branding/staenderglobus-ios.png" />
      <title>TikTok LIVE Companion \u{2013} Dokumentation</title>
    </head>
    <body>
      <div id="root"></div>
      <script type="module" src="/src/main.tsx"></script>
    </body>
  </html>
  HTML
end

# Kommandozeilenoptionen parsen
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"
  opts.on("-o", "--output FILE", "Ausgabedatei") do |file|
    options[:output] = file
  end
end.parse!

# HTML generieren
html_content = generate_html

# In Datei schreiben oder auf stdout ausgeben
if options[:output]
  File.write(options[:output], html_content)
else
  puts html_content
end
