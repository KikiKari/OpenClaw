# Script Abstractions — Status

**Letzter Lauf:** 2026-08-24 00:01 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 238 |
| perl5 | 243 |
| powershell | 211 |
| python | 192 |
| shell | 208 |
| tcl | 256 |
| **gesamt** | **1348** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 118 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 1960 | uebriger ausfuehrbarer Code |
| low | 60 | Markup und Stilvorlagen |
| **gesamt** | **2138** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **9768**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 7
- verworfen: 101

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
