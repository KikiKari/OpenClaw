# Script Abstractions — Status

**Letzter Lauf:** 2026-10-30 05:07 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 527 |
| perl5 | 568 |
| powershell | 537 |
| python | 515 |
| shell | 448 |
| tcl | 591 |
| **gesamt** | **3186** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 148 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 3751 | uebriger ausfuehrbarer Code |
| low | 69 | Markup und Stilvorlagen |
| **gesamt** | **3968** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **18463**

## Letzter Lauf

- bearbeitete Quelldateien: 23
- erzeugte Uebersetzungen: 1
- verworfen: 22

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
