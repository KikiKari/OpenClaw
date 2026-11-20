# Script Abstractions — Status

**Letzter Lauf:** 2026-11-20 18:50 UTC

Jede Quelldatei der drei Repositories wird in zehn Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

GitHub-Stand: `6adc8e6bbe43d81e5d786b41f769ca09e338935b`

| Zielsprache | Dateien |
|---|---:|
| go | 210 |
| javascript | 1790 |
| lua | 282 |
| perl5 | 1985 |
| perl6 | 103 |
| powershell | 1921 |
| python | 1896 |
| ruby | 284 |
| shell | 1348 |
| tcl | 2119 |
| **gesamt** | **11938** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 398 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 6183 | uebriger ausfuehrbarer Code |
| low | 105 | Markup und Stilvorlagen |
| **gesamt** | **6686** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **57559**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 13
- verworfen: 225

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
