# HEARTBEAT.md - Main-Checkliste

## Periodische Checks (alle 45min)

- Last run: 2026-06-09 00:02:01 CEST

### System
- [x] System: vmstat
- [x] Prozesse: ps aux | head -n 10
- [x] Disk: df -h (< 80%)
- [x] Memory: free -h
- [x] Load: uptime
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
- API und Gateway immer Agent ops-hub informieren: openclaw doctor --yes && openclaw status && openclaw gateway stat>
- API und Gateway Wartung: openclaw doctor --fix
- memory Wartung: openclaw memory index --dry-run
- session Wartung: openclaw sessions cleanup --dry-run
- agent Wartung: openclaw sessions cleanup --all-agents --dry-run

## OpenClaw-Control-Rueckmeldung
- Fuer sichtbare Rueckmeldung in der Gateway-Control-UI niemals `channel=heartbeat` verwenden.
- Wenn eine Meldung aus einer isolierten oder Cron-Session an den Betreiber noetig ist und `sessions_send` verfuegbar ist: `sessions_send(sessionKey="agent:main:main", message="<kurzer Status>", timeoutSeconds=0)`.
- Keine `sessions_send`-Selbstsendung verwenden, wenn die aktuelle Session bereits `agent:main:main` ist; dann normale sichtbare Antwort bzw. targetless `message(action=send)` verwenden, falls sichtbare Ausgabe via Message-Tool verlangt wird.

- [ ] Pending script: /home/openclaw/.openclaw/scripts/abstractions-publish-gateway.sh requires manual approval

## Abschluss & Stummschaltung
- Falls KEINE der oben genannten Bedingungen zutrifft und keine kritischen Issues aufgetreten sind:
- **Antworte ausschließlich mit dem Wort: HEARTBEAT_OK**
