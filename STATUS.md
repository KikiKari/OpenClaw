# Script Abstractions — Status

**Letzter Lauf:** 2026-08-23 04:23 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 205 |
| perl5 | 210 |
| powershell | 179 |
| python | 162 |
| shell | 174 |
| tcl | 223 |
| **gesamt** | **1153** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 118 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 1811 | uebriger ausfuehrbarer Code |
| low | 60 | Markup und Stilvorlagen |
| **gesamt** | **1989** | nach Inhalt dedupliziert |

Noch offene Sprachpaare: **9133**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 101
- verworfen: 23

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.
