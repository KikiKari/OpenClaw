# ALERTING.md - Alerting System

## Änderung: Systemd → Cron (alle 15min)

Grund: Gateway lief unter root UND openclaw. Systemd-Wechsel verursachte Datenverlust.

## Alert-Skripte

### alert-all.sh
- Slack #slackclaw
- Slack DM (U0AP3JXHWBZ)
- WebChat

### TikTok LIVE Alerts
TikTok-Prüfungen erhalten den Handle zur Laufzeit; es gibt keine feste Account-Liste. Der alte `tiktok-live-alert.sh`-/Port-5001-Pfad ist deaktiviert. Neue Alert-Aufträge rufen `tiktok_dispatch.py` auf und behandeln `live`, `offline`, `restricted`, technische Fehler und Überlast getrennt. Eine URL wird nur bei Exit `0` und nach strikter Validierung weitergegeben.

Node-Ausführung erfolgt agent-gesteuert über `exec host=node` mit Gateway-Fallback. Der Dispatcher selbst sendet keine Alerts.

### node-health-alert.sh
Prüft Nodes:
- localhost:16000 (Node 1)
- localhost:15000 (Node 2 via Tunnel)
- localhost:18792 (Node 3 via Container)

## Crons (alle 15min)

```bash
*/15 * * * * /home/openclaw/bin/node-health-alert.sh
*/15 * * * * himalaya envelope list | head -10 >> /tmp/email-check.log
*/15 * * * * df -h / && uptime >> /tmp/system-check.log
```

## Token/Sicherheit
- Slack Token in: `~/.config/openclaw/env`
- GMX Passwort in: `~/.config/himalaya/.gmx_pass`
