# Script Abstractions — Status

**Letzter Lauf:** 2026-10-25 17:26 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 420 |
| perl5 | 450 |
| powershell | 423 |
| python | 397 |
| shell | 368 |
| tcl | 475 |
| **gesamt** | **2533** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 148 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 3027 | uebriger ausfuehrbarer Code |
| low | 69 | Markup und Stilvorlagen |
| **gesamt** | **3244** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **14846**

## Letzter Lauf

- bearbeitete Quelldateien: 26
- erzeugte Uebersetzungen: 3
- verworfen: 23

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
