# Script Abstractions — Status

**Letzter Lauf:** 2026-10-23 04:40 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 340 |
| perl5 | 368 |
| powershell | 337 |
| python | 315 |
| shell | 330 |
| tcl | 391 |
| **gesamt** | **2081** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 148 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 2426 | uebriger ausfuehrbarer Code |
| low | 69 | Markup und Stilvorlagen |
| **gesamt** | **2643** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **11738**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 80
- verworfen: 32

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
