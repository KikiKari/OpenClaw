# ABSTRACTIONS - Script-Portierungen

**Dokumentation zentral:** `/home/openclaw/.openclaw/workspace/ABSTRACTIONS.md`  
**Repository:** `/home/openclaw/.openclaw/workspace/git/Abstraktionen/`  
**Erstellt:** 2026-04-18  
**Zuletzt aktualisiert:** 2026-04-18  

---

## Übersicht

Dieses Projekt portiert OpenClaw-Scripts und -Skills in alternative Programmiersprachen, um:
- **Flexibilität** zu erhöhen (nicht nur Python/JS)
- **Lernressourcen** zu schaffen (Vergleich Implementierungen)
- **Wiederverwendbarkeit** zu ermöglichen (Sprach-spezifische Integration)
- **Redundanz** zu schaffen (Fallback-Implementierungen)

---

## Struktur

```
git/Abstraktionen/
├── perl5/           # Perl 5 Portierungen (.pl)
├── perl6/           # Raku Portierungen (.raku)
├── javascript/      # Node.js Portierungen (.js)
├── python/          # Python Portierungen (.py)
├── shell/           # Bash Portierungen (.sh)
├── powershell/      # PowerShell Portierungen (.ps1)
├── tcl/             # Tcl Portierungen (.tcl)
├── ruby/            # Ruby Portierungen (.rb)
├── lua/             # Lua Portierungen (.lua)
├── go/              # Go Portierungen (.go)
├── STATUS.md        # Automatisch generierter Status-Report
└── README.md        # Repository-Übersicht
```

---

## Automatisierung

### Haupt-Script
`/home/openclaw/.openclaw/workspace/skills/script-abstractions-manager/scripts/abstractions_manager.py`

- Läuft alle 6 Stunden via Cron
- Verteilt Jobs auf Multi-Node-Infrastruktur
- Nutzt verschiedene KI-Modelle für Code-Interpolation

### Cron-Job
```
0 */6 * * * /usr/bin/python3 /home/openclaw/.openclaw/workspace/skills/script-abstractions-manager/scripts/abstractions_manager.py >> /home/openclaw/.openclaw/workspace/logs/abstractions-manager/cron.log 2>&1
```

### Manuelle Tools

| Tool | Pfad | Funktion |
|------|------|----------|
| create_abstraction.py | `skills/abstractions-utils/scripts/` | Einzelne Portierung |
| spawn_agent.py | `skills/sub-agents-utils/scripts/` | Sub-Agent spawnen |
| check_nodes.py | `skills/multi-nodes-utils/scripts/` | Node-Status prüfen |
| dispatch_job.py | `skills/multi-nodes-utils/scripts/` | Job verteilen |

---

## Multi-Node Infrastruktur

| Node | Rolle | Status |
|------|-------|--------|
| Node 1 | Gateway-Master, Medium Capacity | ✅ Aktiv |
| Node 2 | Stable Worker, Medium Capacity | ✅ Aktiv |
| Node 3 | Worker (bald verfügbar) | 🔄 Reorganisation |
| Node 5 | Mobile (Redmi Note 11S) | 📱 Intermittent |
| Node 7 | Docker High-Capacity | 🆕 Bald verfügbar |

---

## Zielsprachen

| Sprache | Extension | Besonderheit |
|---------|-----------|--------------|
| Perl 5 | `.pl` | Klassisch, stabil |
| Perl 6 (Raku) | `.raku` | Modern, expressiv |
| JavaScript | `.js` | Node.js Ecosystem |
| Python | `.py` | OpenClaw-Standard |
| Bash/Shell | `.sh` | Unix-native |
| PowerShell | `.ps1` | Windows/Cross-platform |
| Tcl | `.tcl` | Eingebettbar, simpel |
| Ruby | `.rb` | Expressiv, lesbar |
| Lua | `.lua` | Lightweight, eingebettbar |
| Go | `.go` | Kompiliert, schnell |

---

## Verwendung

### Repository klonen
```bash
cd /home/openclaw/.openclaw/workspace/git/Abstraktionen
git log --oneline -10
```

### Eigene Portierung erstellen
```bash
cd /home/openclaw/.openclaw/workspace/skills/abstractions-utils/scripts
python3 create_abstraction.py \
  --source /path/to/original.py \
  --target-lang perl5
```

### Sub-Agent für komplexe Portierung
```bash
cd /home/openclaw/.openclaw/workspace/skills/sub-agents-utils/scripts
python3 spawn_agent.py \
  --task "Port json_processor.py to Go with full error handling" \
  --model openrouter/anthropic/claude-haiku-4.5 \
  --timeout 1800
```

---

## Status

Siehe aktuellen Status-Report:
```bash
cat /home/openclaw/.openclaw/workspace/git/Abstraktionen/STATUS.md
```

---

## Referenzen

- **Skill-Doku:** `skills/script-abstractions-manager/SKILL.md`
- **Cron-Config:** `crons/abstractions-manager.cron`
- **State:** `db/abstractions_state.json`
- **Logs:** `logs/abstractions-manager/`

---

## Backup

Tägliche Backups in:
```
/workspace/backups/YYYYMMDD/
├── SKILL.md
└── abstractions_manager.py
```

---

**Hinweis:** Dies ist ein automatisiertes Langzeitprojekt. Portierungen werden iterativ verbessert und erweitert.