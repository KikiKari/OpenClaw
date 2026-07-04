# HEARTBEAT.md - Main-Checkliste

## Periodische Checks (alle 45min)

- Last run: 2026-07-01 22:04:52 UTC

## Execution Routing

- Der Sandbox-Workspace ist `/workspace`; niemals Hostpfade wie `/home/openclaw/.openclaw/workspace` innerhalb der Sandbox verwenden.
- Echte Linux-Hostdiagnosen über den gepaarten Host-Node mit `system.run` oder über einen ausdrücklich auf Gateway/Host gerichteten Exec ausführen.
- Niemals Sandbox-Prozess-, Systemd- oder Lastwerte als Hostwerte ausgeben.
- Pro Tool-Aufruf exakt einen Diagnosebefehl ausführen. Keine Verkettung mit `&&`, `||`, `;`, Pipes, Umleitungen, Subshells oder mehreren Zeilen.
- OpenClaw-Plattformzustand über die jeweiligen Tools prüfen: Cron für Jobs, Agents für Agents und Nodes mit `action: status` für Nodes.
- OpenClaw-CLI nicht in `host: sandbox` ausführen.

### System
- [ ] Host vmstat: einzelner Node-`system.run`- oder Gateway/Host-Exec-Aufruf mit `vmstat`
- [ ] Host Prozesse: einzelner Aufruf mit `ps aux`; Ausgabe anschließend modellseitig auf zehn Einträge begrenzen
- [ ] Host Disk: einzelner Aufruf mit `df -h`; Auslastung unter 80 % prüfen
- [ ] Host Memory: einzelner Aufruf mit `free -h`
- [ ] Host Load: einzelner Aufruf mit `uptime`
- [ ] Host Logs: einzelner Aufruf mit `journalctl -n 200 -q`
- [ ] Crons: Cron-Tool `action=list`
- [ ] Agents: Agents-Tool
- [ ] Nodes: Nodes-Tool `action=status`

### Cron-Jobs
- [ ] Alle Cron-Jobs auf `delivery.mode: none` prüfen
- [ ] Ergebnisse in `memory/` geschrieben?
- [ ] Kritische Probleme und offene Punkte an Agent `ops-hub` melden
- [ ] Nicht erfolgreiche Aktionen zurückstellen und an Agent `ops-hub` melden

## Bei Problemen
- API-, Gateway-, Memory-, Session- oder Agent-Probleme an Agent `ops-hub` melden.
- Keine Reparatur-, Cleanup- oder zusammengesetzten Shellbefehle aus dem Heartbeat starten.

## OpenClaw-Control-Rueckmeldung

- Fuer sichtbare Rueckmeldung in der Gateway-Control-UI niemals `channel=heartbeat` verwenden.
- Wenn eine Meldung aus einer isolierten oder Cron-Session an den Betreiber noetig ist und `sessions_send` verfuegbar ist: `sessions_send(sessionKey="agent:main:main", message="<kurzer Status>", timeoutSeconds=0)`.
- Keine `sessions_send`-Selbstsendung verwenden, wenn die aktuelle Session bereits `agent:main:main` ist; dann normale sichtbare Antwort bzw. targetless `message(action=send)` verwenden, falls sichtbare Ausgabe via Message-Tool verlangt wird.

## Abschluss

- Bei einem Problem ausschließlich einen kurzen Fehlerstatus als finale Antwort liefern.
- Wenn alle Prüfungen erfolgreich sind und keine Aktion erforderlich ist, als finale Antwort exakt und ausschließlich `HEARTBEAT_OK` liefern.
- `heartbeat_respond` ersetzt diese finale Textantwort nicht.
