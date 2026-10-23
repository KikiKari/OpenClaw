# Script Abstractions — Status

**Letzter Lauf:** 2026-10-23 17:38 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 365 |
| perl5 | 395 |
| powershell | 366 |
| python | 340 |
| shell | 347 |
| tcl | 418 |
| **gesamt** | **2231** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 148 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 2613 | uebriger ausfuehrbarer Code |
| low | 69 | Markup und Stilvorlagen |
| **gesamt** | **2830** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **12656**

## Letzter Lauf

- bearbeitete Quelldateien: 16
- erzeugte Uebersetzungen: 36
- verworfen: 24

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
