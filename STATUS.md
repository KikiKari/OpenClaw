# Script Abstractions — Status

**Letzter Lauf:** 2026-10-12 04:37 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 288 |
| perl5 | 291 |
| powershell | 262 |
| python | 245 |
| shell | 257 |
| tcl | 310 |
| **gesamt** | **1653** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 128 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 2195 | uebriger ausfuehrbarer Code |
| low | 63 | Markup und Stilvorlagen |
| **gesamt** | **2386** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **10833**

## Letzter Lauf

- bearbeitete Quelldateien: 15
- erzeugte Uebersetzungen: 31
- verworfen: 25

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
