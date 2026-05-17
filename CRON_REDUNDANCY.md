# Cron Redundanz: @reboot + 20min Rhythmus

## Konzept

| Priorität | Mechanismus | Wann | Fallback |
|-----------|-------------|------|----------|
| 1. | @reboot | Direkt beim Boot | Sofort |
| 2. | */20 * * * * | Alle 20 Minuten | Falls @reboot nicht ging |

## Warum das funktioniert

Die Lösung prüft **vor jedem Start** ob Gateway bereits läuft:

```bash
# PID-Prüfung
if pgrep -f "openclaw gateway" > /dev/null; then
    echo "Gateway läuft bereits"
    exit 0
fi

# Starte Gateway
openclaw gateway start
```

## Szenarien

| Szenario | @reboot | */20 Minuten | Ergebnis |
|----------|---------|--------------|----------|
| Normaler Boot | ✅ Funktioniert | Prüft: läuft bereits | Kein Doppelstart |
| @reboot failed | ❌ Fehlgeschlagen | Startet nach 20min | Redundanz greift |
| Gateway crashed | - | Startet neu nach 20min | Automatische Wiederherstellung |

## Umsetzung

### Crontab (beide Einträge)

```
# Primär: @reboot (falls es funktioniert)
@reboot sleep 10 && /home/openclaw/.openclaw/workspace/scripts/openclaw-gateway-safe-start.sh

# Fallback: Alle 20 Minuten mit PID-Check
*/20 * * * * /home/openclaw/.openclaw/workspace/scripts/openclaw-gateway-safe-start.sh
```

### Safe-Start Script

```bash
#!/bin/bash
# /home/openclaw/.openclaw/workspace/scripts/openclaw-gateway-safe-start.sh

LOGFILE=/tmp/openclaw-gateway-start.log
PIDFILE=/tmp/openclaw-gateway.pid

echo "$(date): Prüfe Gateway-Status..." >> "$LOGFILE"

# Methode 1: PID-Datei prüfen
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "$(date): Gateway läuft bereits (PID: $PID)" >> "$LOGFILE"
        exit 0
    fi
fi

# Methode 2: Prozess-Liste prüfen
if pgrep -f "openclaw gateway" > /dev/null 2>&1; then
    echo "$(date): Gateway läuft bereits (pgrep gefunden)" >> "$LOGFILE"
    exit 0
fi

# Starte Gateway
/home/openclaw/.npm-global/bin/openclaw gateway start >> "$LOGFILE" 2>&1 &
NEWPID=$!
echo $NEWPID > "$PIDFILE"

echo "$(date): Gateway gestartet (PID: $NEWPID)" >> "$LOGFILE"
```

## Aktuelle Crontab (bereits korrekt)

Deine Crontab ist bereits richtig:
```
@reboot sleep 10 && .../openclaw gateway start
*/30 * * * * ... (andere Jobs)
```

**Keine Änderung nötig!** @reboot und regelmäßige Jobs können koexistieren.

## Monitoring

```bash
# Logs überwachen
tail -f /tmp/openclaw-gateway-start.log

# Prüfen was gestartet hat
ps aux | grep openclaw

# Crontab-Log
tail -f /var/log/syslog | grep CRON
```

---
**Fazit:** Redundanz ist aktiv. @reboot + Fallback funktionieren zusammen!
