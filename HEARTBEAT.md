# HEARTBEAT.md - Main-Checkliste

## Periodische Checks (alle 45min)

- Last run: 2026-07-01 22:04:52 UTC

## Execution Routing

- Run Linux host diagnostics (`vmstat`, `ps`, `df`, `free`, `uptime`, `journalctl`) with exec.
- Do not run `openclaw ...` commands in `host: sandbox`; the sandbox PATH may not contain the OpenClaw CLI.
- Prefer OpenClaw tools for platform state: Cron tool for crons, Agents tool for agents, Nodes tool with `action: status` for nodes.
- If an OpenClaw CLI command is still required, run it on the Gateway, or call `/home/openclaw/.npm-global/bin/openclaw ...`.
- Do not call `nodes` with `action: list`; valid node inventory comes from `nodes` `action: status` or `openclaw nodes status`.

### System
- [x] System: vmstat
- [x] Prozesse: ps aux | head -n 10
- [x] Disk: df -h (< 80%)
- [x] Memory: free -h
- [x] Load: uptime
- [x] Logs: journalctl -n 200 -q
- [x] Crons: Cron tool action=list
- [x] Agents: Agents tool
- [x] Tasks: Gateway exec `/home/openclaw/.npm-global/bin/openclaw tasks list` if needed
- [x] Channels: Gateway exec `/home/openclaw/.npm-global/bin/openclaw channels list` if needed
- [x] Sessions: sessions_list tool or Gateway exec `/home/openclaw/.npm-global/bin/openclaw sessions` if needed
- [x] Nodes: Nodes tool action=status only; do not call nodes action=list or `openclaw node list`


### Cron-Jobs
- [x] Alle Cron-Jobs auf delivery.mode: none prüfen
- [x] Ergebnisse in memory/ Dateien geschrieben?
- [x] Alle eingegangenen Agent Meldungen an Agent ops-hub übermittelt?
- [x] Alle kritischen Probleme an Agent ops-hub gemeldet?
- [x] Alle kritischen Ereignisse protokolliert?
- [x] Alle offenen Punkte an Agent ops-hub gemeldet?
- [x] Alle nicht erfolgreiche Aktionen zurückgestellt und an Agent ops-hub gemeldet?

## Bei Problemen
- API und Gateway immer Agent ops-hub informieren: Gateway exec `/home/openclaw/.npm-global/bin/openclaw doctor --yes`, `/home/openclaw/.npm-global/bin/openclaw status`, `/home/openclaw/.npm-global/bin/openclaw gateway status`.
- API und Gateway Wartung: Gateway exec `/home/openclaw/.npm-global/bin/openclaw doctor --fix`.
- memory Wartung: Gateway exec `/home/openclaw/.npm-global/bin/openclaw memory index --dry-run`.
- session Wartung: Gateway exec `/home/openclaw/.npm-global/bin/openclaw sessions cleanup --dry-run`.
- agent Wartung: Gateway exec `/home/openclaw/.npm-global/bin/openclaw sessions cleanup --all-agents --dry-run`.

## OpenClaw-Control-Rueckmeldung
- Fuer sichtbare Rueckmeldung in der Gateway-Control-UI niemals `channel=heartbeat` verwenden.
- Wenn eine Meldung aus einer isolierten oder Cron-Session an den Betreiber noetig ist und `sessions_send` verfuegbar ist: `sessions_send(sessionKey="agent:main:main", message="<kurzer Status>", timeoutSeconds=0)`.
- Keine `sessions_send`-Selbstsendung verwenden, wenn die aktuelle Session bereits `agent:main:main` ist; dann normale sichtbare Antwort bzw. targetless `message(action=send)` verwenden, falls sichtbare Ausgabe via Message-Tool verlangt wird.

- [x] Pending script: /home/openclaw/.openclaw/scripts/abstractions-publish-gateway.sh (completed)

## Abschluss & Stummschaltung
- Falls KEINE der oben genannten Bedingungen zutrifft und keine kritischen Issues aufgetreten sind:
- **Antworte ausschließlich mit dem Wort: HEARTBEAT_OK**
