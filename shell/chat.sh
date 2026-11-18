#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "125f3342fb95b86638c2c832e7d7001be5d71a5672e6949c76128697535dd0b5", "source_sha256": "f1fb75db28e47070c42c0b401c9bdae5ac468bcd98550232038e409983691fad", "target_language": "shell"}
# chat.css — portiert nach shell
# Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat.css
# Erzeugt: 2026-11-18 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Prüfe, ob ein Parameter übergeben wurde
if [ $# -ne 1 ]; then
    echo "Verwendung: $0 <ausgabedatei>" >&2
    exit 1
fi

ausgabedatei="$1"

# Erstelle die CSS-Datei mit allen @import-Anweisungen
cat > "$ausgabedatei" << 'EOF'
@import "./chat/layout.css";
@import "./chat/text.css";
@import "./chat/grouped.css";
@import "./chat/tool-cards.css";
@import "./chat/sidebar.css";
EOF

echo "CSS-Datei wurde erfolgreich erstellt: $ausgabedatei"
