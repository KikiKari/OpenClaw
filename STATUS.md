# Script Abstractions — Status

**Letzter Lauf:** 2026-08-22 04:23 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 167 |
| perl5 | 167 |
| powershell | 145 |
| python | 143 |
| shell | 150 |
| tcl | 184 |
| **gesamt** | **956** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 116 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 1679 | uebriger ausfuehrbarer Code |
| low | 60 | Markup und Stilvorlagen |
| **gesamt** | **1855** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **8664**

## Letzter Lauf

- bearbeitete Quelldateien: 13
- erzeugte Uebersetzungen: 5
- verworfen: 26

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
