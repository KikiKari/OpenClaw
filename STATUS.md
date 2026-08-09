# Script Abstractions — Status

**Letzter Lauf:** 2026-08-09 16:31 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 75 |
| perl5 | 72 |
| powershell | 60 |
| python | 64 |
| shell | 61 |
| tcl | 79 |
| **gesamt** | **411** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 120 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 1105 | uebriger ausfuehrbarer Code |
| low | 61 | Markup und Stilvorlagen |
| **gesamt** | **1286** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **6242**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 31
- verworfen: 169

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
