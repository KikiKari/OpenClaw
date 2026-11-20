# Script Abstractions — Status

**Letzter Lauf:** 2026-11-20 03:19 UTC

Jede Quelldatei der drei Repositories wird in zehn Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| go | 153 |
| javascript | 798 |
| lua | 185 |
| perl5 | 887 |
| perl6 | 72 |
| powershell | 870 |
| python | 868 |
| ruby | 188 |
| shell | 631 |
| tcl | 955 |
| **gesamt** | **5607** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 398 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 6183 | uebriger ausfuehrbarer Code |
| low | 105 | Markup und Stilvorlagen |
| **gesamt** | **6686** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **57810**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 196
- verworfen: 75

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
