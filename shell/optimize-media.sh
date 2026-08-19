#!/bin/bash
# optimize-media.mjs — portiert nach shell
# Quelle: javascript, Onboarding@main:scripts/optimize-media.mjs
# Erzeugt: 2026-08-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Finde das Verzeichnis des Skripts und gehe zum Zielverzeichnis
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEDIA_DIR="${SCRIPT_DIR}/../public/media"

# Überprüfe, ob das Verzeichnis existiert
if [[ ! -d "$MEDIA_DIR" ]]; then
  echo "Fehler: Verzeichnis $MEDIA_DIR existiert nicht."
  exit 1
fi

# Durchlaufe alle PNG-Dateien im Verzeichnis
for png_file in "$MEDIA_DIR"/*.png; do
  # Überspringe, wenn keine PNG-Dateien vorhanden sind
  [[ -e "$png_file" ]] || continue
  
  # Extrahiere den Basisnamen ohne Erweiterung
  basename="${png_file%.png}"
  
  # Konvertiere zu WebP
  convert "$png_file" -quality 84 "${basename}.webp"
  
  # Konvertiere zu AVIF
  convert "$png_file" -quality 58 "${basename}.avif"
done

echo "WebP- und AVIF-Derivate erzeugt."
