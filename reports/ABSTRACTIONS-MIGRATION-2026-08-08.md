# Abstraktionslauf: Umstellung und Produktionsnachweis

**Abgeschlossen:** 2026-08-08

**Betriebs-Branch:** `KikiKari/OpenClaw@gateway2`

**Ausgabe-Branch:** `KikiKari/OpenClaw@gateway2-abstractions`

## Veröffentlichung

| Branch | Commit | Inhalt |
|---|---|---|
| `gateway2` | `ba1c429` | Stub-Manager und Altbeiwerk stillgelegt; neuer Manager, Skill, Wrapper, Zeitplan und Dokumentation aktiviert |
| `gateway2-abstractions` | `62abde7` | bereinigter, vollständiger Ausgabe-Snapshot mit bytegleichem Baum des ersten echten Laufs |

Der Ausgabe-Branch steht bei der Abschlussprüfung auf seinem Remote-Kopf und
gegenüber `main` bei einem Commit voraus und keinem Commit zurück.

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
- das alte lokale Ausgabe-Checkout auf `d544c2f` einschließlich seiner 135
  lokalen Commits und der uncommittierten `STATUS.md`;
- der alte separate Publisher und seine Laufzeit-Wrapper.

Die 135 lokalen Commits wurden zunächst irrtümlich über `352c082` in die
veröffentlichte Ausgabehistorie aufgenommen. Dadurch zeigte GitHub den
Ausgabe-Branch öffentlich als 156 Commits vor und 267 Commits hinter `main`.
Diese falsche Historienverknüpfung wurde am 2026-08-09 mit ausdrücklicher
Freigabe und `--force-with-lease` entfernt. Der damalige Branchkopf `0b4e65f`
ist vollständig im verifizierten Git-Bundle
`output-public-history-before-correction.bundle` gesichert. Das komplette
Checkout einschließlich acht uncommittierter Dateien eines abgebrochenen
Scheduler-Laufs liegt zusätzlich unter
`output-checkout-before-public-history-correction/`.

Der korrigierte Commit `62abde7` hat `main` als Elterncommit und exakt denselben
Tree-Hash `07978a0f29f8d2471e473c4fe656827be8fb93ad` wie `0b4e65f`. Damit blieb der
veröffentlichte Ausgabebaum bytegleich, während die stillgelegte Althistorie
nicht länger über den aktiven Ausgabe-Branch erreichbar ist.

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
