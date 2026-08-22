# Script Abstractions — Status

**Letzter Lauf:** 2026-08-22 04:04 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 70 |
| perl5 | 74 |
| powershell | 62 |
| python | 64 |
| shell | 66 |
| tcl | 76 |
| **gesamt** | **412** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 115 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 1680 | uebriger ausfuehrbarer Code |
| low | 60 | Markup und Stilvorlagen |
| **gesamt** | **1855** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **9313**

## Letzter Lauf

- bearbeitete Quelldateien: 1
- erzeugte Uebersetzungen: 6
- verworfen: 0

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
