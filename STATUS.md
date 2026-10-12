# Script Abstractions — Status

**Letzter Lauf:** 2026-10-12 19:12 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 313 |
| perl5 | 329 |
| powershell | 300 |
| python | 285 |
| shell | 296 |
| tcl | 352 |
| **gesamt** | **1875** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 129 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 2360 | uebriger ausfuehrbarer Code |
| low | 63 | Markup und Stilvorlagen |
| **gesamt** | **2552** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **11591**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 190
- verworfen: 10

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
