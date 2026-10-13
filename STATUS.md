# Script Abstractions — Status

**Letzter Lauf:** 2026-10-13 04:01 UTC

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
| high | 128 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 2371 | uebriger ausfuehrbarer Code |
| low | 63 | Markup und Stilvorlagen |
| **gesamt** | **2562** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **12819**

## Letzter Lauf

- bearbeitete Quelldateien: 1
- erzeugte Uebersetzungen: 1
- verworfen: 0

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
