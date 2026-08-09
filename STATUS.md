# Script Abstractions — Status

**Letzter Lauf:** 2026-08-09 10:10 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 69 |
| perl5 | 73 |
| powershell | 61 |
| python | 63 |
| shell | 66 |
| tcl | 75 |
| **gesamt** | **407** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 119 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 931 | uebriger ausfuehrbarer Code |
| low | 58 | Markup und Stilvorlagen |
| **gesamt** | **1108** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **5593**

## Letzter Lauf

- bearbeitete Quelldateien: 1
- erzeugte Uebersetzungen: 5
- verworfen: 1

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
