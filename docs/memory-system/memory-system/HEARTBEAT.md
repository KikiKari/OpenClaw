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

## Bei Problemen
- API und Gateway immer Agent ops-hub informieren: openclaw status && openclaw gateway status && openclaw nodes status && openclaw node list
- API und Gateway Wartung: openclaw doctor --yes
- memory Wartung: openclaw memory index --dry-run
- session Wartung: openclaw sessions cleanup --dry-run
- agent Wartung: openclaw sessions cleanup --all-agents --dry-run

## Abschluss & Stummschaltung
- Falls KEINE der oben genannten Bedingungen zutrifft:
- **Antworte ausschließlich mit dem Wort: HEARTBEAT_OK**
