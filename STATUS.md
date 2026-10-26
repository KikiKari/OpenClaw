# Script Abstractions — Status

**Letzter Lauf:** 2026-10-26 11:36 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 444 |
| perl5 | 475 |
| powershell | 449 |
| python | 422 |
| shell | 390 |
| tcl | 502 |
| **gesamt** | **2682** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 148 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 3177 | uebriger ausfuehrbarer Code |
| low | 69 | Markup und Stilvorlagen |
| **gesamt** | **3394** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **15600**

## Letzter Lauf

- bearbeitete Quelldateien: 10
- erzeugte Uebersetzungen: 1
- verworfen: 22

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
