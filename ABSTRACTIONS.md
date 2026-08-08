# Abstraktionslauf

## Gültiger Laufweg

Der kanonische Manager liegt unter:

`/home/openclaw/.openclaw/workspace/abstractions/ABSTRACTIONS_MANAGER.py`

Er ist aus `KikiKari/Projects@abstractions` übernommen. Im Manager selbst ist
nur `veroeffentlichen()` auf `KikiKari/OpenClaw@gateway2-abstractions`
angepasst. `ABSTRACTIONS_REPO` bleibt der neutrale lokale Pfad
`workspace/git/Abstraktionen/`; dessen Checkout steht auf dem Ausgabe-Branch.
`GITHUB_BENUTZER`, `QUELLEN`, Modellkette, Prüfung und Übersetzungslogik sind
unverändert.

Der Betriebsstand wird ausschließlich auf `OpenClaw@gateway2` gepflegt. Die
Erzeugnisse werden ausschließlich auf `OpenClaw@gateway2-abstractions`
veröffentlicht.

## Verhalten

Jede Quelldatei wird vollständig an OpenRouter gesendet und in die jeweils
anderen der sechs Zielsprachen übersetzt:

- JavaScript;
- Perl 5;
- PowerShell 7;
- Python 3.12;
- Bash 5;
- Tcl 8.6.

Die unveränderte Quellenliste umfasst `KikiKari/OpenClaw`,
`KikiKari/Projects` und `KikiKari/Onboarding` mit den im Manager festgelegten
Branches. Inhaltsgleiche Quellen werden per SHA-256 zusammengeführt.

Erzeugnisse mit TODO-/Platzhalter-Merkmalen, auffällig geringer Länge oder
ungültiger Syntax werden verworfen. Es gibt keinen Stub-Fallback.

## Modellkette

Die Modellkette der Ausarbeitung bleibt in dieser Reihenfolge erhalten:

1. `qwen/qwen3-coder`
2. `deepseek/deepseek-chat-v3.1`
3. `z-ai/glm-4.6`
4. `mistralai/codestral-2508`
5. `qwen/qwen-2.5-coder-32b-instruct`

## Laufzeit und Secrets

Der nicht versionierte Laufzeit-Wrapper
`/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh` liest
`OPENROUTER_API_KEY` aus der vorhandenen Serverablage
`/home/openclaw/.openclaw/.env` und exportiert ihn nur in den Prozess des
Managers. Für die Veröffentlichung wird ein vorhandener GitHub-Token unter
dem vom Manager erwarteten Namen in die Prozessumgebung abgebildet. Kein
Schlüsselwert liegt in einer versionierten Datei.

Manueller Lauf:

```bash
/home/openclaw/.openclaw/workspace/scripts/abstractions-manager.sh --prioritaet high
```

Inventar-Probelauf ohne Modellaufruf:

```bash
/home/openclaw/.openclaw/workspace/scripts/abstractions-manager.sh \
  --prioritaet high --anzahl 1 --probelauf
```

## Ablagen

| Zweck | Pfad |
|---|---|
| Ausgabe-Checkout | `workspace/git/Abstraktionen/` |
| Quellspiegel und Arbeitsbäume | `workspace/git/quellen/` |
| Zustand | `workspace/db/abstractions_state.json` |
| Manager-Log | `workspace/logs/abstractions-manager/manager.log` |
| Vorher-Befund | `reports/ABSTRACTIONS-BEFORE-2026-08-08.md` |
| Sicherung | `workspace/backups/abstractions-replacement-20260808T204155+0200/` |

## Zeitplan

Der Manager läuft alle sechs Stunden über den Laufzeit-Wrapper. Der frühere
separate Publisher ist stillgelegt, weil der neue Manager Commit und Push nach
erfolgreichen Übersetzungen selbst ausführt.

Aktiver OpenClaw-Scheduler-Job:
`39368c42-8279-45d8-8fd8-14c8690593a9` (`main`, isolierter Command-Job,
fünf Minuten Streuung). Der Manager wird nicht zusätzlich über die
Linux-Benutzer-Crontab gestartet.

```cron
0 */6 * * * /home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh
```

## Stillgelegter Altbestand

Der alte Stub-Manager, seine Skills und Helfer, alte Zustände und Logs, der
separate Publisher sowie der vollständige bisherige Ausgabe-Branch liegen im
oben genannten Backupbereich. Sie sind keine Laufzeitabhängigkeiten mehr.
Details stehen in `ABSTRACTIONS-RETIRED.md` und im Sicherungsmanifest.

## Erster Produktionslauf

Der erste echte Lauf des neuen Managers am 2026-08-08 bearbeitete eine
mittelpriore JavaScript-Quelle und erzeugte fünf vollständige Übersetzungen.
Alle fünf Ziele bestanden die lokale Syntaxprüfung. PowerShell wurde nach der
benutzerlokalen Installation von PowerShell 7.6.4 mit derselben
`ScriptBlock`-Kompilierung geprüft, die der Manager verwendet. Es wurden keine
Ergebnisse verworfen und keine TODO-/Platzhalter-Muster abgelegt.

Ausgabe-Commit: `0b4e65f` auf `gateway2-abstractions`.
