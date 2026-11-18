#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "af481b136c68c6edc6d8bb02d3107ca6456f726fa26d239d98e0fac13c9612f7", "source_sha256": "daf22c296c801d3d533083361cc59fbdc22e5bfe528aa4bad1973b54cc5448a4", "target_language": "ruby"}
# index.css — portiert nach ruby
# Quelle: css, OpenClaw@main:src/index.css
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

# Methode zur Erstellung der CSS-Struktur
def create_css_structure
  css_rules = {
    "body" => {
      "margin" => "0",
      "font-family" => "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue', sans-serif",
      "-webkit-font-smoothing" => "antialiased",
      "-moz-osx-font-smoothing" => "grayscale"
    },
    "code" => {
      "font-family" => "source-code-pro, Menlo, Monaco, Consolas, 'Courier New', monospace"
    }
  }
  
  return css_rules
end

# Methode zur Formatierung der CSS-Ausgabe
def format_css(css_rules)
  output = ""
  
  css_rules.each do |selector, properties|
    output += "#{selector} {\n"
    
    properties.each do |property, value|
      output += "  #{property}: #{value};\n"
    end
    
    output += "}\n\n"
  end
  
  # Entferne letzte Leerzeilen
  output.chomp.chomp
end

# Hauptprogramm
if ARGV.length != 1
  puts "Verwendung: #{$0} <ausgabedatei>"
  exit 1
end

output_file = ARGV[0]

# Erstelle CSS-Struktur
css_structure = create_css_structure()

# Formatiere CSS
css_content = format_css(css_structure)

# Schreibe in Datei
File.open(output_file, 'w') do |file|
  file.write(css_content)
end

puts "CSS-Datei wurde erfolgreich erstellt: #{output_file}"
