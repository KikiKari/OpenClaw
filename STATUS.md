# Script Abstractions — Status

**Letzter Lauf:** 2026-11-03 05:11 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 607 |
| perl5 | 678 |
| powershell | 651 |
| python | 625 |
| shell | 500 |
| tcl | 706 |
| **gesamt** | **3767** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 151 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 4290 | uebriger ausfuehrbarer Code |
| low | 73 | Markup und Stilvorlagen |
| **gesamt** | **4514** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **21082**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 4
- verworfen: 196

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
