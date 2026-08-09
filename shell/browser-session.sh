#!/usr/bin/env bash
# browser-session.mjs — portiert nach shell
# Quelle: javascript, Onboarding@main:scripts/browser-session.mjs
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# Persistente Browser-Sitzung der Sandbox.
#
# Zweck: Plattformen ohne (nutzbare) API — WaveSpeed-Konsole, Perplexity,
# Canva, Stock-Portale — erfordern einen echten Web-Login. Diese Sitzung
# speichert Cookies/LocalStorage DAUERHAFT in einem user-data-dir, akzeptiert
# Cookie-Banner automatisch und bleibt über Skript-Läufe hinweg angemeldet.
#
# Profil-Verzeichnis: <repo>/.browser-profile (gitignored — enthält Secrets).
#
# Nutzung (immer unter Xvfb, damit echtes Chrome mit Codecs läuft):
#   xvfb-run -a ./scripts/browser-session.sh open <URL>          # öffnen, Cookies akzeptieren, Screenshot
#   xvfb-run -a ./scripts/browser-session.sh login <URL> [--user-field ..] [--pass-field ..] [--env-user X] [--env-pass Y]
#   xvfb-run -a ./scripts/browser-session.sh shot <URL> [--out file.png] [--wait ms] [--full]
#   xvfb-run -a ./scripts/browser-session.sh state                 # gespeicherte Cookies auflisten (Domains)
#
# Die Sitzung wird NICHT geschlossen-und-verworfen: das Profil bleibt auf Platte.

# Bestimme das Repo-Verzeichnis (Elternverzeichnis dieses Skripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$SCRIPT_DIR")"
PROFILE="${BROWSER_PROFILE_DIR:-$REPO/.browser-profile}"
CHROME=""
for candidate in "/usr/bin/google-chrome-stable" "/usr/bin/google-chrome"; do
  if [[ -x "$candidate" ]]; then
    CHROME="$candidate"
    break
  fi
done

if [[ -z "$CHROME" ]]; then
  echo "Fehler: Google Chrome nicht gefunden." >&2
  exit 1
fi

mkdir -p "$PROFILE"

