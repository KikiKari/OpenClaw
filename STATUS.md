# Script Abstractions — Status

**Letzter Lauf:** 2026-08-09 01:59 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 33 |
| perl5 | 34 |
| powershell | 29 |
| python | 33 |
| shell | 25 |
| tcl | 35 |
| **gesamt** | **189** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 120 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 588 | uebriger ausfuehrbarer Code |
| low | 57 | Markup und Stilvorlagen |
| **gesamt** | **765** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **3693**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 184
- verworfen: 16

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
