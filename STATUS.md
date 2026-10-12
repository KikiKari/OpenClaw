# Script Abstractions — Status

**Letzter Lauf:** 2026-10-12 10:50 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 289 |
| perl5 | 304 |
| powershell | 275 |
| python | 260 |
| shell | 273 |
| tcl | 325 |
| **gesamt** | **1726** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 129 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 2348 | uebriger ausfuehrbarer Code |
| low | 63 | Markup und Stilvorlagen |
| **gesamt** | **2540** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **11721**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 89
- verworfen: 27

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
