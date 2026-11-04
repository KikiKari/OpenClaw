# Script Abstractions — Status

**Letzter Lauf:** 2026-11-04 01:56 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 630 |
| perl5 | 701 |
| powershell | 674 |
| python | 646 |
| shell | 507 |
| tcl | 728 |
| **gesamt** | **3886** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 151 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 4290 | uebriger ausfuehrbarer Code |
| low | 73 | Markup und Stilvorlagen |
| **gesamt** | **4514** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **20921**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 161
- verworfen: 35

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
