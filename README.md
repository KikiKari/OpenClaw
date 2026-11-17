# Gateway 1 — Script Abstractions

Modellgenerierte und syntaktisch geprüfte Portierungen aus den konfigurierten
OpenClaw-, Projects- und Onboarding-Quellen. Der Abstraction Manager führt den
Bestand alle sechs Stunden fort und veröffentlicht direkt in diesem Branch.

## Aktueller Arbeitsstand

Die Tabelle wird aus den versionierten Dateien automatisch aktualisiert. Details zu den Läufen stehen in [STATUS.md](STATUS.md).

| Sprache | Aktive Dateien | Verzeichnis |
| --- | ---: | --- |
| JavaScript | 1548 | `javascript/` |
| Perl 5 | 1745 | `perl5/` |
| PowerShell | 1659 | `powershell/` |
| Python | 1627 | `python/` |
| Shell | 1193 | `shell/` |
| Tcl | 1825 | `tcl/` |
| Raku | 12 | `perl6/` |
| Ruby | 91 | `ruby/` |
| Lua | 79 | `lua/` |
| Go | 86 | `go/` |
| **Gesamt** | **9865** | |

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
