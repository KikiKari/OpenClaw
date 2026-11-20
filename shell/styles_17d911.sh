#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "840e7f5ab61a89c6017e982dd686b78574cbb8ec1e48d56d1141dc6a505252aa", "source_sha256": "17d9118c74c9951b6bd9c5e3475b496be57f796a591823384aa44dbdad5a115d", "target_language": "shell"}
# styles.css — portiert nach shell
# Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles.css
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Prüfe, ob ein Parameter übergeben wurde
if [ $# -ne 1 ]; then
    echo "Fehler: Bitte geben Sie einen Dateinamen als Parameter an." >&2
    exit 1
fi

datei="$1"

# Schreibe die CSS-Direktiven in die angegebene Datei
{
    echo '@import "./styles/base.css";'
    echo '@import "./styles/layout.css";'
    echo '@import "./styles/layout.mobile.css";'
    echo '@import "./styles/components.css";'
    echo '@import "./styles/chat.css";'
    echo '@import "./styles/config.css";'
    echo '@import "./styles/usage.css";'
    echo '@import "./styles/dreams.css";'
    echo '@import "@create-markdown/preview/themes/system.css";'
    echo ''
    echo '.cm-preview {'
    echo '  --cm-mono: var(--mono);'
    echo '  --cm-link: var(--accent);'
    echo '  --cm-info: var(--info);'
    echo '  --cm-warning: var(--warn);'
    echo '  --cm-success: var(--ok);'
    echo '  --cm-danger: var(--danger);'
    echo '}'
} > "$datei"

echo "CSS-Datei wurde erfolgreich erstellt: $datei"
