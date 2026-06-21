# ALERTING.md - Alerting System

> Historisches Dokument. Aktuelle Pfade, Live-Erkennung und Multi-Node-
> Ausführung: `/home/openclaw/.openclaw/workspace/TIKTOK-CURRENT.md`.

## Änderung: Systemd → Cron (alle 15min)

Grund: Gateway lief unter root UND openclaw. Systemd-Wechsel verursachte Datenverlust.

## Alert-Skripte

### alert-all.sh
- Slack #slackclaw
- Slack DM (U0AP3JXHWBZ)
- WebChat

### tiktok-live-alert.sh
Prüft: @example_creator, @example_creator
- API: localhost:5001 oder localhost:16000
- Bei Live: Alert + VLC-Link

### node-health-alert.sh
Prüft Nodes:
- localhost:16000 (Node 1)
- localhost:15000 (Node 2 via Tunnel)
- localhost:18792 (Node 3 via Container)

## Crons (alle 15min)

```bash
*/15 * * * * /home/openclaw/bin/tiktok-live-alert.sh
*/15 * * * * /home/openclaw/bin/node-health-alert.sh
*/15 * * * * himalaya envelope list | head -10 >> /tmp/email-check.log
*/15 * * * * df -h / && uptime >> /tmp/system-check.log
```

## Token/Sicherheit
- Slack Token in: `~/.config/openclaw/env`
- GMX Passwort in: `~/.config/himalaya/.gmx_pass`
