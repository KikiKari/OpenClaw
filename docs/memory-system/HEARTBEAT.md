# HEARTBEAT.md - Memory-Checkliste

## Periodische Checks (alle 180min)

### System
- [x] System: vmstat

### Cron-Jobs
- [ ] Alle Cron-Jobs auf delivery.mode: none prüfen
- [x] Ergebnisse in memory/ Dateien geschrieben?
- [x] Alle kritischen Probleme an Agent ops-hub gemeldet?
- [x] Alle kritischen Ereignisse an Agent ops-hub gemeldet?
- [x] Alle offenen Punkte an Agent ops-hub gemeldet?

## Execution Routing

- Run Linux host diagnostics (`vmstat`, `ps`, `df`, `free`, `uptime`, `journalctl`) with exec.
- Do not run `openclaw ...` commands in `host: sandbox`; the sandbox PATH may not contain the OpenClaw CLI.
- Prefer OpenClaw tools for platform state: Cron tool for crons, Agents tool for agents, Nodes tool with `action: status` for nodes.
- If an OpenClaw CLI command is still required, run it on the Gateway, or call `/home/openclaw/.npm-global/bin/openclaw ...`.
- Do not call `nodes` with `action: list`; valid node inventory comes from `nodes` `action: status` or `openclaw nodes status`.

## Bei Problemen
- API und Gateway immer Agent ops-hub informieren: Gateway exec `/home/openclaw/.npm-global/bin/openclaw status`, `/home/openclaw/.npm-global/bin/openclaw gateway status`, `/home/openclaw/.npm-global/bin/openclaw nodes status`.
- API und Gateway Wartung: Gateway exec `/home/openclaw/.npm-global/bin/openclaw doctor --yes`.
- memory Wartung: Gateway exec `/home/openclaw/.npm-global/bin/openclaw memory index --dry-run`.
- session Wartung: Gateway exec `/home/openclaw/.npm-global/bin/openclaw sessions cleanup --dry-run`.
- agent Wartung: Gateway exec `/home/openclaw/.npm-global/bin/openclaw sessions cleanup --all-agents --dry-run`.

## Abschluss & Stummschaltung
- Falls KEINE der oben genannten Bedingungen zutrifft:
- **Antworte ausschließlich mit dem Wort: HEARTBEAT_OK**
