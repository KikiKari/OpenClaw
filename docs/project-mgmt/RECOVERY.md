# RECOVERY.md - Wiederherstellung nach Datenverlust

## Problem
OpenClaw Gateway lief unter root UND openclaw.
Systemd-Service-Wechsel verursachte Datenverlust bei:
- Cron-Jobs
- Alert-Konfiguration
- Session-Daten

## Lösung: Alles auf Cron (alle 15min)


### 3. Alert-Skripte
- Ort: `/home/openclaw/bin/`
- Eigentümer: openclaw:openclaw
- Rechte: 755

### 4. TikTok LIVE Runtime
Die alte Port-5001-App ist retired. Wiederherstellung bedeutet: portable Skill-Pfade und Laufzeiten prüfen, nicht einen HTTP-Dienst starten.

```bash
python3 "$HOME/.openclaw/workspace/tiktok-monitor/tiktok_dispatch.py" \
  check example_creator --execution local --json
node --check "$HOME/.openclaw/workspace/skills/tiktok-live/scripts/tiktok-check-profile.js"
node --check "$HOME/.openclaw/workspace/skills/tiktok-live-mon/scripts/tiktok-check-profile.js"
```

Auf gepaarten Nodes müssen Workspace, Python, Node.js und Playwright/Chromium am gleichen portablen Pfad vorhanden sein. Fehlende Node-Abhängigkeiten führen zum Gateway-Fallback.

### 5. Health-Checks
Alle Nodes erreichbar:
- :16000 - OK
- :15000 - OK (worker-2)
- :18792 - OK

## Verhinderte Datenverluste
- E-Mail-Config: `~/.config/himalaya/config.toml`
- Slack-Token: `~/.config/openclaw/env`
- Skripte: `/home/openclaw/bin/`
