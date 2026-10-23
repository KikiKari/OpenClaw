# Script Abstractions — Status

**Letzter Lauf:** 2026-10-23 22:13 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 367 |
| perl5 | 398 |
| powershell | 368 |
| python | 343 |
| shell | 349 |
| tcl | 422 |
| **gesamt** | **2247** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 148 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 2619 | uebriger ausfuehrbarer Code |
| low | 69 | Markup und Stilvorlagen |
| **gesamt** | **2836** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **12662**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 24
- verworfen: 31

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
