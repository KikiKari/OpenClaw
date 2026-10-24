# Script Abstractions — Status

**Letzter Lauf:** 2026-10-24 16:14 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 395 |
| perl5 | 427 |
| powershell | 399 |
| python | 371 |
| shell | 358 |
| tcl | 450 |
| **gesamt** | **2400** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 148 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 2761 | uebriger ausfuehrbarer Code |
| low | 69 | Markup und Stilvorlagen |
| **gesamt** | **2978** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **13354**

## Letzter Lauf

- bearbeitete Quelldateien: 34
- erzeugte Uebersetzungen: 25
- verworfen: 26

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
