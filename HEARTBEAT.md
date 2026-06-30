# HEARTBEAT.md - Main-Checkliste

## Periodische Checks (alle 45min)

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
- API und Gateway immer Agent ops-hub informieren: openclaw doctor --yes && openclaw status && openclaw gateway status && openclaw nodes status
- API und Gateway Wartung: openclaw doctor --fix
- memory Wartung: openclaw memory index --dry-run
- session Wartung: openclaw sessions cleanup --dry-run
- agent Wartung: openclaw sessions cleanup --all-agents --dry-run

## Abschluss & Stummschaltung
- Fuer Control-UI-Rueckmeldung Status/Heartbeat zusaetzlich via `sessions_send`
  an `sessionKey="agent:main:main"` mit `timeoutSeconds=0` spiegeln.
  Provider-Delivery bleibt Slack; `message` nicht fuer Control-UI verwenden.
- Falls KEINE der oben genannten Bedingungen zutrifft und keine kritischen Issues aufgetreten sind:
- **Antworte ausschließlich mit dem Wort: HEARTBEAT_OK**
