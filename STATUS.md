# Script Abstractions — Status

**Letzter Lauf:** 2026-11-01 23:23 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 597 |
| perl5 | 667 |
| powershell | 638 |
| python | 614 |
| shell | 494 |
| tcl | 696 |
| **gesamt** | **3706** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 150 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 4151 | uebriger ausfuehrbarer Code |
| low | 73 | Markup und Stilvorlagen |
| **gesamt** | **4374** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **20291**

## Letzter Lauf

- bearbeitete Quelldateien: 13
- erzeugte Uebersetzungen: 20
- verworfen: 24

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
