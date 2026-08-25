# Long-Term Memory


## Promoted From Short-Term Memory (2026-08-16)

<!-- openclaw-memory-promotion:memory:memory/2026-08-09-1517-heartbeat.md:4:4 -->
- Ergebnis: Keine kritischen Systembefunde festgestellt. [score=0.857 recalls=0 avg=0.620 source=memory/2026-08-09-1517-heartbeat.md:4-4]
<!-- openclaw-memory-promotion:memory:memory/2026-08-09-0847-heartbeat.md:23:24 -->
- Nicht erfolgreiche Prüfschritte: `tail -n 2000 /var/log/syslog`: Datei nicht vorhanden; `tail -n 2000 /var/log/kern.log`: Datei nicht vorhanden [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-09-0847-heartbeat.md:23-24]
<!-- openclaw-memory-promotion:memory:memory/2026-08-09-1317-heartbeat.md:7:10 -->
- System-Checks: Disk: OK — `/` und `/workspace` bei 37% (176G/503G belegt, 307G frei); Memory: OK — MemTotal 16.325.864 kB, MemAvailable 12.774.700 kB, SwapTotal 0 kB, SwapFree 0 kB; Load: OK — loadavg 0.37 0.37 0.31, laufende Prozesse 5, Threads/Tasks 728; Uptime: `/proc/uptime` 12155.05 s [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-09-1317-heartbeat.md:7-10]
<!-- openclaw-memory-promotion:memory:memory/2026-08-09-1317-heartbeat.md:11:11 -->
- System-Checks: VM: `/proc/vmstat` gelesen; keine OOM-Kills (`oom_kill 0`), kein Swap-I/O (`pswpin 0`, `pswpout 0`) [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-09-1317-heartbeat.md:11-11]
<!-- openclaw-memory-promotion:memory:memory/2026-08-09-1317-heartbeat.md:14:17 -->
- Nicht erfolgreiche bzw. eingeschränkte Prüfschritte: `uptime`: command not found; `free -h`: command not found; `vmstat 1 3`: command not found; `ps aux`: command not found; `ps aux | head -n 20` zusätzlich durch Pipe-Policy blockiert [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-09-1317-heartbeat.md:14-17]
<!-- openclaw-memory-promotion:memory:memory/2026-08-09-1317-heartbeat.md:18:18 -->
- Nicht erfolgreiche bzw. eingeschränkte Prüfschritte: `journalctl -n 2000 --no-pager`: command not found; Umleitung/Tail durch Policy blockiert [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-09-1317-heartbeat.md:18-18]
<!-- openclaw-memory-promotion:memory:memory/2026-08-09-1517-heartbeat.md:7:10 -->
- System-Checks: Disk: OK — `/` und `/workspace` bei 37% (176G/503G belegt, 307G frei); Memory: OK — MemTotal 16.325.864 kB, MemAvailable 12.857.052 kB, SwapTotal 0 kB, SwapFree 0 kB; Load: OK — loadavg 0.43 0.31 0.27, laufende Prozesse 20, blockierte Prozesse 0, Threads/Tasks 720; Uptime: `/proc/uptime` 19459.22 s [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-09-1517-heartbeat.md:7-10]
<!-- openclaw-memory-promotion:memory:memory/2026-08-09-1517-heartbeat.md:11:12 -->
- System-Checks: VM: `/proc/vmstat` gelesen; keine OOM-Kills (`oom_kill 0`), kein Swap-I/O (`pswpin 0`, `pswpout 0`); Logs: `journalctl` in Sandbox nicht verfügbar; `/var/log` enthält nur ältere Paket-/Alternatives-Logs ohne aktuelle kritische Meldungen [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-09-1517-heartbeat.md:11-12]
<!-- openclaw-memory-promotion:memory:memory/2026-08-09-1517-heartbeat.md:15:18 -->
- Nicht erfolgreiche bzw. eingeschränkte Prüfschritte: `free -h`: command not found; `uptime`: command not found; `vmstat 1 5`: command not found; `ps aux`: command not found [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-09-1517-heartbeat.md:15-18]
<!-- openclaw-memory-promotion:memory:memory/2026-08-09-1517-heartbeat.md:19:20 -->
- Nicht erfolgreiche bzw. eingeschränkte Prüfschritte: `journalctl -n 2000 --no-pager`: command not found; Gateway-Host-Diagnostik per `exec host=gateway`: durch Exec-Host-Policy nicht erlaubt [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-09-1517-heartbeat.md:19-20]

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
