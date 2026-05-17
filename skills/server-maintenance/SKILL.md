# Server Maintenance Skill

**Status:** 🚧 Vorbereitend - Wartet auf Alerting-Schnittstelle

## Zweck
Automatisierte und manuelle Wartungsaufgaben für alle Cluster-Nodes: Updates, Backups, Monitoring, Security-Checks.

## Verwendung

```bash
# Wartungsfenster für Node öffnen
openclaw maintenance start --node <id> --duration <minutes>

# System-Updates
openclaw maintenance update --node <id> [--security-only]

# Backup durchführen
openclaw maintenance backup --node <id> [--full|--incremental]

# Log-Rotation
openclaw maintenance logs --node <id> --rotate [--compress]

# Security-Check
openclaw maintenance security --node <id> [--audit|--fix]

# Wartungsfenster schließen
openclaw maintenance end --node <id>
```

## Wartungs-Scheduler

```json
{
  "schedule": {
    "daily": [
      {"task": "backup", "time": "03:00", "nodes": ["all"]},
      {"task": "log-rotate", "time": "04:00", "nodes": ["all"]}
    ],
    "weekly": [
      {"task": "security-scan", "day": "sunday", "time": "02:00"},
      {"task": "update-check", "day": "monday", "time": "03:00"}
    ],
    "monthly": [
      {"task": "full-backup", "day": 1, "time": "01:00"},
      {"task": "disk-cleanup", "day": 15, "time": "02:00"}
    ]
  }
}
```

## Node-spezifische Tasks

### Node 1 (Gateway)
```bash
# Täglich
openclaw maintenance logs --node node-1 --retention 30
openclaw maintenance backup --node node-1 --dest /opt/backup/node1

# Wöchentlich
openclaw maintenance security --node node-1 --audit
openclaw maintenance update --node node-1 --security-only
```

### Node 2 (Worker)
```bash
# Container-Cleanup
openclaw maintenance docker --node node-2 --prune

# Task-Queue-Prüfung
openclaw cluster worker health --node node-2
```

### Node 3 (Relay) ⚠️
```bash
# Kritisch: Disk voll (95%)
openclaw maintenance disk --node node-3 --analyze
openclaw maintenance logs --node node-3 --older-than 180d --delete

# Kernel-Update (pending space)
# openclaw maintenance kernel --node node-3 --update
```

**Aktuelle Empfehlungen für Node 3:**
1. `find /home/pbot -name "*.log" -mtime +180 -delete` → ~5GB frei
2. `sqlite3 /home/pbot/pbot/rizon/message_history.sqlite3 "VACUUM;"` → ~500MB
3. Alternative: `/home/share/` als Mount für Node 5?

### Node 4 (Mobile)
```bash
# Begrenzte Wartung
openclaw maintenance battery --optimize
openclaw maintenance storage --cleanup
```

## Alert-Regeln (pending Messaging)

| Bedingung | Schwere | Aktion |
|-----------|---------|--------|
| Disk > 90% | 🔴 Kritisch | Sofort notify + cleanup |
| Load > 4.0 | 🔴 Kritisch | Task-Redistribution |
| RAM > 90% | 🟡 Warnung | Log + notify |
| Backup fehlgeschlagen | 🔴 Kritisch | Retry + notify |
| Security Alert | 🔴 Kritisch | Sofort notify |
| Service down | 🔴 Kritisch | Auto-restart + notify |

## Self-Healing

```bash
# Automatische Reparaturen
openclaw maintenance auto-heal --enable

# Beispiele:
# - Service crashed → restart
# - Disk full → cleanup old logs
# - Tunnel down → reconnect
# - WireGuard fail → fallback SSH
```

## Playbooks

### Emergency: Node 3 Disk Full
```bash
#!/bin/bash
# emergency-node3-cleanup.sh

# 1. Stop non-essential services
systemctl stop fail2ban
systemctl stop pmlogger

# 2. Aggressive log cleanup
journalctl --vacuum-size=100M
find /home/pbot -name "*.log" -mtime +30 -delete

# 3. Check space
df -h /

# 4. Restart services if OK
[ $(df / | tail -1 | awk '{print $5}' | tr -d '%') -lt 85 ] && \
  systemctl start fail2ban
```

## Offene Punkte
- [ ] Alerting-Channel (SMTP/Chat)
- [ ] Auto-Healing implementieren
- [ ] Backup-Storage Node 5 vs Node 3

## Siehe auch
- [Resource Manager Skill](../resource-manager/SKILL.md)
- [Cluster Gateway Skill](../cluster-gateway/SKILL.md)
- Node 3 DataSheet: Disk-Warnung
