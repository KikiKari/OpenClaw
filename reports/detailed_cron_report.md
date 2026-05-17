
## Übersicht aller laufenden und geplanten Cron-Jobs

**Datum:** 2026-04-19
**Uhrzeit:** 20:02 GMT+2

### Neu erstellte permanente Sub-Agents (als Cron-Jobs mit persistenter Session)

| # | Name                    | Session                   | Model                           | Schedule       | Tools                                                                                                                                                                                                                                                                 |
|---|---------------------------|---------------------------|---------------------------------|----------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1 | clawhub-git-sync-agent    | session:clawhub-git-sync  | kimi-k2.5                       | stündlich      | exec (clawhub CLI), read, write, edit                                                                                                                                                                                                                                 |
| 2 | db-maintainer             | session:db-maintainer     | deepseek-r1-0528                | alle 30 Min    | exec (SQLite), read/write (DBs), nodes:spawn_check_fallback                                                                                                                                                                                                           |
| 3 | log-collector             | session:log-collector     | kimi-k2.5                       | alle 3 Std     | exec (SSH), read/write_ssh, logs:collect_store                                                                                                                                                                                                                        |
| 4 | channel-status-agent      | session:channel-status    | claude-3.5-sonnet               | 9/21 Uhr       | message, sessions_spawn                                                                                                                                                                                                                                               |
| 5 | node-health-monitor       | session:node-health       | kimi-k2.5                       | alle 45 Min    | exec (SSH), read (Metriken), nodes:query_all                                                                                                                                                                                                                        |
| 6 | reports-creator           | session:reports-creator   | deepseek-r1-0528                | täglich 6:00   | exec, read (DBs), write (Reports)                                                                                                                                                                                                                                     |
| 7 | script-abstractions-manager | session:abstractions-mgr  | nemotron-super-49b              | alle 6 Std     | exec, read, write, nodes:query_all                                                                                                                                                                                                                                    |

### Vorhandene Cron-Jobs (unverändert)

| Name                      | Schedule       | Session   | Status |
|---------------------------|----------------|-----------|--------|
| light-system-check        | alle 3h        | isolated  | ✅ enabled (Fehler) |
| session-delta-sync        | alle 3h        | isolated  | ✅ enabled |
| daily-system-health       | täglich 6:00   | isolated  | ✅ enabled |
| daily-memory-cleanup      | täglich 7:00   | isolated  | ✅ enabled |
| daily-security-check      | täglich 8:00   | isolated  | ✅ enabled |
| hourly-email-check        | stündlich      | isolated  | ❌ disabled (Channel-Fehler) |
| node3-reboot-check        | 8. April 03:31 | session   | ❌ disabled (Abgelaufen) |
| tiktok-live-check-20      | 20 * * * *     | isolated  | ❌ disabled (Channel-Fehler) |
| tiktok-live-check-45      | 45 * * * *     | isolated  | ❌ disabled (Channel-Fehler) |

**Hinweis:** Die "neuen" Jobs sind als persistente Sessions konfiguriert, während die "vorhandenen" meist isolierte Einzelsessions sind.
