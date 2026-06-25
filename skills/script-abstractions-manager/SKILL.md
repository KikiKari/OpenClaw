# script-abstractions-manager Skill

**Name:** script-abstractions-manager  
**Beschreibung:** Automatisierte Portierung von Scripts in alternative Programmiersprachen mit Multi-Node Unterstützung  
**Version:** 1.1.0  
**Emoji:** 🔄  
**Zuletzt aktualisiert:** 2026-04-18  

## Übersicht

Der Script Abstractions Manager erstellt automatisch Portierungen von Python-, JavaScript-, Shell- und anderen Scripts in alternative Programmiersprachen. Er unterstützt Multi-Node-Verteilung und nutzt verschiedene KI-Modelle für die Code-Interpolation.

## Zugehörige Skills

- **abstractions-utils** - Manuelles Erstellen von Abstraktionen
- **sub-agents-utils** - Sub-Agents spawnen/verwalten  
- **multi-nodes-utils** - Multi-Node Job-Verteilung

## Zielsprachen

| Sprache | Extension | Status |
|---------|-----------|--------|
| Perl 5 | `.pl` | ✅ Vollständig |
| Perl 6 (Raku) | `.raku` | ✅ Vollständig |
| JavaScript | `.js` | ✅ Vollständig |
| Python | `.py` | ✅ Vollständig |
| Bash/Shell | `.sh` | ✅ Vollständig |
| PowerShell | `.ps1` | ✅ Vollständig |
| Tcl | `.tcl` | ✅ Vollständig |
| Ruby | `.rb` | ✅ Vollständig |
| Lua | `.lua` | ✅ Vollständig |
| Go | `.go` | ✅ Vollständig |

## Multi-Node Support

| Node | Verfügbarkeit | Kapazität | Priorität | Gerät |
|------|---------------|-----------|-----------|-------|
| Node 1 | ✅ Immer | Medium | 2 | Gateway-Master |
| Node 2 | ✅ Immer | Medium | 3 | Stable Worker |
| Node 3 | 🔄 Bald | Medium | 4 | Nach Reorganisation |
| Node 5 | 📱 Bedingt | Low | 5 | Redmi Note 11S |
| Node 7 | 🆕 Bald | High | 1 | Docker Hauptarbeitspferd |

### Job-Verteilung

- **Heavy Jobs** (>50KB × Sprachen) → Node 7, Node 2, Node 1
- **Medium Jobs** (10-50KB × Sprachen) → Node 2, Node 1, Node 7
- **Light Jobs** (<10KB × Sprachen) → Node 5 (wenn verfügbar), Node 1, Node 2

## Verwendung

### Automatischer Betrieb (Cron)
```bash
# Läuft alle 6 Stunden via Cron
0 */6 * * * /usr/bin/python3 .../ABSTRACTIONS_MANAGER.py >> .../cron.log 2>&1
```

### Manuelle Ausführung
```bash
cd /home/openclaw/.openclaw/workspace
python3 skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py
```

### Mit Utils-Skills kombiniert
```bash
# Schnelle Abstraktion
cd skills/abstractions-utils/scripts
python3 create_abstraction.py --source /path/to/script.py --target-lang perl5

# Sub-Agent managen
cd skills/sub-agents-utils/scripts
python3 spawn_agent.py --task "Review code" --model openrouter/openai/gpt-4o

# Nodes checken
cd skills/multi-nodes-utils/scripts
python3 check_nodes.py --format table
```

## Ausgabe-Verzeichnisse

| Typ | Pfad |
|-----|------|
| **Repository** | `/home/openclaw/.openclaw/workspace/git/Abstraktionen/` |
| **Logs** | `/home/openclaw/.openclaw/workspace/logs/abstractions-manager/` |
| **State** | `/home/openclaw/.openclaw/workspace/db/abstractions_state.json` |
| **Status-Report** | `Abstraktionen/STATUS.md` |

## Prioritäts-Struktur

### High Priority (Top 5 Skills)
- skill-creator (5 Scripts)
- json-utils (4 Scripts)
- scripting-utils (4 Scripts)
- model-usage (2 Scripts)
- tiktok-live / tiktok-live-mon (nur aktive Scripts unter
  `$HOME/.openclaw/workspace/skills/...`; bei Portierungen den Dispatcher-
  Vertrag einschließlich Normalisierung, Restricted-Erkennung, URL-Validierung,
  Exit 75 und Prozess-Cleanup unverändert erhalten)

### Medium Priority (Workspace Scripts)
- 63 Scripts in `/workspace/scripts/`
- db-maintainer, log-collector, git-publish-agent

### Low Priority (Langzeitziel)
- 11.381 Scripts im gesamten `.openclaw` Verzeichnis

## KI-Modelle für Interpolation

Standardmäßig rotiert der Manager durch diese Modelle:
- `openrouter/moonshotai/kimi-k2.5`
- `openrouter/openai/gpt-4o`
- `openrouter/anthropic/claude-3-5-sonnet-20241022`
- `openrouter/google/gemini-2.0-flash-001`
- `openrouter/nvidia/llama-3.3-nemotron-super-49b-v1`
- `openrouter/qwen/qwen-2.5-coder-32b-instruct`

## Git Integration

Automatische Commits nach jedem Batch:
- "High priority: X abstractions"
- "Medium priority: X abstractions"

## Fehlerbehandlung

- **Node nicht erreichbar** → Fallback zu Node 1
- **Script zu groß** → Aufteilung in Chunks
- **Git-Konflikt** → Auto-merge mit Timestamp
- **Out of Memory** → Job-Queue pausieren

## Konfiguration

Editierbar in `scripts/ABSTRACTIONS_MANAGER.py`:
```python
NODES = {
    "node1": {"always_available": True, "capacity": "medium", "priority": 2},
    "node7": {"always_available": True, "capacity": "high", "priority": 1},
    # ...
}
```

## Abhängigkeiten

- Python 3.8+
- `openclaw` CLI
- Git
- Network-Zugriff zu Nodes (für Remote-Execution)

## Monitoring

```bash
# Live-Log anzeigen
tail -f /home/openclaw/.openclaw/workspace/logs/abstractions-manager/$(date +%Y-%m-%d).log

# Status-Report
cat /home/openclaw/.openclaw/workspace/git/Abstraktionen/STATUS.md

# Cron-Status
crontab -l | grep abstractions
```
