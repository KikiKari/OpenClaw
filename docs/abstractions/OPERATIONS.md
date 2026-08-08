# Abstraktionslauf auf gateway1

## Aktiver Aufbau

- Manager: `skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py`
- Wrapper: `/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh`
- Ausgabe: `git/OpenClaw-gateway1-abstractions`, Branch `gateway1-abstractions`
- Zustand: `db/abstractions_state.json`
- Protokoll: `logs/abstractions-manager/manager.log`
- Zeitplan: OpenClaw-Command-Job alle sechs Stunden; Standardkontingent 40 Quelldateien
- Eigener Agent oder Plugin: nicht vorhanden

Der Manager liest die unveraenderte Quellenliste aus `KikiKari/OpenClaw`,
`KikiKari/Projects` und `KikiKari/Onboarding`. Schreibzugriffe gehen nur an
`KikiKari/OpenClaw@gateway1-abstractions`.

## Verarbeitung

Quellcode wird nach Inhalt dedupliziert und nach `high`, `medium` oder `low`
priorisiert. Jede Quelle wird ueber die unveraenderte Modellkette nach
JavaScript, Perl 5, PowerShell, Python, Bash und Tcl portiert; die bereits
vorliegende Quellsprache wird ausgelassen. Platzhalter, auffaellig kurze
Ergebnisse und erkennbare Syntaxfehler werden verworfen.

Der State verwendet `erledigt`, `statistik` und `naechste_prioritaet`. Der alte
State mit `processed`, `queue`, `current_priority` und `stats` ist inkompatibel
und stillgelegt.

## Betrieb

```bash
# Inventar und Ablauf ohne Modellaufruf pruefen
/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh \
  --prioritaet high --anzahl 1 --probelauf

# Kontrollierten Live-Lauf starten
/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh \
  --prioritaet high --anzahl 1

# Live-Job und Stilllegung des alten Publishers pruefen
openclaw cron list --json
```

Der Wrapper laedt Secrets aus `/home/openclaw/.openclaw/.env`, bildet fuer den
Prozess `GITHUB_TOKEN` aus dem vorhandenen GitHub-Token und verhindert parallele
Laeufe mit `flock`. Secretwerte duerfen weder geloggt noch versioniert werden.

## Stillgelegt und gesichert

Der alte Multi-Node-Manager, Stub-Generator, `abstractions-utils`, beide alten
Skill-Repositories, Publisher-Skripte, Publisher-Zeitplaene, alte Reports,
Logs, State und der komplette Rumpf-Ausgabecheckout werden nicht mehr genutzt.
Sie liegen unter:

`workspace/backups/abstractions-migration-20260808T183831Z/`

`BEFUND_VOR_UMSTELLUNG.md` dokumentiert den Zustand vor der ersten Aenderung.
`MANIFEST.sha256` und die Git-Bundles dienen der Integritaetspruefung und
Wiederherstellung.

## Abnahme 2026-08-08

- Vollstaendiger Probelauf: 19 Arbeitsbaeume, 764 eindeutige Quelldateien,
  120 High-Priority-Quellen nach Aktualisierung von `gateway1`.
- Live-Nachweis: eine Python-Quelle, fuenf angenommene Uebersetzungen, null
  verworfene Ergebnisse.
- Syntax lokal bestaetigt fuer JavaScript, Perl 5, Bash und Tcl; PowerShell
  wurde wegen fehlendem `pwsh` gemaess Managerregel angenommen.
- Ausgabe-Commits: `ba5fc2b` entfernt den gesicherten Rumpfbestand;
  `f965cba` enthaelt die ersten modellgenerierten Uebersetzungen.
- Betriebs-Commit: `a7b278a` ersetzt und dokumentiert den alten Workflow auf
  `gateway1`.

## Fehlerbehandlung

- Ohne `OPENROUTER_API_KEY` beendet sich ein Live-Lauf mit Exit-Code 2.
- Ohne erreichbare Quellen oder Inventar endet er mit Exit-Code 1.
- Fehlende Zielinterpreter werden protokolliert; auf diesem Server fehlt `pwsh`.
- Fehlgeschlagene Modellantworten werden verworfen und nicht als erledigt markiert.
- Der erste blob-gefilterte Checkout grosser Quellen kann das feste Git-Limit
  erreichen. Nach Sicherung eines verwaisten `index.lock` denselben Lauf erneut
  starten; bereits geladene Blobs bleiben im lokalen Mirror erhalten.
- Der separate Publisher bleibt deaktiviert, da der Manager selbst committen und
  nach `gateway1-abstractions` pushen kann.
