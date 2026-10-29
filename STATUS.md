# Script Abstractions — Status

**Letzter Lauf:** 2026-10-29 01:35 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 504 |
| perl5 | 542 |
| powershell | 512 |
| python | 489 |
| shell | 439 |
| tcl | 569 |
| **gesamt** | **3055** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 148 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 3482 | uebriger ausfuehrbarer Code |
| low | 69 | Markup und Stilvorlagen |
| **gesamt** | **3699** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **16946**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 179
- verworfen: 21

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
