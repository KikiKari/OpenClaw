# Script Abstractions — Status

**Letzter Lauf:** 2026-08-09 08:16 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 64 |
| perl5 | 61 |
| powershell | 54 |
| python | 58 |
| shell | 55 |
| tcl | 68 |
| **gesamt** | **360** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 120 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 735 | uebriger ausfuehrbarer Code |
| low | 57 | Markup und Stilvorlagen |
| **gesamt** | **912** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **4399**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 213
- verworfen: 27

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
