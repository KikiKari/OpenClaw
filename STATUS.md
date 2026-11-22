# Script Abstractions — Status

**Letzter Lauf:** 2026-11-22 12:13 UTC

Jede Quelldatei der drei Repositories wird in zehn Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

GitHub-Stand: `f9008f7bf7375bd4dd71a909a2469ece81521763`

| Zielsprache | Dateien |
|---|---:|
| go | 232 |
| javascript | 1810 |
| lua | 308 |
| perl5 | 1996 |
| perl6 | 107 |
| powershell | 1942 |
| python | 1922 |
| ruby | 311 |
| shell | 1357 |
| tcl | 2144 |
| **gesamt** | **12129** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 398 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 6316 | uebriger ausfuehrbarer Code |
| low | 105 | Markup und Stilvorlagen |
| **gesamt** | **6819** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **58523**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 142
- verworfen: 166

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
