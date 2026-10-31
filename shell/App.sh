#!/bin/bash
# App.css — portiert nach shell
# Quelle: css, OpenClaw@main:src/App.css
# Erzeugt: 2026-10-31 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Prüfe, ob ein Parameter übergeben wurde
if [ $# -ne 1 ]; then
    echo "Verwendung: $0 <ausgabedatei>"
    exit 1
fi

output_file="$1"

# Funktion zum Schreiben von CSS-Regeln
write_css() {
    local selector="$1"
    shift
    local rules=("$@")
    
    echo "$selector {" 
    for rule in "${rules[@]}"; do
        echo "  $rule"
    done
    echo "}"
    echo
}

# Leere die Ausgabedatei oder erstelle sie neu
> "$output_file"

# Schreibe :root Regeln
{
    echo ":root {"
    echo "  color-scheme: dark;"
    echo "  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif;"
    echo "  background: #0b1020;"
    echo "  color: #eef2ff;"
    echo "}"
    echo
} > "$output_file"

# Schreibe * Regeln
write_css "*" "box-sizing: border-box;" >> "$output_file"

# Schreibe body Regeln
{
    echo "body {"
    echo "  margin: 0;"
    echo "  min-width: 320px;"
    echo "  min-height: 100vh;"
    echo "  background:"
    echo "    radial-gradient(circle at 20% 20%, rgba(56, 189, 248, 0.22), transparent 30rem),"
    echo "    radial-gradient(circle at 80% 10%, rgba(168, 85, 247, 0.2), transparent 28rem),"
    echo "    linear-gradient(135deg, #050816 0%, #111827 55%, #172033 100%);"
    echo "}"
    echo
} >> "$output_file"

# Schreibe .page-shell Regeln
write_css ".page-shell" \
    "min-height: 100vh;" \
    "display: grid;" \
    "place-items: center;" \
    "padding: 2rem;" >> "$output_file"

# Schreibe .hero-card Regeln
{
    echo ".hero-card {"
    echo "  width: min(100%, 56rem);"
    echo "  padding: clamp(2rem, 6vw, 4.5rem);"
    echo "  border: 1px solid rgba(148, 163, 184, 0.28);"
    echo "  border-radius: 2rem;"
    echo "  background: rgba(15, 23, 42, 0.72);"
    echo "  box-shadow: 0 2rem 6rem rgba(0, 0, 0, 0.35);"
    echo "  backdrop-filter: blur(18px);"
    echo "}"
    echo
} >> "$output_file"

# Schreibe .eyebrow Regeln
{
    echo ".eyebrow {"
    echo "  margin: 0 0 1rem;"
    echo "  color: #67e8f9;"
    echo "  font-size: 0.8rem;"
    echo "  font-weight: 700;"
    echo "  letter-spacing: 0.18em;"
    echo "  text-transform: uppercase;"
    echo "}"
    echo
} >> "$output_file"

# Schreibe h1 Regeln
{
    echo "h1 {"
    echo "  margin: 0;"
    echo "  max-width: 12ch;"
    echo "  font-size: clamp(2.75rem, 8vw, 6rem);"
    echo "  line-height: 0.95;"
    echo "  letter-spacing: -0.06em;"
    echo "}"
    echo
} >> "$output_file"

# Schreibe .lead Regeln
{
    echo ".lead {"
    echo "  margin: 1.5rem 0 0;"
    echo "  max-width: 42rem;"
    echo "  color: #cbd5e1;"
    echo "  font-size: clamp(1.05rem, 2vw, 1.35rem);"
    echo "  line-height: 1.65;"
    echo "}"
    echo
} >> "$output_file"

# Schreibe .link-grid Regeln
{
    echo ".link-grid {"
    echo "  display: grid;"
    echo "  gap: 0.85rem;"
    echo "  margin-top: 2rem;"
    echo "}"
    echo
} >> "$output_file"

# Schreibe .link-grid a Regeln
{
    echo ".link-grid a {"
    echo "  display: flex;"
    echo "  align-items: center;"
    echo "  justify-content: space-between;"
    echo "  gap: 1rem;"
    echo "  padding: 1rem 1.15rem;"
    echo "  border: 1px solid rgba(148, 163, 184, 0.25);"
    echo "  border-radius: 1rem;"
    echo "  color: #f8fafc;"
    echo "  text-decoration: none;"
    echo "  background: rgba(255, 255, 255, 0.06);"
    echo "}"
    echo
} >> "$output_file"

# Schreibe .link-grid a:hover, .link-grid a:focus-visible Regeln
{
    echo ".link-grid a:hover,"
    echo ".link-grid a:focus-visible {"
    echo "  border-color: rgba(103, 232, 249, 0.75);"
    echo "  outline: none;"
    echo "  background: rgba(103, 232, 249, 0.12);"
    echo "}"
} >> "$output_file"

echo "CSS erfolgreich in '$output_file' geschrieben."
