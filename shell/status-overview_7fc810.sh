#!/bin/bash
# status-overview.html — portiert nach shell
# Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/status-overview.html
# Erzeugt: 2026-11-01 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Prüfe, ob ein Parameter übergeben wurde
if [ $# -ne 1 ]; then
    echo "Verwendung: $0 <ausgabedatei>" >&2
    exit 1
fi

ausgabedatei="$1"

# Erzeuge das HTML-Dokument
cat > "$ausgabedatei" << 'EOF'
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>STATUS-Overview</title>
<link rel="stylesheet" href="status-overview.css">
</head>
<body>
<main id="grid" aria-label="LIVE-Übersicht"></main>
<script src="vendor-mpegts.js"></script>
<script src="status-overview-player.js"></script>
</body>
</html>
EOF

echo "HTML-Dokument wurde erfolgreich in '$ausgabedatei' erstellt."
