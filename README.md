# Gateway 1 — Script Abstractions

Modellgenerierte und syntaktisch geprüfte Portierungen aus den konfigurierten
OpenClaw-, Projects- und Onboarding-Quellen. Der Abstraction Manager führt den
Bestand alle sechs Stunden fort und veröffentlicht direkt in diesem Branch.

## Aktueller Arbeitsstand

Stand laut [STATUS.md](STATUS.md): **6. November 2026, 19:20 UTC**. Die Zahlen sind eine Momentaufnahme; aktuelle Lauf- und Quellenzahlen stehen in `STATUS.md`.

| Sprache | Aktive Dateien | Verzeichnis |
| --- | ---: | --- |
| JavaScript | 682 | `javascript/` |
| Perl 5 | 757 | `perl5/` |
| PowerShell | 729 | `powershell/` |
| Python | 706 | `python/` |
| Shell | 532 | `shell/` |
| Tcl | 790 | `tcl/` |
| **Gesamt** | **4196** | |

Bei einem früheren dokumentierten Lauf blieben die folgenden Job-Commits Teil der Historie: `f965cba` erzeugte
fünf High-Priority-Übersetzungen, `723dac3` erzeugte 184 Medium-Priority-
Übersetzungen und `14b5336` erzeugte 213 Low-Priority-Übersetzungen. Dieser frühere Lauf verwarf zusätzlich 27 nicht bestandene Ergebnisse.

## Vercel-Preview

Die [Gateway-1-Preview](https://openclaw-git-gateway1-abstractions-openclaw-vercel-project.vercel.app) zeigt den aktiven Bestand mit Sprachfilter, Dateisuche und Quelltextansicht. Die Dateien werden als Text angezeigt und nicht ausgeführt. Das historische Verzeichnis ist vom Katalog ausgeschlossen.

Der Build erfasst die sechs Sprachverzeichnisse und erzeugt `dist/catalog.json`. Neue Dateien erscheinen nach dem nächsten erfolgreichen Build. Der Katalog enthält den vollständigen Quelltext und wird beim Öffnen der Preview geladen; seine Größe kann die Ladezeit beeinflussen.

Lokaler Build mit installiertem Node.js und npm:

```sh
npm ci
npm run build
```

Das Ergebnis liegt in `dist/`. Die Versionen der npm-Abhängigkeiten sind in `package-lock.json` festgehalten.

## Veröffentlichung

Der aktive Manager schreibt in die sechs Sprachverzeichnisse, aktualisiert
`STATUS.md`, commitet angenommene Ergebnisse und veröffentlicht non-force nach
`gateway1-abstractions`. Ein separater Publisher ist nicht erforderlich.
