# Script Abstractions — Status

**Letzter Lauf:** 2026-10-29 23:29 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 527 |
| perl5 | 567 |
| powershell | 537 |
| python | 515 |
| shell | 448 |
| tcl | 591 |
| **gesamt** | **3185** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 148 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 3628 | uebriger ausfuehrbarer Code |
| low | 69 | Markup und Stilvorlagen |
| **gesamt** | **3845** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **17687**

## Letzter Lauf

- bearbeitete Quelldateien: 9
- erzeugte Uebersetzungen: 1
- verworfen: 21

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
