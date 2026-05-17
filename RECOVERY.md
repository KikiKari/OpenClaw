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

### 4. TikTok Service
```bash
# Läuft auf Port 5001
ps aux | grep app.py
# Ergebnis: /usr/bin/python3 /opt/tiktok-api/app.py
```

### 5. Health-Checks
Alle Nodes erreichbar:
- :16000 - OK
- :15000 - OK (worker-2)
- :18792 - OK

## Verhinderte Datenverluste
- E-Mail-Config: `~/.config/himalaya/config.toml`
- Slack-Token: `~/.config/openclaw/env`
- Skripte: `/home/openclaw/bin/`
