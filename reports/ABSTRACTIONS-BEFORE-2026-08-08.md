# Abstraktionslauf: Vorher-Befund

**Erhoben:** 2026-08-08 (Europe/Berlin)  
**Betriebs-Repository:** `KikiKari/OpenClaw`, Branch `gateway2`  
**Betriebsstand:** `3ba11e5d2eeb1cc733f50186e6629ebaca308917`  
**Ausgabe-Branch:** `KikiKari/OpenClaw@gateway2-abstractions`  
**Ausgabestand:** `f870ec2665fe303d277a4bbb7283f1c799ae91e6`  
**Ausarbeitung:** `KikiKari/Projects@abstractions`  
**Ausarbeitungsstand:** `b6047087afab103effad517d599c5473c587b98f`

Dieser Bericht wurde nach einer ausschließlich lesenden Erhebung und vor der
Umstellung angelegt. Historische Backups, Sitzungsprotokolle, Cache-Dateien und
Abhängigkeiten unter `node_modules` wurden nicht als aktive Komponenten
gewertet.

## Ergebnis

Der bisherige Produktionspfad erzeugt keine Übersetzungen, sondern Rümpfe.
Von 125 Dateien im Ausgabe-Branch enthalten 122 eindeutige Stub-Merkmale
(`TODO: Implementiere`, `pass` oder gleichwertig); 95 Dateien außerhalb des
Python-Verzeichnisses enthalten allein schon `def main():`. Der gemeldete
Beleg ist reproduziert: `perl5/model_usage.pl` enthält Python-Syntax,
`def main():`, `if __name__ == "__main__":` und einen TODO-Block.

## Manager und Einstiegspunkte

| Bestandteil | Befund vor der Änderung |
|---|---|
| `ABSTRACTIONS_MANAGER.py` | Symlink auf den Skill-Einstieg; SHA-256 `1c3a0649…` |
| `skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py` | 464-Byte-Kompatibilitäts-Wrapper; ruft den separaten Vollmanager auf |
| `abstraction-manager/ABSTRACTIONS_MANAGER.py` | Alter Vollmanager, 27.653 Byte, SHA-256 `dbbbacb4…`; `_build_stub_content()` erzeugt sprachspezifische TODO-Rümpfe; kein Modellaufruf |
| `skills/script-abstractions-manager/scripts/abstractions_manager.py.legacy-20260526-211900` | Noch ein alter Stub-Manager mit TODO- und nicht implementiertem Remote-Dispatch |
| `skills/abstractions-utils/scripts/create_abstraction.py` | Manueller Stub-Erzeuger für zehn Sprachen; enthält für jede Sprache TODO-Rümpfe |

## Skills und Beiwerk

Aktiv beziehungsweise als aktiv dokumentiert sind:

- `skills/script-abstractions-manager/` mit Skill-Dokumentation, Wrapper,
  Legacy-Manager und Bytecode-Resten;
- `skills/abstractions-utils/` mit Skill-Dokumentation und dem manuellen
  Stub-Erzeuger;
- `abstraction-manager/` mit Vollmanager, Dokumentation, Review,
  `create_abstraction.py`, `spawn_agent.py`, `db_manager.py`,
  `json_processor.js`, `logger.py`, `validators.py`, `exceptions.py`,
  `initialize_repo.sh` und `python-hardener.skill`;
- `skills/sub-agents-utils/` und `skills/multi-nodes-utils/` werden in den
  alten Dokumenten als Mitarbeitende genannt. Der tatsächlich ausgeführte
  Vollmanager importiert oder startet sie jedoch nicht; der behauptete
  Multi-Node-/Sub-Agent-Pfad ist damit nur Dokumentation, kein Laufpfad.

Weitere widersprüchliche Arbeitsanweisungen liegen in `ABSTRACTIONS.md`,
`ABSTRACTIONS_MANAGER_SKILL.md`, `SCRIPT-ABSTRACTION-INSTRUCTIONS.md`,
`SCRIPT-ABSTRACTION-TASK.md`, `abstraktionen-task.md` und mehreren alten
Berichten. Sie verweisen teils auf andere Repositories, andere Einstiegspfade,
zehn statt sechs Zielsprachen oder nicht installierte Zeitpläne.

## Agents und Plugins

