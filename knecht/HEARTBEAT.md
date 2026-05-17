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

## Bei Problemen
- API und Gateway immer Agent ops-hub informieren: openclaw doctor --yes && openclaw status && openclaw gateway status && openclaw nodes status && openclaw node list
- API und Gateway Wartung: openclaw doctor --force
- memory Wartung: openclaw memory index --force
- session Wartung: openclaw sessions cleanup --enforce
- agent Wartung: openclaw sessions cleanup --all-agents

## Abschluss & Stummschaltung
- Falls KEINE der oben genannten Bedingungen zutrifft:
- **Antworte ausschließlich mit dem Wort: HEARTBEAT_OK**
