# Gateway 1 — Script Abstractions

Modellgenerierte und syntaktisch geprüfte Portierungen aus den konfigurierten
OpenClaw-, Projects- und Onboarding-Quellen. Der Abstraction Manager führt den
Bestand alle sechs Stunden fort und veröffentlicht direkt in diesem Branch.

## Aktueller Arbeitsstand

Die Tabelle wird aus den versionierten Dateien automatisch aktualisiert. Details zu den Läufen stehen in [STATUS.md](STATUS.md).

| Sprache | Aktive Dateien | Verzeichnis |
| --- | ---: | --- |
| JavaScript | 1816 | `javascript/` |
| Perl 5 | 2002 | `perl5/` |
| PowerShell | 1945 | `powershell/` |
| Python | 1927 | `python/` |
| Shell | 1359 | `shell/` |
| Tcl | 2148 | `tcl/` |
| Raku | 107 | `perl6/` |
| Ruby | 317 | `ruby/` |
| Lua | 314 | `lua/` |
| Go | 232 | `go/` |
| **Gesamt** | **12167** | |

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
