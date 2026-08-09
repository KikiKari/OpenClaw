# Abstraktionslauf: Umstellung und Produktionsnachweis

**Abgeschlossen:** 2026-08-08

**Betriebs-Branch:** `KikiKari/OpenClaw@gateway2`

**Ausgabe-Branch:** `KikiKari/OpenClaw@gateway2-abstractions`

## Veröffentlichung

| Branch | Commit | Inhalt |
|---|---|---|
| `gateway2` | ab `ba1c429`, fortgeschrieben | Stub-Manager und Altbeiwerk stillgelegt; neuer Manager, Skill, Wrapper, Zeitplan und Dokumentation aktiviert |
| `gateway2-abstractions` | `2d9cdac` | fortgeschriebener Arbeitsstand mit 407 Erzeugnissen und vollständig wieder angebundener vorheriger Historie |

Der Ausgabe-Branch steht bei der Abschlussprüfung auf seinem Remote-Kopf. Sein
erster Elternverlauf enthält den vollständigen zugrunde liegenden `main`-Baum;
sein zweiter Elternverlauf bindet den gesicherten Ausgabe-Stand `0b4e65f` ein.

## Übernommener Manager

Quelle ist
`KikiKari/Projects@abstractions:abstractions/ABSTRACTIONS_MANAGER.py` auf
Commit `b6047087afab103effad517d599c5473c587b98f`.

Im Manager wurde ausschließlich `veroeffentlichen()` von
`KikiKari/Projects@abstractions` auf
`KikiKari/OpenClaw@gateway2-abstractions` umgestellt. Der interne
Ausgabepfad bleibt neutral `workspace/git/Abstraktionen/`; die lokale
Quellenablage bleibt unverändert `workspace/git/quellen/`.
`GITHUB_BENUTZER`, `QUELLEN`, Modellkette und die übrige Programmlogik sind
unverändert.

## Sicherung und Stilllegung

Der vollständige Altbestand liegt unter:

`/home/openclaw/.openclaw/workspace/backups/abstractions-replacement-20260808T204155+0200/`

Gesichert sind insbesondere:

- alter Vollmanager, Wrapper, Skills, Helfer und alte Dokumentation;
- alte Zustände, Manager-/Publisher-Logs und Schedulerdateien;
- der Remote-Ausgabestand `f870ec2` als vollständiges Checkout;
- das alte lokale Ausgabe-Checkout auf `d544c2f` einschließlich seiner 152
  lokalen Commits und der uncommittierten `STATUS.md`;
- der alte separate Publisher und seine Laufzeit-Wrapper.

Commit `352c082` verband den lokalen Verlauf mit der damaligen Ausgabe durch
die Strategie `ours`; sein Baum blieb deshalb leer und übernahm keinen Inhalt
des zweiten Elternverlaufs. Das anschließende Umschreiben auf `62abde7` trennte
den gesamten Stand `0b4e65f` mit 156 Commits vollständig vom aktiven Branch.
Diese beiden Eingriffe waren keine Fortschreibung des vorgefundenen Zustands.

Der Verlauf blieb im verifizierten Git-Bundle
`output-public-history-before-correction.bundle` und im Checkout
`output-checkout-before-public-history-correction/` erhalten. Der echte
Merge-Commit `2d9cdac` hat `3c60673` und `0b4e65f` als Eltern. Damit sind alle
156 zuvor abgetrennten Commits wieder über `gateway2-abstractions` erreichbar;
es gibt keinen Commit aus `0b4e65f`, der von `2d9cdac` aus unerreichbar ist.

Im gesicherten Checkout lagen neun noch nicht committed Modell-Erzeugnisse,
nicht acht: sechs Übersetzungen der Quelle
`Projects@secret-vault-public:secret-vault-public/versions/1781743218784.html`
und drei Übersetzungen der Quelle
`Projects@MCP-Server-Monitor:public/3d.html`. Alle neun bestanden die jeweilige
Syntaxprüfung. Sie sind jetzt unter den vom Manager vorgesehenen
Quellhash-Suffixen `2a8278` und `1af353` veröffentlicht, ohne gleichnamige
vorhandene Erzeugnisse zu überschreiben.

