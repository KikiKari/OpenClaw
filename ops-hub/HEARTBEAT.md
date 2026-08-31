# Keep this file empty (or with only comments) to skip heartbeat API calls.

# Add tasks below when you want the agent to check something periodically.

---
# HEARTBEAT.md - Recovery-Checkliste

## Periodische Checks (alle 50min)

## Execution Routing
- Run Linux host diagnostics (`vmstat`, `ps`, `df`, `free`, `uptime`, `journalctl`) with exec.
- Do not run `openclaw ...` commands in `host: sandbox`; the sandbox PATH may not contain the OpenClaw CLI.
- Prefer OpenClaw tools for platform state: Cron tool for crons, Agents tool for agents, Nodes tool with `action: status` for nodes.
- If an OpenClaw CLI command is still required, run it on the Gateway, or call `/home/openclaw/.npm-global/bin/openclaw ...`.
- Do not call `nodes` with `action: list`; valid node inventory comes from `nodes` `action: status` or `openclaw nodes status`.

### System
- [ ] System: vmstat
- [ ] Prozesse: ps aux | head -n 10
- [x] Disk: df -h (< 80%)
- [ ] Memory: free -h
- [ ] Load: uptime
- [ ] Logs: journalctl -n 1000 -q
- [ ] Crons: Cron tool action=list
- [x] Agents: Agents tool
- [ ] Tasks: Gateway exec `/home/openclaw/.npm-global/bin/openclaw tasks list` if needed
- [ ] Channels: Gateway exec `/home/openclaw/.npm-global/bin/openclaw channels list` if needed
- [x] Sessions: sessions_list tool or Gateway exec `/home/openclaw/.npm-global/bin/openclaw sessions` if needed
- [ ] Nodes: Nodes tool action=status only; do not call nodes action=list or `openclaw node list`

### Cron-Jobs
- [ ] Ergebnisse in memory/ Dateien geschrieben?
- [ ] Alle eingegangenen Agent Meldungen protokolliert?
- [ ] Alle kritischen Erreignisse protokolliert?
- [ ] Agent knecht über alle kritischen Meldungen informiert?
- [ ] Agent knecht alle kritische Probleme gemeldet?
- [ ] Agent knecht alle kritischen Ereignisse gemeldet?
- [ ] Alle offenen Punkte in den WebChat geschrieben?

## Bei Problemen
- API und Gateway immer Agent knecht informieren: openclaw doctor --yes && openclaw status && openclaw gateway status && openclaw nodes status
- API und Gateway Wartung: openclaw doctor --fix --yes
- memory Wartung: openclaw memory index --dry-run
- session Wartung: openclaw sessions cleanup --dry-run
- agent Wartung: openclaw sessions cleanup --all-agents --dry-run

## Abschluss & Stummschaltung
- Falls KEINE der oben genannten Bedingungen zutrifft und keine kritischen Issues bekannt sind:
- **Antworte ausschließlich mit dem Wort: HEARTBEAT_OK**