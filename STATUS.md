# Script Abstractions — Status

**Letzter Lauf:** 2026-08-23 11:30 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 237 |
| perl5 | 242 |
| powershell | 210 |
| python | 192 |
| shell | 206 |
| tcl | 254 |
| **gesamt** | **1341** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 118 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 1960 | uebriger ausfuehrbarer Code |
| low | 60 | Markup und Stilvorlagen |
| **gesamt** | **2138** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **9775**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 199
- verworfen: 1

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
