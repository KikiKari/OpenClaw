# Script Abstractions — Status

**Letzter Lauf:** 2026-11-22 23:01 UTC

Jede Quelldatei der drei Repositories wird in zehn Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

GitHub-Stand: `1d02dbb16435d2573c3e4b58db805e192028c7bf`

| Zielsprache | Dateien |
|---|---:|
| go | 232 |
| javascript | 1842 |
| lua | 348 |
| perl5 | 2021 |
| perl6 | 114 |
| powershell | 1969 |
| python | 1955 |
| ruby | 351 |
| shell | 1370 |
| tcl | 2175 |
| **gesamt** | **12377** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 398 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 6449 | uebriger ausfuehrbarer Code |
| low | 105 | Markup und Stilvorlagen |
| **gesamt** | **6952** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **59472**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 0
- verworfen: 206

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
