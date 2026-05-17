# Resource Manager Skill

**Status:** 🚧 Vorbereitend - Wartet auf Monitoring-Daten

## Zweck
Überwacht und verwaltet Cluster-Ressourcen (CPU, RAM, Disk, Netzwerk) über alle Nodes hinweg.

## Verwendung
```bash
# Cluster-Ressourcen anzeigen
openclaw cluster resources status

# Ressourcen eines Nodes
openclaw cluster resources node <node-id>

# Ressourcen-Alarme konfigurieren
openclaw cluster resources alert --threshold <percent> --metric <cpu|mem|disk>

# Load Balancing konfigurieren
openclaw cluster resources balance --strategy [round-robin|least-load|capability]

# Historische Daten
openclaw cluster resources history --node <node-id> --hours <n>
```

## Ressourcen-Übersicht

| Node | CPU | RAM | Disk | Load | Status |
|------|-----|-----|------|------|--------|
| Node 1 | 2C | 4GB | 80GB | 0.5 | ✅ OK |
| Node 2 | 4C | 8GB | 160GB | 0.3 | ✅ OK |
| Node 3 | 4C | 8GB | 39GB | 1.2 | ⚠️ Disk 95% |
| Node 4 | 8C | 6GB | 128GB | ? | ⏳ Pending |
| Node 5 | N/A | N/A | 25GB | N/A | 🌐 Webhosting |

## Thresholds & Alerts

```json
{
  "alerts": {
    "cpu": {"warning": 80, "critical": 95},
    "memory": {"warning": 85, "critical": 95},
    "disk": {"warning": 80, "critical": 90},
    "load": {"warning": 2.0, "critical": 4.0}
  },
  "actions": {
    "warning": "log",
    "critical": "notify"  // pending messaging
  }
}
```

## Aktuelle Status (Node 3 - Kritisch)

```
⚠️  WARNUNG: Node 3 (xnetx)
   Disk Usage: 37G / 39G (95%)
   │
   ├─ 4.5 GB /home/pbot/pbot/rizon/log/log
   ├─ 1.4 GB /home/pbot/pbot/rizon/message_history.sqlite3
   ├─ 671 MB /home/pbot/pbot/ircnet/log/log
   └─ ... weitere Logs
   
   Empfohlene Aktion:
   → Logs archivieren/löschen
   → SQLite VACUUM
   → ODER Kernel-Update + WireGuard
```

## Load Balancing Strategien

| Strategie | Beschreibung |
|-----------|--------------|
| `round-robin` | Gleichmäßige Verteilung |
| `least-load` | An Node mit geringster Last |
| `capability` | Basierend auf Fähigkeiten |
| `proximity` | Nächster Node (Latency) |
| `data-locality` | Wo Daten bereits liegen |

## Zukünftige Features

```bash
# Automatische Skalierung
openclaw cluster resources scale --add-node --type worker

# Ressourcen-Vorhersage
openclaw cluster resources forecast --days 7

# Kosten-Optimierung
openclaw cluster resources optimize --max-cost <eur>
```

## Offene Punkte
- [ ] Echte Monitoring-Daten von Nodes
- [ ] Alerting-Channel (SMTP/Slack/WebChat)
- [ ] Live-Dashboard

## Integration

```javascript
// Beispiel: Task-Scheduling mit Ressourcen-Check
const node = resourceManager.selectNode({
  minCpu: 2,
  minMemory: "4GB",
  diskAvailable: "1GB",
  capabilities: ["docker"]
});

clusterGateway.deploy(node, task);
```

## Siehe auch
- [Cluster Gateway Skill](../cluster-gateway/SKILL.md)
- [Worker Node Skill](../worker-node/SKILL.md)
- [Server Maintenance Skill](../server-maintenance/SKILL.md)
