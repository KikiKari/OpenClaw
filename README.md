# Gateway 1 — Script Abstractions

Modellgenerierte und syntaktisch geprüfte Portierungen aus den konfigurierten
OpenClaw-, Projects- und Onboarding-Quellen. Der Abstraction Manager führt den
Bestand alle sechs Stunden fort und veröffentlicht direkt in diesem Branch.

## Aktueller Arbeitsstand

Letzter dokumentierter Lauf: **2026-08-09 01:59 UTC**. Detaillierte Lauf- und
Quellenzahlen stehen in [STATUS.md](STATUS.md).

| Sprache | Aktive Dateien | Verzeichnis |
| --- | ---: | --- |
| JavaScript | 33 | `javascript/` |
| Perl 5 | 34 | `perl5/` |
| PowerShell | 29 | `powershell/` |
| Python | 33 | `python/` |
| Shell | 25 | `shell/` |
| Tcl | 35 | `tcl/` |
| **Gesamt** | **189** | |

Der Lauf in `723dac3` ergänzte 184 Übersetzungen aus 40 Quelldateien. Die fünf
zuvor erzeugten Übersetzungen aus `f965cba` bleiben ebenfalls enthalten.

## Fortschreibung statt Verdrängung

Der vollständige Stand unmittelbar vor der Migration bleibt versioniert unter
[`historical/abstractions-pre-migration-20260808/`](historical/abstractions-pre-migration-20260808/)
erhalten. Er umfasst 125 damalige Branchpfade, darunter die ursprüngliche
README, den damaligen Statusbericht und 122 frühere Sprachdateien.

Die historische README ist unverändert abrufbar unter
[`gateway1-abstractions-before/README.md`](historical/abstractions-pre-migration-20260808/gateway1-abstractions-before/README.md).
Historische Sprachdateien bleiben getrennt, damit sie nicht als aktive,
modellgeprüfte Übersetzungen ausgegeben oder vom Manager weiterverwendet werden.

Ein zusätzlich vorgefundenes lokales, noch nicht veröffentlichtes Arbeitspaket
mit 182 Dateien wurde ebenfalls verlustfrei unter
[`recovered-uncommitted-20260809/`](historical/abstractions-pre-migration-20260808/.artifacts/recovered-uncommitted-20260809/)
gesichert. Es bleibt vom aktiven Bestand getrennt, bis es eigenständig geprüft
und gegebenenfalls übernommen wird.

## Veröffentlichung

Der aktive Manager schreibt in die sechs Sprachverzeichnisse, aktualisiert
`STATUS.md`, commitet angenommene Ergebnisse und veröffentlicht non-force nach
`gateway1-abstractions`. Ein separater Publisher ist nicht erforderlich.
