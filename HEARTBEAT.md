# HEARTBEAT.md - Main-Checkliste

## Periodische Checks (alle 45min)

### System
- [x] System: vmstat
- [x] Prozesse: ps aux | head -n 10
- [ ] Disk: df -h (< 80%)
- [ ] Memory: free -h
- [ ] Load: uptime
- [x] Logs: journalctl -n 200 -q
- [ ] Crons: openclaw cron list
- [ ] Agents: openclaw agents list
- [ ] Tasks: openclaw tasks list
- [ ] Channels: openclaw channels list
- [ ] Sessions: openclaw sessions
- [x] Nodes: openclaw nodes status && openclaw node list


### Cron-Jobs
- [x] Alle Cron-Jobs auf delivery.mode: none prüfen
- [x] Ergebnisse in memory/ Dateien geschrieben?
- [x] Alle eingegangenen Agent Meldungen an Agent ops-hub übermittelt?
- [x] Alle kritischen Probleme an Agent ops-hub gemeldet?
- [x] Alle kritischen Ereignisse protokolliert?
- [x] Alle offenen Punkte an Agent ops-hub gemeldet?
- [x] Alle nicht erfolgreiche Aktionen zurückgestellt und an Agent ops-hub gemeldet?

## Bei Problemen
- API und Gateway immer Agent ops-hub informieren: openclaw doctor --yes && openclaw status && openclaw gateway status && openclaw nodes status && openclaw node list
- API und Gateway Wartung: openclaw doctor --fix
- memory Wartung: openclaw memory index --dry-run
- session Wartung: openclaw sessions cleanup --dry-run
- agent Wartung: openclaw sessions cleanup --all-agents --dry-run

## Abschluss & Stummschaltung
- Falls KEINE der oben genannten Bedingungen zutrifft und keine kritischen Issues aufgetreten sind:
- **Antworte ausschließlich mit dem Wort: HEARTBEAT_OK**
