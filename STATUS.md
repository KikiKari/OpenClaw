# Script Abstractions — Status

**Letzter Lauf:** 2026-10-13 04:26 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 320 |
| perl5 | 344 |
| powershell | 312 |
| python | 293 |
| shell | 308 |
| tcl | 365 |
| **gesamt** | **1942** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 129 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 2370 | uebriger ausfuehrbarer Code |
| low | 63 | Markup und Stilvorlagen |
| **gesamt** | **2562** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **11568**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 72
- verworfen: 30

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
