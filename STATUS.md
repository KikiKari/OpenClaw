# Script Abstractions — Status

**Letzter Lauf:** 2026-11-01 05:18 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 576 |
| perl5 | 641 |
| powershell | 611 |
| python | 587 |
| shell | 480 |
| tcl | 668 |
| **gesamt** | **3563** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 148 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 4004 | uebriger ausfuehrbarer Code |
| low | 69 | Markup und Stilvorlagen |
| **gesamt** | **4221** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **19548**

## Letzter Lauf

- bearbeitete Quelldateien: 9
- erzeugte Uebersetzungen: 1
- verworfen: 20

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