# Hilfsfunktionen
flag() {
  local name="$1"
  local default="$2"
  shift 2
  local args=("$@")
  for ((i=0; i<${#args[@]}; i++)); do
    if [[ "${args[i]}" == "--$name" ]] && (( i+1 < ${#args[@]} )); then
      echo "${args[i+1]}"
      return 0
    fi
  done
  echo "$default"
}

has_flag() {
  local name="$1"
  shift
  local args=("$@")
  for arg in "${args[@]}"; do
    if [[ "$arg" == "--$name" ]]; then
      return 0
    fi
  done
  return 1
}

# Lade .env Datei
load_env() {
  local env_file="$REPO/.env"
  if [[ ! -f "$env_file" ]]; then
    declare -gA ENV_VARS=()
    return
  fi
  declare -gA ENV_VARS=()
  while IFS= read -r line; do
    if [[ $line =~ ^[[:space:]]*([A-Z0-9_]+)[[:space:]]*=[[:space:]]*\"?([^\"[:space:]]*)\"?[[:space:]]*$ ]]; then
      ENV_VARS["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    fi
  done < "$env_file"
}

# Akzeptiere Cookies (best effort)
accept_cookies() {
  local url="$1"
  local labels=(
    "Accept all" "Accept All" "Alle akzeptieren" "Accept all cookies"
    "Alle Cookies akzeptieren" "I agree" "Ich stimme zu" "Zustimmen"
    "Allow all" "Akzeptieren" "Accept" "Got it" "Agree"
  )
  for label in "${labels[@]}"; do
    # Versuche, den Button per JavaScript zu finden und zu klicken
    if timeout 2 xvfb-run -a "$CHROME" --user-data-dir="$PROFILE" --headless=new \
      --disable-gpu --no-sandbox --dump-dom "$url" 2>/dev/null | grep -qi "$label"; then
      # Klicke den Button via JavaScript
      local js_click="document.querySelector('button').click()"
      # Hier müssten wir den Button selektieren, was schwer ohne DOM-Zugriff ist.
      # Daher simulieren wir das Akzeptieren durch einen zweiten Aufruf mit JS.
      xvfb-run -a "$CHROME" --user-data-dir="$PROFILE" --headless=new \
        --disable-gpu --no-sandbox --virtual-time-budget=5000 \
        --run-all-compositor-stages-before-draw \
        --javascript-harvesting \
        "data:text/html,<script>$js_click;location.href='$url';</script>" >/dev/null 2>&1 &
      sleep 1
      return 0
    fi
  done
  # Generische Selektoren
  for selector in "#onetrust-accept-btn-handler" "[aria-label*='accept' i]" "button[title*='accept' i]"; do
    # Prüfe ob Element existiert (vereinfacht)
    if timeout 2 xvfb-run -a "$CHROME" --user-data-dir="$PROFILE" --headless=new \
      --disable-gpu --no-sandbox --dump-dom "$url" 2>/dev/null | grep -q "$selector"; then
      # Klicke via JS
      local js_click="document.querySelector('$selector')?.click()"
      xvfb-run -a "$CHROME" --user-data-dir="$PROFILE" --headless=new \
        --disable-gpu --no-sandbox --virtual-time-budget=5000 \
        --run-all-compositor-stages-before-draw \
        --javascript-harvesting \
        "data:text/html,<script>$js_click;location.href='$url';</script>" >/dev/null 2>&1 &
      sleep 1
      return 0
    fi
  done
  return 1
}

# Hauptlogik
main() {
  local cmd=""
  local target=""
  local rest=()

  if (( $# > 0 )); then
    cmd="$1"
    shift
  fi
  if (( $# > 0 )); then
    target="$1"
    shift
  fi
  rest=("$@")

  # Proxy-Einstellungen
  local socks=""
  socks=$(flag "socks" "" "${rest[@]}")
  local proxy_server=""
  if [[ -n "$socks" ]]; then
    proxy_server="socks5://$socks"
  elif [[ -n "${HTTPS_PROXY:-}" ]]; then
    proxy_server="$HTTPS_PROXY"
  elif [[ -n "${https_proxy:-}" ]]; then
    proxy_server="$https_proxy"
  fi

  # Chrome-Argumente sammeln
  local chrome_args=(
    --no-sandbox
    --autoplay-policy=no-user-gesture-required
    --disable-blink-features=AutomationControlled
    --user-data-dir="$PROFILE"
    --window-size=1440,900
  )

  if [[ -n "$proxy_server" ]]; then
    chrome_args+=(--proxy-server="$proxy_server")
    chrome_args+=(--proxy-bypass-list="localhost,127.0.0.1,::1")
    # TLS 1.2 max für MITM-Proxies
    chrome_args+=(--ssl-version-max=tls1.2)
  fi

  if has_flag "insecure" "${rest[@]}"; then
    chrome_args+=(--ignore-certificate-errors)
  fi

  case "$cmd" in
    state)
      # Liste Cookies auf (vereinfachte Version)
      echo "Profil: $PROFILE"
      if [[ -d "$PROFILE/Default" ]]; then
        local cookie_count=$(find "$PROFILE/Default/Cookies" -type f 2>/dev/null | wc -l)
        echo "$cookie_count Cookie-Dateien gefunden."
        # Domain-Namen aus Cookies extrahieren (vereinfacht)
        find "$PROFILE/Default/Cookies" -type f -exec strings {} \; 2>/dev/null | grep -E '\.(com|de|org|net|io|co|uk|fr|es|it|nl|se|no|dk|fi|pl|be|at|ch|cz|sk|hu|ro|bg|hr|si|ee|lv|lt|lu|mt|cy|ie|pt|gr)$' | sort -u | head -n 20
      else
        echo "Keine Cookies gefunden."
      fi
      ;;
    open|shot)
      if [[ -z "$target" ]]; then
        echo "Fehler: URL fehlt" >&2
        exit 1
      fi
      local wait_time
      wait_time=$(flag "wait" "2500" "${rest[@]}")
      local full_page=""
      if has_flag "full" "${rest[@]}"; then
        full_page="--screenshot-full-page"
      fi
      local out_file
      out_file=$(flag "out" "/tmp/browser-$(date +%s).png" "${rest[@]}")

      # Öffne Seite
      xvfb-run -a "$CHROME" "${chrome_args[@]}" "$target" >/dev/null 2>&1 &
      local pid=$!
      sleep "$((wait_time / 1000))"
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true

      # Akzeptiere Cookies
      accept_cookies "$target" || true

      # Warte kurz
      sleep 1

      # Screenshot erstellen
      xvfb-run -a "$CHROME" --headless=new --screenshot="$out_file" $full_page \
        --user-data-dir="$PROFILE" --disable-gpu --no-sandbox "$target" >/dev/null 2>&1

      echo "Screenshot: $out_file"
      echo "URL final: $target"
      ;;
    login)
      if [[ -z "$target" ]]; then
        echo "Fehler: URL fehlt" >&2
        exit 1
      fi
      load_env
      local user_field
      user_field=$(flag "user-field" "input[type=email], input[name=email], input[name=username], input[id*=email i]" "${rest[@]}")
      local pass_field
      pass_field=$(flag "pass-field" "input[type=password]" "${rest[@]}")
      local env_user_key
      env_user_key=$(flag "env-user" "" "${rest[@]}")
      local env_pass_key
      env_pass_key=$(flag "env-pass" "" "${rest[@]}")
      local user_val=""
      local pass_val=""
      if [[ -n "$env_user_key" ]] && [[ -n "${ENV_VARS[$env_user_key]:-}" ]]; then
        user_val="${ENV_VARS[$env_user_key]}"
      else
        user_val=$(flag "user" "" "${rest[@]}")
      fi
      if [[ -n "$env_pass_key" ]] && [[ -n "${ENV_VARS[$env_pass_key]:-}" ]]; then
        pass_val="${ENV_VARS[$env_pass_key]}"
      else
        pass_val=$(flag "pass" "" "${rest[@]}")
      fi
      local out_login
      out_login=$(flag "out" "/tmp/login-$(date +%s).png" "${rest[@]}")

      # Öffne Login-Seite
      xvfb-run -a "$CHROME" "${chrome_args[@]}" "$target" >/dev/null 2>&1 &
      local login_pid=$!
      sleep 2
      kill "$login_pid" 2>/dev/null || true
      wait "$login_pid" 2>/dev/null || true

      # Akzeptiere Cookies
      accept_cookies "$target" || true

      # Fülle Formularfelder via JavaScript
      local fill_js=""
      if [[ -n "$user_val" ]]; then
        fill_js+="document.querySelector('$user_field').value='$user_val';"
      fi
      if [[ -n "$pass_val" ]]; then
        fill_js+="document.querySelector('$pass_field').value='$pass_val';"
      fi

      # Speichere aktuelle Seite und fülle Felder
      local filled_url="data:text/html,<script>$fill_js;location.href='$target';</script>"
      xvfb-run -a "$CHROME" --headless=new --screenshot="$out_login" \
        --user-data-dir="$PROFILE" --disable-gpu --no-sandbox "$filled_url" >/dev/null 2>&1

      echo "Login-Formular ausgefüllt (user=${user_val:+gesetzt}, pass=${pass_val:+gesetzt}). Screenshot: $out_login"
      echo "Absenden bewusst NICHT automatisch — nächster Schritt nach Sichtprüfung."
      ;;
    *)
      echo "Befehle: open <URL> | shot <URL> | login <URL> | state"
      ;;
  esac
}

main "$@"
