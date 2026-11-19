#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "850db909e9d18a9e64a8fdead84296fc14b7a90c11467172ac6ac5d48383db9d", "source_sha256": "e3bab1624f203b949716145357872ec8001a11d44b45121002215386ca7164b3", "target_language": "shell"}
# style.css — portiert nach shell
# Quelle: css, workspace@local:skills/github-clones/openclaw/docs/style.css
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Prüfe, ob ein Parameter übergeben wurde
if [ $# -ne 1 ]; then
    echo "Verwendung: $0 <ausgabedatei>" >&2
    exit 1
fi

# Ausgabedatei vom ersten Parameter holen
ausgabedatei="$1"

# Inhalt in die Ausgabedatei schreiben
cat > "$ausgabedatei" << 'CSS_ENDE'
#content > h1:first-of-type {
  display: none !important;
}

.nav-tabs {
  position: relative;
}

.nav-tabs-item > div {
  opacity: 0;
}

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

html.dark .nav-tabs-underline {
  background-color: rgb(var(--primary-light));
}

.nav-tabs-underline-ready .nav-tabs-underline {
  opacity: 1;
}
CSS_ENDE

echo "CSS-Datei wurde erfolgreich erstellt: $ausgabedatei"
