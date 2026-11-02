# Script Abstractions — Status

**Letzter Lauf:** 2026-11-02 05:10 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 597 |
| perl5 | 669 |
| powershell | 640 |
| python | 615 |
| shell | 496 |
| tcl | 698 |
| **gesamt** | **3715** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 150 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 4161 | uebriger ausfuehrbarer Code |
| low | 73 | Markup und Stilvorlagen |
| **gesamt** | **4384** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **20332**

## Letzter Lauf

- bearbeitete Quelldateien: 23
- erzeugte Uebersetzungen: 9
- verworfen: 22

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
