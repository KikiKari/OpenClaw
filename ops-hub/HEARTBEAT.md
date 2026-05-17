```markdown
# Keep this file empty (or with only comments) to skip heartbeat API calls.

# Add tasks below when you want the agent to check something periodically.
```

---
# HEARTBEAT.md - Recovery-Checkliste

## Periodische Checks (alle 50min)

### System
- [x] System: vmstat
- [x] Prozesse: ps aux | head -n 10
- [ ] Disk: df -h (< 80%)
- [ ] Memory: free -h
- [ ] Load: uptime
- [x] Logs: journalctl -n 1000 -q
- [x] Crons: openclaw cron list
- [x] Agents: openclaw agents list
- [x] Tasks: openclaw tasks list
- [x] Channels: openclaw channels list
- [x] Sessions: openclaw sessions
- [x] Nodes: openclaw nodes status && openclaw node list

### Cron-Jobs
- [x] Ergebnisse in memory/ Dateien geschrieben?
- [x] Alle eingegangenen Agent Meldungen protokolliert?
- [x] Alle kritischen Erreignisse protokolliert?
- [x] Agent knecht über alle kritischen Meldungen informiert?
- [x] Agent knecht alle kritische Probleme gemeldet?
- [x] Agent knecht alle kritischen Ereignisse gemeldet?
- [x] Alle offenen Punkte in den WebChat geschrieben?

## Bei Problemen
- API und Gateway immer Agent knecht informieren: openclaw doctor --yes && openclaw status && openclaw gateway status && openclaw nodes status && openclaw node list
- API und Gateway Wartung: openclaw doctor --fix --yes
- memory Wartung: openclaw memory index --dry-run
- session Wartung: openclaw sessions cleanup --dry-run
- agent Wartung: openclaw sessions cleanup --all-agents --dry-run

## Abschluss & Stummschaltung
- Falls KEINE der oben genannten Bedingungen zutrifft und keine kritischen Issues bekannt sind:
- **Antworte ausschließlich mit dem Wort: HEARTBEAT_OK**
