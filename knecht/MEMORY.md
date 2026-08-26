# Long-Term Memory


## Promoted From Short-Term Memory (2026-08-25)

<!-- openclaw-memory-promotion:memory:memory/2026-08-19-0317-heartbeat.md:4:4 -->
- Ergebnis: Keine kritischen Systembefunde festgestellt. [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-19-0317-heartbeat.md:4-4]
<!-- openclaw-memory-promotion:memory:memory/2026-08-19-0317-heartbeat.md:7:10 -->
- System-Checks: Disk: OK — `/` und `/workspace` bei 39% (184G/503G belegt, 299G frei); Memory: OK — MemTotal 16.325.868 kB, MemAvailable 11.746.080 kB, SwapTotal 0 kB, SwapFree 0 kB; Load: OK — loadavg 2.88 2.04 1.59, laufende Prozesse 4, blockierte Prozesse 0; Uptime: `/proc/uptime` 31159.89 s [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-19-0317-heartbeat.md:7-10]
<!-- openclaw-memory-promotion:memory:memory/2026-08-19-0317-heartbeat.md:11:13 -->
- System-Checks: VM: `/proc/vmstat` gelesen; keine OOM-Kills (`oom_kill 0`), kein Swap-I/O (`pswpin 0`, `pswpout 0`); Prozesse: `ps` in Sandbox nicht verfügbar; `/proc/stat` zeigt `procs_running 4`, `procs_blocked 0`; Logs: `journalctl` in Sandbox nicht verfügbar; `/var/log` enthält nur ältere Paket-/Alternatives-Logs (letzte Änderung 15.06.) ohne aktuelle kritische Meldungen [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-19-0317-heartbeat.md:11-13]
<!-- openclaw-memory-promotion:memory:memory/2026-08-19-0317-heartbeat.md:16:19 -->
- Nicht erfolgreiche bzw. eingeschränkte Prüfschritte: `free -h`: command not found (Ersatz: `/proc/meminfo`); `uptime`: command not found (Ersatz: `/proc/uptime`, `/proc/loadavg`); `vmstat`: command not found (Ersatz: `/proc/vmstat`, `/proc/stat`); `ps aux`: command not found (Ersatz: `/proc/stat`) [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-19-0317-heartbeat.md:16-19]
<!-- openclaw-memory-promotion:memory:memory/2026-08-19-0317-heartbeat.md:20:20 -->
- Nicht erfolgreiche bzw. eingeschränkte Prüfschritte: `journalctl -n 2000`: command not found (kein systemd in Sandbox) [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-19-0317-heartbeat.md:20-20]
<!-- openclaw-memory-promotion:memory:memory/2026-08-19-0317-heartbeat.md:23:24 -->
- Cron-/Heartbeat-Ablage: Letzter Heartbeat-Eintrag vor diesem Lauf: 2026-08-18-2117-heartbeat.md (keine kritischen Befunde).; Dieses Ergebnis wurde als aktueller Heartbeat-Eintrag abgelegt. [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-19-0317-heartbeat.md:23-24]
<!-- openclaw-memory-promotion:memory:memory/2026-08-19-0417-heartbeat.md:4:4 -->
- Ergebnis: Keine kritischen Systembefunde festgestellt. [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-19-0417-heartbeat.md:4-4]
<!-- openclaw-memory-promotion:memory:memory/2026-08-19-0417-heartbeat.md:7:10 -->
- System-Checks: Disk: OK — `/` und `/workspace` bei 39% (184G/503G belegt, 299G frei); Memory: OK — MemTotal 16.325.868 kB, MemAvailable 11.680.196 kB; Load: OK — loadavg 1.84 1.15 0.92; Uptime: `/proc/uptime` 34750.13 s [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-19-0417-heartbeat.md:7-10]
<!-- openclaw-memory-promotion:memory:memory/2026-08-19-0417-heartbeat.md:11:12 -->
- System-Checks: Prozesse: `ps` in Sandbox nicht verfügbar; Logs: `journalctl` in Sandbox nicht verfügbar [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-19-0417-heartbeat.md:11-12]
<!-- openclaw-memory-promotion:memory:memory/2026-08-19-0417-heartbeat.md:15:18 -->
- Nicht erfolgreiche bzw. eingeschränkte Prüfschritte: `free -h`: command not found (Ersatz: `/proc/meminfo`); `uptime`: command not found (Ersatz: `/proc/uptime`, `/proc/loadavg`); `vmstat`: command not found; `ps aux`: command not found [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-19-0417-heartbeat.md:15-18]

