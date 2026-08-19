#!/bin/bash
# App.css — portiert nach shell
# Quelle: css, OpenClaw@main:src/App.css
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Prüfe, ob ein Dateiname übergeben wurde
if [[ $# -ne 1 ]]; then
    echo "Verwendung: $0 <ausgabedatei>" >&2
    exit 1
fi

output_file="$1"

# Funktion zum Schreiben von CSS-Regeln
write_css() {
    local selector="$1"
    shift
    local properties=("$@")
    
    echo "$selector {" >> "$output_file"
    for prop in "${properties[@]}"; do
        echo "  $prop" >> "$output_file"
    done
    echo "}" >> "$output_file"
    echo "" >> "$output_file"
}

# Leere die Ausgabedatei und schreibe den CSS-Code
> "$output_file"

# Root-Styles
write_css ":root" \
    "color-scheme: dark;" \
    "font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif;" \
    "background: #0b1020;" \
    "color: #eef2ff;"

# Universelle Styles
write_css "*" \
    "box-sizing: border-box;"

# Body-Styles
write_css "body" \
    "margin: 0;" \
    "min-width: 320px;" \
    "min-height: 100vh;" \
    "background:" \
    "  radial-gradient(circle at 20% 20%, rgba(56, 189, 248, 0.22), transparent 30rem)," \
    "  radial-gradient(circle at 80% 10%, rgba(168, 85, 247, 0.2), transparent 28rem)," \
    "  linear-gradient(135deg, #050816 0%, #111827 55%, #172033 100%);"

# Page Shell
write_css ".page-shell" \
    "min-height: 100vh;" \
    "display: grid;" \
    "place-items: center;" \
    "padding: 2rem;"

# Hero Card
write_css ".hero-card" \
    "width: min(100%, 56rem);" \
    "padding: clamp(2rem, 6vw, 4.5rem);" \
    "border: 1px solid rgba(148, 163, 184, 0.28);" \
    "border-radius: 2rem;" \
    "background: rgba(15, 23, 42, 0.72);" \
    "box-shadow: 0 2rem 6rem rgba(0, 0, 0, 0.35);" \
    "backdrop-filter: blur(18px);"

# Eyebrow
write_css ".eyebrow" \
    "margin: 0 0 1rem;" \
    "color: #67e8f9;" \
    "font-size: 0.8rem;" \
    "font-weight: 700;" \
    "letter-spacing: 0.18em;" \
    "text-transform: uppercase;"

# Überschrift
write_css "h1" \
    "margin: 0;" \
    "max-width: 12ch;" \
    "font-size: clamp(2.75rem, 8vw, 6rem);" \
    "line-height: 0.95;" \
    "letter-spacing: -0.06em;"

# Lead Text
write_css ".lead" \
    "margin: 1.5rem 0 0;" \
    "max-width: 42rem;" \
    "color: #cbd5e1;" \
    "font-size: clamp(1.05rem, 2vw, 1.35rem);" \
    "line-height: 1.65;"

# Link Grid Container
write_css ".link-grid" \
    "display: grid;" \
    "gap: 0.85rem;" \
    "margin-top: 2rem;"

# Link Grid Elemente
write_css ".link-grid a" \
    "display: flex;" \
    "align-items: center;" \
    "justify-content: space-between;" \
    "gap: 1rem;" \
    "padding: 1rem 1.15rem;" \
    "border: 1px solid rgba(148, 163, 184, 0.25);" \
    "border-radius: 1rem;" \
    "color: #f8fafc;" \
    "text-decoration: none;" \
    "background: rgba(255, 255, 255, 0.06);"

# Hover/Focus States für Links
echo ".link-grid a:hover," >> "$output_file"
echo ".link-grid a:focus-visible {" >> "$output_file"
echo "  border-color: rgba(103, 232, 249, 0.75);" >> "$output_file"
echo "  outline: none;" >> "$output_file"
echo "  background: rgba(103, 232, 249, 0.12);" >> "$output_file"
echo "}" >> "$output_file"
