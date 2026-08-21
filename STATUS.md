# Script Abstractions — Status

**Letzter Lauf:** 2026-08-21 00:09 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 152 |
| perl5 | 152 |
| powershell | 128 |
| python | 127 |
| shell | 136 |
| tcl | 168 |
| **gesamt** | **863** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 116 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 1546 | uebriger ausfuehrbarer Code |
| low | 60 | Markup und Stilvorlagen |
| **gesamt** | **1722** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **8100**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 29
- verworfen: 104

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