Der aktuelle Baum enthält den vollständigen zugrunde liegenden `main`-Stand
und zusätzlich `STATUS.md` sowie 407 Erzeugnisse. Gegenüber dem ersten Elternteil
von `2d9cdac` wurden neun Dateien hinzugefügt und `STATUS.md` fortgeschrieben;
es wurde keine Datei gelöscht und die README blieb bytegleich.

## Nachprüfung des Betriebs-Branches

Zwischen dem unmittelbar vor der Umstellung vorgefundenen Commit `3ba11e5`
und dem dokumentierten Betriebsstand wurden 24 Pfade aus dem aktiven Git-Baum
entfernt. Davon sind 22 reguläre Dateien bytegenau im Workspace-Snapshot
gesichert; die beiden weiteren Pfade waren symbolische Links und sind mit ihren
ursprünglichen Linkzielen ebenfalls im Snapshot sowie im Bereich
`retired-active-paths/` erhalten. Keine neue Nullbyte-Datei wurde erzeugt. Die
fünf bereits vorher vorhandenen Nullbyte-Dateien sind in beiden Ständen
identisch.

Die stärkste Verkürzung einer weiter aktiven Datei betrifft
`skills/script-abstractions-manager/SKILL.md` von 4.900 auf 1.185 Byte. Die
vollständige vorherige Fassung ist bytegenau im Workspace-Snapshot erhalten.
Die entfernten Pfade und diese Skill-Änderung bleiben damit wiederherstellbar;
sie wurden bei dieser Historienreparatur nicht eigenmächtig zurückgespielt.

## Laufzeit

- OpenClaw-Scheduler-Job:
  `39368c42-8279-45d8-8fd8-14c8690593a9`;
- Takt: alle sechs Stunden, fünf Minuten Streuung;
- Agent: `main`, isolierter Command-Job;
- Befehl:
  `/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh`;
- der frühere separate Publisher-Cron ist entfernt;
- die Linux-Benutzer-Crontab startet keinen zusätzlichen Manager.

Nach einem abgebrochenen Mehrdateienlauf am 2026-08-09 wurde der
nicht versionierte Laufzeit-Wrapper so begrenzt, dass ein argumentloser
Scheduler-Aufruf genau eine Quelldatei verarbeitet. Damit kann der Manager die
vollständige Sprachgruppe committen und veröffentlichen, bevor das Zeitfenster
des isolierten Jobs endet. Manuelle Aufrufe mit expliziten Argumenten bleiben
unverändert.

Der dabei gesicherte uncommittierte Arbeitsstand ist inzwischen vollständig
unter kollisionsfreien Namen in `2d9cdac` übernommen.

Der Wrapper liest `OPENROUTER_API_KEY` aus der vorhandenen, nicht
versionierten Serverablage und exportiert ihn nur in den Managerprozess. Der
Schlüsselwert wurde weder ausgegeben noch versioniert.

## Produktionsnachweis

Der echte Lauf erfasste 19 Arbeitsbäume und 752 eindeutige Quelldateien aus
1.039 Fundstellen. Für die erste mittelpriore Quelle
`1781743218784.js` wurden erzeugt:

| Zielsprache | Datei | Prüfung |
|---|---|---|
| Perl 5 | `perl5/1781743218784.pl` | `perl -c` erfolgreich |
| PowerShell | `powershell/1781743218784.ps1` | `pwsh`-`ScriptBlock`-Kompilierung erfolgreich |
| Python | `python/1781743218784.py` | Python-Kompilierung erfolgreich |
| Bash | `shell/1781743218784.sh` | `bash -n` erfolgreich |
| Tcl | `tcl/1781743218784.tcl` | Vollständigkeits-/Syntaxprüfung erfolgreich |

Die fünf Dateien enthalten zusammen 1.217 Zeilen. Der Scan auf die bekannten
Stub-Muster, TODO-Platzhalter und fremde Python-Einstiegssyntax außerhalb des
Python-Ziels war sauber. Der erzeugte Commit enthielt keine Treffer der
konfigurierten Secret-Muster.

Für die PowerShell-Prüfung wurde die offizielle Linux-ARM64-Ausgabe von
PowerShell 7.6.4 benutzerlokal unter
`/home/openclaw/.local/share/powershell/7.6.4/` installiert und über
`/home/openclaw/.local/bin/pwsh` erreichbar gemacht. Archiv-Digest,
GitHub-API-Digest und die veröffentlichte `hashes.sha256` stimmen überein.
