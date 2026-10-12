#!/bin/bash
# index.html — portiert nach shell
# Quelle: html, Projects@TikTok-Live-Companion:site/index.html
# Erzeugt: 2026-10-12 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Parameter prüfen
if [[ $# -ne 1 ]]; then
  echo "Aufruf: $0 <ausgabedatei>" >&2
  exit 1
fi

# Ausgabedatei vom ersten Parameter übernehmen
ausgabedatei="$1"

# HTML-Dokument generieren und in die Ausgabedatei schreiben
cat > "$ausgabedatei" << 'HTML_END'
<!doctype html>
<html lang="de">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content="Dokumentation für TikTok LIVE Companion 0.8.2 – Chat-TTS, Zuschauerstatistik, Songerkennung und Stream-Informationen direkt im Browser." />
    <meta name="theme-color" content="#ffffff" />
    <link rel="icon" type="image/png" href="/branding/staenderglobus-ios.png" />
    <link rel="apple-touch-icon" href="/branding/staenderglobus-ios.png" />
    <title>TikTok LIVE Companion – Dokumentation</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
HTML_END

echo "HTML-Datei wurde erfolgreich erstellt: $ausgabedatei"
