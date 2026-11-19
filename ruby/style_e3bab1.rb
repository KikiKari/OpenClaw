#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "f9dbf7680744b7be15da119b504b39c350850ba0db79319f7484a0857c0477ea", "source_sha256": "e3bab1624f203b949716145357872ec8001a11d44b45121002215386ca7164b3", "target_language": "ruby"}
# style.css — portiert nach ruby
# Quelle: css, workspace@local:skills/github-clones/openclaw/docs/style.css
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

# Ruby-Skript zur Erzeugung der CSS-Datei style.css
# Portiert von CSS zu Ruby unter Verwendung von String-Erstellung und Dateiausgabe

def generate_css_content
  css_rules = []

  # Regel 1: Verstecke das erste h1-Element innerhalb von #content
  css_rules << "#content > h1:first-of-type {\n  display: none !important;\n}"

  # Regel 2: Positionierung der Nav-Tabs
  css_rules << ".nav-tabs {\n  position: relative;\n}"

  # Regel 3: Unsichtbare div-Elemente innerhalb von Nav-Tabs-Items
  css_rules << ".nav-tabs-item > div {\n  opacity: 0;\n}"

  # Regel 4: Gestaltung der Nav-Tabs-Unterstrich-Animation
  underline_rule = <<-CSS
.nav-tabs-underline {
  position: absolute;
  left: 0;
  bottom: 0;
  height: 1.5px;
  width: var(--nav-tab-underline-width, 0);
  transform: translateX(var(--nav-tab-underline-x, 0));
  background-color: rgb(var(--primary));
  border-radius: 999px;
  pointer-events: none;
  opacity: 0;
  transition:
    transform 260ms ease-in-out,
    width 260ms ease-in-out,
    opacity 160ms ease-in-out;
  will-change: transform, width;
}
CSS
  css_rules << underline_rule.strip

  # Regel 5: Angepasste Farbe im Dark-Mode
  css_rules << "html.dark .nav-tabs-underline {\n  background-color: rgb(var(--primary-light));\n}"

  # Regel 6: Sichtbarkeit bei bereitgestelltem Underline
  css_rules << ".nav-tabs-underline-ready .nav-tabs-underline {\n  opacity: 1;\n}"

  # Kombiniere alle Regeln mit doppelten Zeilenumbrüchen
  css_rules.join("\n\n")
end

def write_css_to_file(filename)
  File.write(filename, generate_css_content)
end

# Hauptprogramm - prüft ob Dateiname als Parameter übergeben wurde
if ARGV.length != 1
  puts "Verwendung: #{$0} <dateiname>"
  exit 1
end

output_file = ARGV[0]
write_css_to_file(output_file)
puts "CSS-Datei erfolgreich erstellt: #{output_file}"