## Promoted From Short-Term Memory (2026-08-26)

<!-- openclaw-memory-promotion:memory:memory/2026-08-19-0417-heartbeat.md:19:19 -->
- Nicht erfolgreiche bzw. eingeschränkte Prüfschritte: `journalctl -n 2000`: command not found (kein systemd in Sandbox) [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-19-0417-heartbeat.md:19-19]
<!-- openclaw-memory-promotion:memory:memory/2026-08-19-0417-heartbeat.md:22:23 -->
- Cron-/Heartbeat-Ablage: Letzter Heartbeat-Eintrag vor diesem Lauf: 2026-08-19-0317-heartbeat.md (keine kritischen Befunde).; Ergebnisse werden weiterhin regelmäßig in `memory/` geschrieben. [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-19-0417-heartbeat.md:22-23]
<!-- openclaw-memory-promotion:memory:memory/2026-08-19-0747-heartbeat.md:4:4 -->
- Ergebnis: Keine kritischen Systembefunde festgestellt. [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-19-0747-heartbeat.md:4-4]
<!-- openclaw-memory-promotion:memory:memory/2026-08-19-0747-heartbeat.md:7:10 -->
- System-Checks: Disk: OK — `/` und `/workspace` bei 39% (184G/503G belegt, 299G frei); Memory: OK — MemTotal 16.325.868 kB, MemAvailable 11.767.796 kB (72,1% verfügbar), Swap 0 kB; Load: OK — loadavg 1.20 0.83 0.80, laufende Prozesse 2, blockierte Prozesse 0; Uptime: `/proc/uptime` 47378.15 s [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-19-0747-heartbeat.md:7-10]
<!-- openclaw-memory-promotion:memory:memory/2026-08-20-0447-heartbeat.md:4:4 -->
- Ergebnis: Keine neuen kritischen Systembefunde. Vorheriger Budget-Limit-Fehler (23:50 Aug 19) scheint durch Tages-Reset behoben. [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-20-0447-heartbeat.md:4-4]
<!-- openclaw-memory-promotion:memory:memory/2026-08-20-0447-heartbeat.md:7:10 -->
- System-Checks: Disk: OK — 39% (184G/503G, 299G frei); Memory: OK — MemTotal ~16 GB, MemAvailable ~11,5 GB (72%), Swap 0; Load: OK — loadavg 1.60 0.93 0.84, ~34h uptime; VM: OK — keine OOM-Kills, kein Swap-I/O [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-20-0447-heartbeat.md:7-10]
<!-- openclaw-memory-promotion:memory:memory/2026-08-20-0447-heartbeat.md:13:15 -->
- Fortbestehende Probleme (aus 2026-08-19-2350-heartbeat.md): CLi-Versionskonflikt: 2026.6.5 installiert vs. 2026.7.1-2 erwartet → Operator-Update nötig; Sandbox OpenClaw-Home read-only → kein `openclaw doctor/status` möglich; ops-hub Session nicht sichtbar aus Sandbox → keine Benachrichtigung möglich [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-20-0447-heartbeat.md:13-15]
<!-- openclaw-memory-promotion:memory:memory/2026-08-20-0447-heartbeat.md:18:18 -->
- Nicht erfolgreiche bzw. eingeschränkte Prüfschritte: `free`, `uptime`, `vmstat`, `ps`, `journalctl`: in Sandbox nicht verfügbar (Ersatz: /proc) [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-20-0447-heartbeat.md:18-18]
<!-- openclaw-memory-promotion:memory:memory/2026-08-20-0447-heartbeat.md:21:23 -->
- Aktionen: Keine neuen kritischen Meldungen.; ops-hub Benachrichtigung weiterhin nicht möglich (Session unsichtbar).; Budget-Limit scheint behoben (aktueller Heartbeat läuft über openrouter/auto). [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-20-0447-heartbeat.md:21-23]
<!-- openclaw-memory-promotion:memory:memory/2026-08-20-1519-heartbeat.md:4:4 -->
- Ergebnis: API-/Gateway-Konfigurationsproblem festgestellt und nicht behebbar aus der Sandbox. [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-20-1519-heartbeat.md:4-4]
