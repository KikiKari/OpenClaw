#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "af3579ac9b6dc41d39f4379b60e6dcb78afa4554b1b8afd6daa0bd0c6ccd6a56", "source_sha256": "735fe4b2c74b10f265f715cd4e85d574f46a7132d2e592703b5e712888470105", "target_language": "ruby"}
# index.html — portiert nach ruby
# Quelle: html, OpenClaw@main:index.html
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'

# Generates an HTML document similar to the provided index.html
class HtmlGenerator
  def initialize
    @doc = Document.new
  end

  def generate
    html = <<~HTML
      <!DOCTYPE html>
      <html lang="de">
        <head>
          <meta charset="utf-8" />
          <link rel="icon" href="/favicon.ico" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <meta name="theme-color" content="#0b1020" />
          <meta
            name="description"
            content="OpenClaw Startseite für Repository, Dokumentation und Frontend-Branch."
          />
          <link rel="apple-touch-icon" href="/logo192.png" />
          <!--
            manifest.json provides metadata used when your web app is installed on a
            user's mobile device or desktop. See https://developers.google.com/web/fundamentals/web-app-manifest/
          -->
          <link rel="manifest" href="/manifest.json" />
          <title>OpenClaw</title>
        </head>
        <body>
          <noscript>You need to enable JavaScript to run this app.</noscript>
          <div id="root"></div>
          <!--
            This HTML file is a template.
            If you open it directly in the browser, you will see an empty page.

            You can add webfonts, meta tags, or analytics to this file.
            The build step will place the bundled scripts into the <body> tag.

            To begin the development, run `npm start` or `yarn start`.
            To create a production bundle, use `npm run build` or `yarn build`.
          -->
        </body>
        <script type="module" src="/src/index.jsx"></script>
      </html>
    HTML
    
    html
  end
  
  class Document
  end
end

# Main execution
if __FILE__ == $0
  if ARGV.length != 1
    puts "Usage: #{$0} <output_file>"
    exit 1
  end

  output_file = ARGV[0]
  
  generator = HtmlGenerator.new
  html_content = generator.generate
  
  File.write(output_file, html_content)
  
  puts "HTML file generated successfully: #{output_file}"
end
