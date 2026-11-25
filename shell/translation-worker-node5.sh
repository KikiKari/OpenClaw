#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "8c7da94e624dec78775c13be3e3a1f6c228c0feb26a5f5608fd976f5886c5f87", "source_sha256": "e31da3d72f8d806a159d6709f37f55500c7f16939f04c094f2ab46a959e70c57", "target_language": "shell"}
# translation-worker-node5.ps1 — portiert nach shell
# Quelle: powershell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node5.ps1
# Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

ACTION="${1:?Usage: $0 {prepare|run}}"
WORKER="$HOME/.openclaw/workers/translation_worker.py"
EXPECTED="9f8e810dd49f30fbc05064a98faf280d1f2480fdb8f125115ad006d486cd555b"

if [[ ! -f "$WORKER" ]]; then
    echo "Worker missing: $WORKER" >&2
    exit 1
fi

if [[ -L "$WORKER" ]]; then
    echo "Worker link rejected" >&2
    exit 1
fi

CHECKSUM=$(sha256sum "$WORKER" | awk '{print $1}')
if [[ "$CHECKSUM" != "$EXPECTED" ]]; then
    echo "Worker checksum mismatch" >&2
    exit 1
fi

if [[ "$ACTION" == "prepare" ]]; then
    echo "Worker verified: $WORKER"
    exit 0
fi

python3 "$WORKER"
