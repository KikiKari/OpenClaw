# Script Abstractions — Status

**Letzter Lauf:** 2026-08-24 05:30 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 262 |
| perl5 | 267 |
| powershell | 237 |
| python | 220 |
| shell | 233 |
| tcl | 283 |
| **gesamt** | **1502** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 118 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 2117 | uebriger ausfuehrbarer Code |
| low | 60 | Markup und Stilvorlagen |
| **gesamt** | **2295** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **10556**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 196
- verworfen: 4

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
