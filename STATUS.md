# Script Abstractions — Status

**Letzter Lauf:** 2026-08-19 10:39 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 147 |
| perl5 | 146 |
| powershell | 125 |
| python | 125 |
| shell | 130 |
| tcl | 161 |
| **gesamt** | **834** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 116 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 1443 | uebriger ausfuehrbarer Code |
| low | 60 | Markup und Stilvorlagen |
| **gesamt** | **1619** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **7614**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 176
- verworfen: 18

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
