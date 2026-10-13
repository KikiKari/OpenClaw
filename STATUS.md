# Script Abstractions — Status

**Letzter Lauf:** 2026-10-13 12:48 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 339 |
| perl5 | 364 |
| powershell | 332 |
| python | 313 |
| shell | 326 |
| tcl | 387 |
| **gesamt** | **2061** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 129 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 2370 | uebriger ausfuehrbarer Code |
| low | 63 | Markup und Stilvorlagen |
| **gesamt** | **2562** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **11407**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 161
- verworfen: 4

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
