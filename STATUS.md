# Script Abstractions — Status

**Letzter Lauf:** 2026-08-22 00:50 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 166 |
| perl5 | 167 |
| powershell | 143 |
| python | 143 |
| shell | 150 |
| tcl | 184 |
| **gesamt** | **953** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 116 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 1671 | uebriger ausfuehrbarer Code |
| low | 60 | Markup und Stilvorlagen |
| **gesamt** | **1847** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **8629**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 96
- verworfen: 104

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
