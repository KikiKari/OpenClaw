# Gateway 1 — Script Abstractions

Modellgenerierte und syntaktisch geprüfte Portierungen aus den konfigurierten
OpenClaw-, Projects- und Onboarding-Quellen. Der Abstraction Manager führt den
Bestand alle sechs Stunden fort und veröffentlicht direkt in diesem Branch.

## Aktueller Arbeitsstand

Letzter dokumentierter Lauf: **2026-08-09 08:16 UTC**. Detaillierte Lauf- und
Quellenzahlen stehen in [STATUS.md](STATUS.md).

| Sprache | Aktive Dateien | Verzeichnis |
| --- | ---: | --- |
| JavaScript | 64 | `javascript/` |
| Perl 5 | 61 | `perl5/` |
| PowerShell | 54 | `powershell/` |
| Python | 58 | `python/` |
| Shell | 55 | `shell/` |
| Tcl | 68 | `tcl/` |
| **Gesamt** | **360** | |

Die ursprünglichen Job-Commits bleiben Teil der Historie: `f965cba` erzeugte
fünf High-Priority-Übersetzungen, `723dac3` erzeugte 184 Medium-Priority-
Übersetzungen und `14b5336` erzeugte 213 Low-Priority-Übersetzungen. Der letzte
Lauf verwarf zusätzlich 27 nicht bestandene Ergebnisse.

## Fortschreibung statt Verdrängung

Der vollständige Stand unmittelbar vor der Migration bleibt versioniert unter
[`historical/abstractions-pre-migration-20260808/`](historical/abstractions-pre-migration-20260808/)
erhalten. Er umfasst 125 damalige Branchpfade, darunter die ursprüngliche
README, den damaligen Statusbericht und 122 frühere Sprachdateien.

Die historische README ist unverändert abrufbar unter
[`gateway1-abstractions-before/README.md`](historical/abstractions-pre-migration-20260808/gateway1-abstractions-before/README.md).
Historische Sprachdateien bleiben getrennt, damit sie nicht als aktive,
modellgeprüfte Übersetzungen ausgegeben oder vom Manager weiterverwendet werden.

Ein während des letzten Laufs vorgefundener Zwischenstand mit 182 Dateien wurde
zusätzlich verlustfrei unter
[`recovered-uncommitted-20260809/`](historical/abstractions-pre-migration-20260808/.artifacts/recovered-uncommitted-20260809/)
gesichert. Der später regulär abgeschlossene Originalcommit `14b5336` ist in
den aktiven Bestand integriert; der Zwischenstand bleibt als Prüfbeleg getrennt.

## Veröffentlichung

Der aktive Manager schreibt in die sechs Sprachverzeichnisse, aktualisiert
`STATUS.md`, commitet angenommene Ergebnisse und veröffentlicht non-force nach
`gateway1-abstractions`. Ein separater Publisher ist nicht erforderlich.
