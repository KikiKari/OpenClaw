# Worker Node Skill

**Status:** 🚧 Vorbereitend - Wartet auf Gateway-Integration

## Zweck
Worker Nodes führen Tasks aus, die vom Gateway zugewiesen werden. Unterstützen CPU-intensive, langlaufende oder isolierte Workloads.

## Verwendung
```bash
# Worker auf Node registrieren
openclaw cluster worker register --gateway <gateway-ip>

# Worker-Status prüfen
openclaw cluster worker status

# Verfügbare Ressourcen melden
openclaw cluster worker report

# Task ausführen (via Gateway-Anweisung)
openclaw cluster worker execute --task-id <id>

# Worker abmelden
openclaw cluster worker unregister
```

## Ressourcen-Profil

Jeder Worker meldet seine Kapazitäten:

```json
{
  "node_id": "node-2",
  "resources": {
    "cpu_cores": 4,
    "memory_gb": 8,
    "disk_gb": 160,
    "gpus": 0
  },
  "capabilities": [
    "shell",
    "docker",
    "python",
    "node"
  ],
  "limits": {
    "max_concurrent_tasks": 4,
    "max_task_duration": "1h"
  }
}
```

## Task-Typen

| Typ | Beschreibung | Beispiel |
|-----|--------------|----------|
| `shell` | Shell-Befehle | System-Administration |
| `script` | Skript-Ausführung | Python/Node-Automation |
| `container` | Docker/Podman | Isolierte Workloads |
| `download` | Datei-Downloads | Torrent/HTTP-Grabber |
| `build` | Kompilieren | Paketbau, Web-Builds |

## Workload-Beispiele

```bash
# Node 2: Backup-Scripts
worker task --type shell --script "backup-node3.sh"

# Node 4 (Mobile): Monitoring
worker task --type script --script "check-service-health.py"

# Container-Task
worker task --type container --image "alpine:latest" --cmd "apk update"
```

## Priorisierung

Tasks werden nach Priorität abgearbeitet:
1. **Kritisch** - Sofortausführung (z.B. Alerts)
2. **Hoch** - Normale Verarbeitung
3. **Niedrig** - Hintergrund-Tasks

## Fehlerbehandlung

| Szenario | Aktion |
|----------|--------|
| Task timeout | Retry auf anderem Worker |
| Worker offline | Queue für später |
| Resource exhaustion | Skalierung/Alert |

## Offene Punkte
- [ ] Task-Queue über Gateway
- [ ] Job-Status-Reporting
- [ ] Failover bei Worker-Ausfall

## Siehe auch
- [Cluster Gateway Skill](../cluster-gateway/SKILL.md)
- [Resource Manager Skill](../resource-manager/SKILL.md)
