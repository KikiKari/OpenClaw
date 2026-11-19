#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "ba8b155d61b16aabf16abe320605f9f1241333ca1a8d69a0eb5f2bea86a96306", "source_sha256": "635ed6e934aa27ffc7ad156af00126e0797ae1d1c065daddb996e2bddc8cbeb3", "target_language": "ruby"}
# index.html — portiert nach ruby
# Quelle: html, workspace@local:skills/github-clones/openclaw/extensions/qa-lab/web/index.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require 'optparse'

# Parse command line options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"
  opts.on("-o", "--output FILE", "Output file") do |file|
    options[:output] = file
  end
end.parse!

# Generate HTML document structure
html_content = <<~HTML
  <!doctype html>
  <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <meta name="color-scheme" content="light dark" />
      <title>QA Lab</title>
    </head>
    <body>
      <div id="app"></div>
      <script type="module" src="/src/main.ts"></script>
    </body>
  </html>
HTML

# Write to file or stdout
if options[:output]
  File.write(options[:output], html_content)
  puts "HTML document written to #{options[:output]}"
else
  puts html_content
end
