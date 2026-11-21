# Script Abstractions — Status

**Letzter Lauf:** 2026-11-21 17:15 UTC

Jede Quelldatei der drei Repositories wird in zehn Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

GitHub-Stand: `79aca45b1136363e0106f8c3cb393a1efc3ec947`

| Zielsprache | Dateien |
|---|---:|
| go | 214 |
| javascript | 1794 |
| lua | 286 |
| perl5 | 1986 |
| perl6 | 104 |
| powershell | 1925 |
| python | 1900 |
| ruby | 288 |
| shell | 1348 |
| tcl | 2123 |
| **gesamt** | **11968** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 398 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 6316 | uebriger ausfuehrbarer Code |
| low | 105 | Markup und Stilvorlagen |
| **gesamt** | **6819** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **58679**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 0
- verworfen: 282

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
