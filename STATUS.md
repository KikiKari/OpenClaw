# Script Abstractions — Status

**Letzter Lauf:** 2026-11-04 20:34 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 653 |
| perl5 | 724 |
| powershell | 699 |
| python | 673 |
| shell | 519 |
| tcl | 755 |
| **gesamt** | **4023** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 151 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 4418 | uebriger ausfuehrbarer Code |
| low | 73 | Markup und Stilvorlagen |
| **gesamt** | **4642** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **21542**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 176
- verworfen: 24

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
