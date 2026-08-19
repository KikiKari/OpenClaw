# Script Abstractions — Status

**Letzter Lauf:** 2026-08-19 05:39 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 120 |
| perl5 | 114 |
| powershell | 101 |
| python | 110 |
| shell | 105 |
| tcl | 127 |
| **gesamt** | **677** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 116 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 1320 | uebriger ausfuehrbarer Code |
| low | 60 | Markup und Stilvorlagen |
| **gesamt** | **1496** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **7175**

## Letzter Lauf

- bearbeitete Quelldateien: 33
- erzeugte Uebersetzungen: 134
- verworfen: 31

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
