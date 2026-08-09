# Script Abstractions — Status

**Letzter Lauf:** 2026-08-08 23:16 UTC

Jede Quelldatei der drei Repositories wird in sechs Zielsprachen portiert.
Es werden vollstaendige Uebersetzungen abgelegt; Erzeugnisse ohne gueltige
Syntax oder mit Platzhaltern werden verworfen.

## Bestand

| Zielsprache | Dateien |
|---|---:|
| javascript | 69 |
| perl5 | 73 |
| powershell | 61 |
| python | 63 |
| shell | 66 |
| tcl | 75 |
| **gesamt** | **407** |

## Quellen

| Prioritaet | Quelldateien | Bedeutung |
|---|---:|---|
| high | 117 | Betriebsscripte aus scripts-Verzeichnissen |
| medium | 575 | uebriger ausfuehrbarer Code |
| low | 57 | Markup und Stilvorlagen |
| **gesamt** | **749** | nach Inhalt dedupliziert |

Noch offene Sprachpaare laut letztem Inventar: **3416**

## Letzter Lauf

- bearbeitete Quelldateien: 40
- erzeugte Uebersetzungen: 189
- verworfen: 11

## Herkunft

- `KikiKari/OpenClaw` — main, gateway1, gateway2
- `KikiKari/Projects` — alle Branches
- `KikiKari/Onboarding` — main

Erzeugt von `abstractions/ABSTRACTIONS_MANAGER.py`.

## Konsolidierung

Der Bestand wurde aus den am alten Veröffentlichungsziel erhaltenen echten
Erzeugnissen übernommen. Zwei dort abgeschnittene Tcl-Dateien wurden nicht
veröffentlicht. Für `tcl/1781743218784.tcl` wurde die bereits vorhandene,
vollständige und syntaxgültige Fassung dieses Ausgabe-Branches beibehalten.

Der vor dem Umschreiben gesicherte Verlauf bis `0b4e65f` ist wieder als echte
Git-Abstammung eingebunden. Neun dort noch nicht committed, aber vollständig
erzeugte und syntaxgültige Übersetzungen wurden unter den vom Manager
vorgesehenen Quellhash-Suffixen `2a8278` und `1af353` ergänzt. Dadurch wird
keine bereits vorhandene Übersetzung gleichen Namens überschrieben.
