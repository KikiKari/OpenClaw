# Gateway 1 — Script Abstractions

Modellgenerierte und syntaktisch geprüfte Portierungen aus den konfigurierten
OpenClaw-, Projects- und Onboarding-Quellen. Der Abstraction Manager führt den
Bestand alle sechs Stunden fort und veröffentlicht direkt in diesem Branch.

## Aktueller Arbeitsstand

Die Tabelle wird aus den versionierten Dateien automatisch aktualisiert. Details zu den Läufen stehen in [STATUS.md](STATUS.md).

| Sprache | Aktive Dateien | Verzeichnis |
| --- | ---: | --- |
| JavaScript | 1847 | `javascript/` |
| Perl 5 | 2026 | `perl5/` |
| PowerShell | 1972 | `powershell/` |
| Python | 1960 | `python/` |
| Shell | 1374 | `shell/` |
| Tcl | 2182 | `tcl/` |
| Raku | 117 | `perl6/` |
| Ruby | 357 | `ruby/` |
| Lua | 353 | `lua/` |
| Go | 238 | `go/` |
| **Gesamt** | **12426** | |

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
