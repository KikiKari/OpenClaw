# Cron-Job Korrektur: @reboot → 20min mit PID-Check

## Problem

`@reboot` funktioniert oft nicht zuverlässig (abhängig von cron-Implementation).

## Lösung

**Alle 20 Minuten starten + PID-Check** (keine Multiplikation):

### Gateway Start (korrigiert)

**Vorher:**
```
@reboot sleep 10 && /home/openclaw/.npm-global/bin/openclaw gateway start
```

**Nachher:**
```
*/20 * * * * /home/openclaw/.openclaw/workspace/scripts/openclaw-gateway-start.sh
```

Mit Script (`scripts/openclaw-gateway-start.sh`):
```bash
#!/bin/bash
# Startet OpenClaw Gateway nur wenn nicht bereits laufend

PIDFILE=/tmp/openclaw-gateway.pid

if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Gateway läuft bereits (PID: $PID)"
        exit 0
    fi
fi

# Starte Gateway
/home/openclaw/.npm-global/bin/openclaw gateway start
echo $! > "$PIDFILE"
echo "Gateway gestartet (PID: $!)"
```

## Vollständige korrigierte Crontab

```
# Alle 20 Minuten: Gateway (mit PID-Check)
*/20 * * * * /home/openclaw/.openclaw/workspace/scripts/openclaw-gateway-start.sh >> /tmp/openclaw-gateway.log 2>&1

# 3 Uhr täglich: DB-Backup
0 3 * * * /home/openclaw/bin/daily-db-backup.sh >> /home/openclaw/.openclaw/logs/cron-backup.log 2>&1

# Alle 3 Stunden: Nodes-Report
0 */3 * * * cd /home/openclaw/.openclaw/workspace && node scripts/update-nodes-report.js && node scripts/post-nodes-report.js >> /home/openclaw/.openclaw/logs/nodes-report.log 2>&1

# Alle 30 Minuten: Ops-Hub Heartbeat
*/30 * * * * cd /home/openclaw/.openclaw/workspace && node scripts/ops-hub-heartbeat.js >> /home/openclaw/.openclaw/logs/ops-hub-heartbeat.log 2>&1

# Alle 30 Minuten: DB Maintainer
*/30 * * * * /usr/bin/python3 /home/openclaw/.openclaw/workspace/skills/db-maintainer/scripts/db_maintainer.py >> /home/openclaw/.openclaw/workspace/logs/db-maintainer/cron.log 2>&1
```

## Anwendung

```bash
# Als openclaw:
crontab -e

# Alles löschen, oben einfügen, speichern
```