Auf dem Server existieren zehn Agent-Verzeichnisse und fünf lokale
Plugin-Verzeichnisse. Außerhalb historischer Sitzungen, temporärer
Codex-Verzeichnisse und Backups enthält keines davon einen aktiven Verweis auf
den Abstraktionslauf. In `openclaw.json` ist kein eigener Abstraktions-Agent
und kein Abstraktions-Plugin konfiguriert. Ein solcher Agent-/Plugin-Laufpfad
ist daher nicht vorhanden; gegenteilige Aussagen in alten Dokumenten sind
gegenstandslos.

## Konfiguration und Zustand

- `db/abstractions_state.json` ist der Zustand des alten Managers. Er meldet
  127 erzeugte „Abstraktionen“ und einen letzten Lauf am 2026-07-12, obwohl
  der Output nahezu vollständig aus Rümpfen besteht.
- `OPENROUTER_API_KEY` liegt in den vorhandenen, nicht versionierten Dateien
  `/home/openclaw/.openclaw/.env` und
  `/home/openclaw/.openclaw/gateway.systemd.env`. Beide haben Modus `0600`;
  der Schlüssel ist vorhanden, 73 Zeichen lang und hat das erwartete
  `sk-or-`-Präfix. Der Wert wurde nicht ausgegeben oder in diesen Bericht
  übernommen.
- Die zentrale OpenClaw-Konfiguration enthält keinen aktiven Manager-Eintrag.
- Das Betriebs-Repository war bei der Erhebung sauber. Das gesonderte lokale
  Ausgabe-Checkout `workspace/git/Abstraktionen` stand auf
  `d544c2f772c4a3be62c6c1828df6a016b83dddb2`, lag 135 Commits vor dem Remote
  und hatte eine geänderte `STATUS.md`. Dieser divergierte Bestand wurde vor
  dem Austausch vollständig samt `.git` gesichert.

## Zeitpläne und Publisher

Die tatsächlich installierte Linux-Benutzer-Crontab enthält keinen
Manager-Lauf. Sie enthält lediglich:

- den allgemeinen `git-publish-gateway` um 06:20 und 18:20 Uhr;
- `abstractions-publish-gateway-cron.sh` um 04:40, 13:40 und 22:40 Uhr.

Die Datei `crons/abstractions-manager.cron` und ältere Crontab-Dokumente
behaupten zusätzlich einen Lauf alle sechs Stunden; dieser Eintrag ist nicht
in der Linux-Crontab installiert.

### Nachtrag: OpenClaw-Scheduler

Die nach der dateibasierten Erhebung zusätzlich abgefragte aktuelle
OpenClaw-Scheduler-API zeigte einen aktiven Manager-Job mit der ID
`39368c42-8279-45d8-8fd8-14c8690593a9`. Er lief als Command-Job des Agents
`main` in einer isolierten Sitzung im Sechs-Stunden-Takt mit fünf Minuten
Streuung. Sein Befehl zeigte auf die Synchronisationskopie
`workspace/git/skills/script-abstractions-manager/scripts/ABSTRACTIONS_MANAGER.py`
und damit auf den alten Stub-Lauf. Der Jobdatensatz und die migrierten
Schedulerdateien wurden vor seiner Anpassung ebenfalls in den Sicherungsbereich
übernommen.

Der separate Publisher besteht aus:

- `/home/openclaw/.openclaw/scripts/abstractions-publish-gateway.sh`;
- `/home/openclaw/.openclaw/scripts/abstractions-publish-gateway-cron.sh`;
- dem Workspace-Wrapper `scripts/abstractions-publish-gateway.sh`;
- dem Logbereich `/home/openclaw/.openclaw/logs/abstractions-publish-gateway/`.

Die letzten dokumentierten Pushes am 2026-08-07 und 2026-08-08 wurden als
Nicht-Fast-Forward abgewiesen. Der Publisher setzte lokal bei jedem Lauf
weitere Commits auf einen divergierten Stand und löste den Konflikt nicht.

## Sicherungsziel für die Umstellung

Der auf diesem Server etablierte Backupbereich ist
`/home/openclaw/.openclaw/workspace/backups/`; die vorhandene Konvention
verwendet darin zeitgestempelte Unterverzeichnisse. Für die Umstellung wird
ein eigener, manifestierter Unterbereich angelegt. Er ist durch `.gitignore`
von der Versionierung ausgeschlossen. Dort werden der alte Manager samt
Beiwerk, Laufzustand, Zeitplan/Publisher und eine vollständige Kopie des
bisherigen Ausgabe-Branch-Bestands erhalten. Nichts davon bleibt anschließend
ein aktiver Laufpfad.
