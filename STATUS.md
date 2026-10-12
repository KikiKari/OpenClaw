# Script Abstractions — Status

**Letzter Lauf:** 2026-10-12 01:07 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 285 |
| perl5 | 289 |
| powershell | 260 |
| python | 243 |
| shell | 255 |
| tcl | 308 |
| **gesamt** | **1640** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 128 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 2140 | uebriger ausfuehrbarer Code |
| low | 62 | Markup und Stilvorlagen |
| **gesamt** | **2330** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **10583**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 179
- verworfen: 5

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
