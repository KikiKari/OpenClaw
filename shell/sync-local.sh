#!/bin/bash
# sync-local.ps1 — portiert nach shell
# Quelle: powershell, Onboarding@main:scripts/sync-local.ps1
# Erzeugt: 2026-08-21 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Standardparameter festlegen
BRANCH="${1:-claude/onboarding-persistent-sandbox-vjfmcx}"
INTERVAL_SECONDS="${2:-20}"
COMPOSE_FILE="${3:-docker-compose.dev.yml}"
ONCE=false

# Prüfen, ob --once als Parameter übergeben wurde
for arg in "$@"; do
  if [[ "$arg" == "--once" ]]; then
    ONCE=true
    break
  fi
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

log() {
  echo "[$(date +%H:%M:%S)] $1"
}

invoke_compose() {
  if ! docker compose -f "$COMPOSE_FILE" "$@"; then
    log "WARNUNG: docker compose $* fehlgeschlagen"
  fi
}

# Sicherstellen, dass der Ziel-Branch ausgecheckt ist
CURRENT=$(git rev-parse --abbrev-ref HEAD)
if [[ "$CURRENT" != "$BRANCH" ]]; then
  log "Wechsle von '$CURRENT' auf '$BRANCH' …"
  git fetch origin "$BRANCH"
  if ! git switch "$BRANCH" 2>/dev/null; then
    if ! git switch -c "$BRANCH" --track "origin/$BRANCH"; then
      echo "Branch '$BRANCH' konnte nicht ausgecheckt werden." >&2
      exit 1
    fi
  fi
fi

log "Sync aktiv: origin/$BRANCH -> $REPO_ROOT (Intervall ${INTERVAL_SECONDS}s, Compose: $COMPOSE_FILE)"

while true; do
  if ! git fetch origin "$BRANCH" --quiet; then
    log "Fetch fehlgeschlagen (Netzwerk?) — nächster Versuch in ${INTERVAL_SECONDS}s"
  else
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse "origin/$BRANCH")

    if [[ "$LOCAL" != "$REMOTE" ]]; then
      if ! git merge-base --is-ancestor "$LOCAL" "$REMOTE"; then
        log "ACHTUNG: Lokaler Stand ist von origin/$BRANCH abgewichen (lokale Commits?). Kein automatischer Merge — bitte manuell auflösen."
      else
        CHANGED=$(git diff --name-only "$LOCAL".."$REMOTE")
        git merge --ff-only "$REMOTE" --quiet
        IFS=$'\n' read -rd '' -a CHANGED_ARRAY <<< "$CHANGED" || true
        log "Aktualisiert ${LOCAL:0:7} -> ${REMOTE:0:7} (${#CHANGED_ARRAY[@]} Datei(en))"

        FRONTEND_DEPS=false
        BACKEND_IMAGE=false
        COMPOSE_CHANGED=false

        for file in "${CHANGED_ARRAY[@]}"; do
          case "$file" in
            package.json|package-lock.json)
              FRONTEND_DEPS=true
              ;;
            backend/Dockerfile|backend/requirements*.txt)
              BACKEND_IMAGE=true
              ;;
            "$COMPOSE_FILE")
              COMPOSE_CHANGED=true
              ;;
          esac
        done

        if [[ "$COMPOSE_CHANGED" == true ]]; then
          log "Compose-Datei geändert — erzeuge Dev-Stack neu …"
          invoke_compose up -d
        fi

        if [[ "$BACKEND_IMAGE" == true ]]; then
          log "Backend-Dependencies/Dockerfile geändert — baue nur das Backend neu …"
          invoke_compose up -d --build backend
        fi

        if [[ "$FRONTEND_DEPS" == true ]]; then
          log "Frontend-Dependencies geändert — starte Frontend neu (npm install läuft im Container) …"
          invoke_compose restart frontend
        fi

        if [[ "$COMPOSE_CHANGED" != true && "$BACKEND_IMAGE" != true && "$FRONTEND_DEPS" != true ]]; then
          log "Nur Quellcode/Assets — Hot-Reload übernimmt, kein Build nötig."
        fi
      fi
    fi
  fi

  if [[ "$ONCE" == true ]]; then
    break
  fi
  sleep "$INTERVAL_SECONDS"
done
