---
name: abstractions_utils
description: Portiert OpenClaw-Scripts automatisch in 10 Zielsprachen. Einzelnes Script per create_abstraction.py, Batch-Betrieb per ABSTRACTIONS_MANAGER.py (Cron alle 6h).
version: 1.0.0
metadata:
  openclaw:
    emoji: 🤖
    os: ["linux"]
    requires:
      bins:
        - python3
        - git
---

# abstractions-utils Skill

---

## Verwendung

### Einzelnes Script portieren

```bash
python3 /home/openclaw/.openclaw/workspace/skills/abstractions-utils/scripts/create_abstraction.py \
    --source /pfad/zum/script.py \
    --target-lang perl5
```

### Alle unterstützten Sprachen auf einmal

```bash
for lang in perl5 perl6 javascript shell powershell tcl ruby lua go; do
    python3 /home/openclaw/.openclaw/workspace/skills/abstractions-utils/scripts/create_abstraction.py \
        --source /pfad/zum/script.py \
        --target-lang $lang
done
```

### Batch-Betrieb (Cron, alle 6 Stunden)

```
0 */6 * * * /usr/bin/python3 /home/openclaw/.openclaw/workspace/skills/abstractions-utils/scripts/ABSTRACTIONS_MANAGER.py
```

### Manuell ausführen

```bash
python3 /home/openclaw/.openclaw/workspace/skills/abstractions-utils/scripts/ABSTRACTIONS_MANAGER.py
```

### Status-Report lesen

```bash
cat /home/openclaw/.openclaw/workspace/git/Abstraktionen/STATUS.md
```

### Letzten Lauf im Log prüfen

```bash
tail -50 /home/openclaw/.openclaw/workspace/logs/abstractions-manager/$(date +%Y-%m-%d).log
```

### Verarbeitungs-State zurücksetzen

```bash
rm /home/openclaw/.openclaw/workspace/db/abstractions_state.json
```

---

## Verfügbare Scripts

| Script | Funktion |
|--------|----------|
| `create_abstraction.py` | Einzelnes Script in eine Zielsprache portieren |
| `ABSTRACTIONS_MANAGER.py` | Batch-Orchestrator: alle Scripts, alle Nodes, Cron-Betrieb |

---

## Node-Übersicht

| Node | Gerät | Kapazität | Priorität |
|------|-------|-----------|-----------|
| node7 | Server (Docker-Hauptarbeitspferd) | high | 1 |
| node1 | Server (Gateway-Master) | medium | 2 |
| node2 | Server (Stable Worker) | medium | 3 |
| node3 | Server (bald verfügbar) | medium | 4 |
| node5 | Redmi Note 11S | low | 5 |

---

## Unterstützte Zielsprachen

- perl5, perl6
- javascript
- python
- shell
- powershell
- tcl
- ruby
- lua
- go

---

Ausgabe-Repository: `/home/openclaw/.openclaw/workspace/git/Abstraktionen`
State-Datei: `/home/openclaw/.openclaw/workspace/db/abstractions_state.json`
Logs: `/home/openclaw/.openclaw/workspace/logs/abstractions-manager/YYYY-MM-DD.log`
