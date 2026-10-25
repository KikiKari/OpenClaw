# Script Abstractions — Status

**Letzter Lauf:** 2026-10-25 11:29 UTC

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
| medium | 2898 | uebriger ausfuehrbarer Code |
| low | 69 | Markup und Stilvorlagen |
| **gesamt** | **3115** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **14032**

## Letzter Lauf

- bearbeitete Quelldateien: 10
- erzeugte Uebersetzungen: 1
- verworfen: 23

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
