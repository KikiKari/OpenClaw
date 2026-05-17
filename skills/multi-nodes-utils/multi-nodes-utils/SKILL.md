# multi-nodes-utils Skill

**Name:** multi-nodes-utils  
**Beschreibung:** Tools für Multi-Node Verwaltung und Job-Verteilung  
**Version:** 1.0.0  
**Emoji:** 🌐  

## Node-Übersicht

| Node | Verfügbarkeit | Kapazität | Gerät | Besonderheit |
|------|---------------|-----------|-------|--------------|
| Node 1 | ✅ Immer | Medium | Server | Gateway-Master |
| Node 2 | ✅ Immer | Medium | Server | Stable Worker |
| Node 3 | 🔄 Bald | Medium | Server | Wie Node 2 |
| Node 5 | 📱 Bedingt | Low | Redmi Note 11S | Mobile Internet |
| Node 7 | 🆕 Bald | High | Docker | Hauptarbeitspferd |

## Job-Verteilung

| Job-Typ | Gewicht | Bevorzugte Nodes |
|---------|---------|------------------|
| Heavy | >50KB × Sprachen | Node 7, Node 2, Node 1 |
| Medium | 10-50KB × Sprachen | Node 2, Node 1, Node 7 |
| Light | <10KB × Sprachen | Node 5, Node 1, Node 2 |

## Verfügbare Scripts

| Script | Funktion |
|--------|----------|
| `dispatch_job.py` | Job auf passenden Node verteilen |
| `check_nodes.py` | Status aller Nodes prüfen |
| `node_health.py` | Gesundheits-Check pro Node |
| `route_task.py` | Task-Routing mit Fallback |

## Schnellnutzung

### Single Job dispatch
```bash
python3 .../dispatch_job.py \
  --job "process_large_file.py" \
  --weight heavy \
  --wait
```

### Node-Status check
```bash
python3 .../check_nodes.py --format table
```

### Automatisches Routing
```bash
python3 .../route_task.py \
  --script /path/to/script.py \
  --target-langs perl5,javascript,python \
  --dispatch
```

## Node-Konfiguration

JSON-Konfiguration in `nodes_config.json`:
```json
{
  "nodes": {
    "node1": {
      "always_available": true,
      "capacity": "medium",
      "priority": 2,
      "ssh_host": "localhost"
    },
    "node5": {
      "always_available": false,
      "capacity": "low",
      "priority": 5,
      "device": "Redmi Note 11S",
      "condition": "mobile_internet"
    },
    "node7": {
      "always_available": true,
      "capacity": "high",
      "priority": 1,
      "docker": true
    }
  }
}
```

## Programmatische Nutzung

```python
from multi_nodes_utils import NodeRouter

router = NodeRouter()
node = router.select_node(job_weight="heavy")
print(f"Selected: {node}")  # -> node7

# Mit Fallback
result = router.dispatch("task.py", preferred="node7", fallback=["node2", "node1"])
```