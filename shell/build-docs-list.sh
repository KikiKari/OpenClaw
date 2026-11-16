#!/usr/bin/env bash
# abstraction-provenance: {"artifact_sha256": "e1e98b5fb122268dd8ec4853e1b9cd00f97d8b9078190936d0d3c5d09e14bd9f", "source_sha256": "a1805aea1655d2760f0aa6fe9d137718ec6b67c1eb8b7d25c2b93d461eea3215", "target_language": "shell"}
# build-docs-list.mjs — portiert nach shell
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-docs-list.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Bestimme das Verzeichnis des Skripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$ROOT_DIR/bin"
BIN_PATH="$BIN_DIR/docs-list"

# Erstelle das bin-Verzeichnis rekursiv
mkdir -p "$BIN_DIR"

# Wrapper-Inhalt als mehrzeiliger String
read -r -d '' WRAPPER_CONTENT <<'EOF'
#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const script = path.join(here, "..", "scripts", "docs-list.js");

const result = spawnSync(process.execPath, [script], { stdio: "inherit" });
process.exit(result.status ?? 1);
EOF

# Schreibe den Wrapper in die Datei und setze die Berechtigungen
echo "$WRAPPER_CONTENT" > "$BIN_PATH"
chmod 755 "$BIN_PATH"
