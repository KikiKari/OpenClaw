# channel-status-agent Skill

**Name:** channel-status-agent  
**Beschreibung:** Automatische Status-Updates in Messaging-Channels  
**Version:** 1.0.0  
**Emoji:** 📊  

## Zweck

Sendet regelmäßige Status-Updates über System, Nodes und Agents in konfigurierte Channels.

## Features

- Tägliche Zusammenfassung (09:00)
- Wöchentlicher Report (Montag 09:00) 
- Kritische Alerts (sofort)
- Multi-Channel Support

## Verwendung

### Manueller Status
```bash
python3 scripts/channel_status.py --type daily
python3 scripts/channel_status.py --type weekly
python3 scripts/channel_status.py --type alert --message "Node 3 offline"
```

### Automatisch via Cron
```bash
# Täglich um 09:00
0 9 * * * python3 /workspace/skills/channel-status-agent/scripts/channel_status.py --type daily

# Wöchentlich Montag 09:00
0 9 * * 1 python3 /workspace/skills/channel-status-agent/scripts/channel_status.py --type weekly
```

## Status-Inhalte

### Täglicher Status
- Aktive Nodes (online/offline)
- Agent-Status (läuft/gestoppt)
- Fehler der letzten 24h
- Disk/RAM-Auslastung
- Neue Skills/Updates

### Wöchentlicher Report
- Verfügbarkeits-Statistik
- Top-Fehler
- Durchgeführte Updates
- Geplante Wartungen

## Konfiguration

```json
{
  "channel-status": {
    "channels": [
      {"type": "telegram", "id": "-1002381931352"},
      {"type": "discord", "id": "main"}
    ],
    "daily_time": "09:00",
    "weekly_day": "monday",
    "alert_threshold": "critical"
  }
}
```

## Integration

- Nutzt `message` Tool für Channel-Posts
- Liest Status aus logs.db und Systemmetriken
- Koordiniert mit reports-creator