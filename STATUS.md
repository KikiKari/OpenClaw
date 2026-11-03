# Script Abstractions — Status

**Letzter Lauf:** 2026-11-03 05:04 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 71 |
| perl5 | 75 |
| powershell | 64 |
| python | 65 |
| shell | 68 |
| tcl | 78 |
| **gesamt** | **421** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 150 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 4291 | uebriger ausfuehrbarer Code |
| low | 73 | Markup und Stilvorlagen |
| **gesamt** | **4514** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **22537**

## Letzter Lauf

- bearbeitete Quelldateien: 1
- erzeugte Uebersetzungen: 1
- verworfen: 0

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
