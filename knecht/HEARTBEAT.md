# Keep this file empty (or with only comments) to skip heartbeat API calls.

# Add tasks below when you want the agent to check something periodically.

---
# HEARTBEAT.md - Recovery-Checkliste

## Periodische Checks (alle 55min)

### System
- [x] Disk: df -h (< 80%)
- [x] Memory: free -h
- [x] Load: uptime
- [x] System: vmstat
- [x] Prozesse: ps aux | head -n 20
- [x] Logs: journalctl -n 2000

### Cron-Jobs
- [x] Ergebnisse in memory/ Dateien geschrieben?
- [x] Alle kritischen Meldungen protokolliert?
- [x] Alle gemeldeten Probleme behoben?
- [x] Alle Behebungen an Agent ops-hub gemeldet?
- [x] Alle nicht behobenen Probleme und Meldungen protokolliert?
- [x] Alle kritischen Ereignisse protokolliert?
- [x] Alle offenen Punkte in den WebChat geschrieben?
- [x] Alle nicht erfolgreiche Aktionen zurückgestellt und an Agent ops-hub gemeldet?

## Execution Routing

- Run Linux host diagnostics (`vmstat`, `ps`, `df`, `free`, `uptime`, `journalctl`) with exec.
- Do not run `openclaw ...` commands in `host: sandbox`; the sandbox PATH may not contain the OpenClaw CLI.
- Prefer OpenClaw tools for platform state: Cron tool for crons, Agents tool for agents, Nodes tool with `action: status` for nodes.
- If an OpenClaw CLI command is still required, run it on the Gateway, or call `/home/openclaw/.npm-global/bin/openclaw ...`.
- Do not call `nodes` with `action: list`; valid node inventory comes from `nodes` `action: status` or `openclaw nodes status`.

## Bei Problemen
- API und Gateway immer Agent ops-hub informieren: Gateway exec `/home/openclaw/.npm-global/bin/openclaw doctor --yes`, `/home/openclaw/.npm-global/bin/openclaw status`, `/home/openclaw/.npm-global/bin/openclaw gateway status`, `/home/openclaw/.npm-global/bin/openclaw nodes status`.
- API und Gateway Wartung: Gateway exec `/home/openclaw/.npm-global/bin/openclaw doctor --force`.
- memory Wartung: Gateway exec `/home/openclaw/.npm-global/bin/openclaw memory index --force`.
- session Wartung: Gateway exec `/home/openclaw/.npm-global/bin/openclaw sessions cleanup --enforce`.
- agent Wartung: Gateway exec `/home/openclaw/.npm-global/bin/openclaw sessions cleanup --all-agents`.

## Abschluss & Stummschaltung
- Falls KEINE der oben genannten Bedingungen zutrifft:
- **Antworte ausschließlich mit dem Wort: HEARTBEAT_OK**
