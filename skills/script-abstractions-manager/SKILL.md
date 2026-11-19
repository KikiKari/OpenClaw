---
name: script-abstractions-manager
description: Port source files from the configured KikiKari repositories into ten model-generated language implementations. Use for operating, diagnosing, dry-running, or documenting the scheduled OpenClaw abstraction workflow and its gateway1-abstractions output branch.
---

# Script Abstractions Manager

Run the bundled manager as the single implementation of this workflow:

```bash
/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh --prioritaet high --anzahl 1 --probelauf
```

- Keep `QUELLEN`, `MODELLE`, prompts, and CLI behavior unchanged. Results whose
  configured syntax check cannot complete are not accepted as validated.
- The gateway manager sends complete per-language jobs through the authenticated
  `abstractions-transport` plugin to available paired nodes. The existing
  Gateway wrapper is the entry point for its six-hour schedule.
- Node 5 is eligible through its specifically mapped Windows plugin host after
  the 2026-11-17 compatibility test. Retain the existing heavy-job priority.
  After a connection loss, query the same attempt; do not automatically
  resubmit an attempt with an unknown outcome.
- `ABSTRACTIONS_EXECUTION=standalone` runs translations locally without a
  Gateway connection. Each accepted artifact is queued in the existing state
  and published separately to `OpenClaw@gateway1-abstractions`; publication
  can be retried with `--nur-veroeffentlichen`.
- Read `OPENROUTER_API_KEY` from the server environment; never print or version it.
- Write only to the checkout `workspace/git/OpenClaw-gateway1-abstractions` on branch `gateway1-abstractions`.
- Use `--probelauf` to refresh the inventory without model requests.
- Gateway inventory includes eligible workspace files recursively as well as
  configured repository sources. Exclude `work` and `backups` at every level;
  existing sensitive-data, state, dependency and output exclusions apply.
  Files over 200,000 bytes remain in inventory but are not sent.
- Use `--prioritaet high|medium|low|alle` and `--anzahl N` to bound a live run.
- Treat rejected placeholder output as a failed translation, not as a usable artifact.
- Read `workspace/docs/abstractions/OPERATIONS.md` for scheduling, source scope, and publication details.

## Zusammengeführter Katalog auf Vercel

Der zusammengeführte Bestand aus `Projects@abstractions` und `OpenClaw@gateway1-abstractions` ist unter [abstractions-two.vercel.app](https://abstractions-two.vercel.app/) veröffentlicht. Das Vercel-Projekt `abstractions` verwendet `KikiKari/OpenClaw` und den Produktionsbranch `gateway1-abstractions`. Das Produktionsdeployment des Commits [`917ebb8`](https://github.com/KikiKari/OpenClaw/commit/917ebb8649543ac7e40df0448fba39d9c149cb21) wurde als READY und der Domain zugeordnet bestätigt; die [3D-Architektur](https://abstractions-two.vercel.app/3d.html) ist Teil des Deployments. Der Katalog umfasste bei diesem Stand 9.474 Dateien in zehn Sprachverzeichnissen. Der Abgleich erhielt alle Inhalte des Projects-Bestands: 132 zusätzliche Pfade und 39 abweichende Varianten wurden übernommen, 5.099 Dateien waren bytegleich. Diese Zahlen sind eine Momentaufnahme.

Die Umstellung belegt weder einen neuen Managerlauf noch die fachliche Prüfung aller Übersetzungen. Die automatische Domainzuweisung ist aktiviert; die Vercel-Projekteinstellung weist `KikiKari/OpenClaw` und `gateway1-abstractions` als Git-Quelle und Produktionsbranch aus.

## Betriebsstand 19.11.2026

Node 1 gibt nach beendetem Worker mit `unknown` dessen Ausführungsplatz frei; der Versuch bleibt abfragbar und wird nicht automatisch neu versendet. Einzelheiten zu Prüfungen, Sicherungen und dem noch nicht installierten Actions-Entwurf stehen in `/home/openclaw/.openclaw/workspace/docs/abstractions/OPERATIONS.md`.
