# node-health-monitor Skill

**Name:** node-health-monitor  
**Beschreibung:** Überwacht Health-Status aller Cluster-Nodes  
**Version:** 1.0.0  
**Emoji:** 🏥  

## Zweck

Kontinuierliche Überwachung von Node-Verfügbarkeit, Ressourcen und Services.

## Features

- SSH-basierte Health-Checks
- Resource-Monitoring (CPU, RAM, Disk)
- Service-Status (OpenClaw, Docker, etc.)
- Automatische Alerts bei Problemen
- Multi-Node SSH/VPN Support

## Checks pro Node

| Check | Schwellwert | Alert |
|-------|-------------|-------|
| Ping/SSH | Timeout 10s | Sofort |
| CPU | > 90% | Nach 5 Min |
| RAM | > 90% | Nach 5 Min |
| Disk | > 85% | Warnung |
| Disk | > 95% | Kritisch |
| Gateway | Nicht läuft | Sofort |

## Verwendung

### Einzelner Check
```bash
python3 scripts/node_health.py --node node1 --check all
python3 scripts/node_health.py --node node2 --check disk
python3 scripts/node_health.py --node all --check ping
```

### Kontinuierliches Monitoring
```bash
# Alle 3 Stunden via Cron (geändert 2026-04-20, vorher: */45 bzw. */55)
0 */3 * * * python3 /workspace/skills/node-health-monitor/scripts/node_health.py --node all --alert
```
**Modell:** `openrouter/moonshotai/kimi-k3`

## Node-Konfiguration

```json
{
  "nodes": {
    "node1": {
      "name": "Gateway",
      "host": "localhost",
      "ssh_port": 22,
      "critical": true
    },
    "node2": {
      "name": "Worker",
      "host": "100.109.255.27",
      "ssh_port": 22,
      "via": "tailscale"
    },
    "node3": {
      "name": "Relay",
      "host": "node3.example.com",
      "ssh_port": 22,
      "alerts": {"disk": 90}
    }
  }
}
```

## Alert-Integration

- Nutzt `channel-status-agent` für kritische Alerts
- Schreibt in `health.db` für Historie
- Kann Auto-Healing triggern

## Metriken

Sammelt und speichert:
- Verfügbarkeit % (Uptime)
- Response-Zeit (ms)
- Resource-Trends
- Service-Ausfälle
