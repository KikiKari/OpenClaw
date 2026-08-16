# Long-Term Memory


## Promoted From Short-Term Memory (2026-08-15)

<!-- openclaw-memory-promotion:memory:memory/2026-08-08-1017-heartbeat.md:11:12 -->
- Ergebnis: Keine kritischen Meldungen, keine Probleme, keine offenen Punkte.; Keine Meldung an ops-hub erforderlich. [score=0.857 recalls=0 avg=0.620 source=memory/2026-08-08-1017-heartbeat.md:11-12]
<!-- openclaw-memory-promotion:memory:memory/2026-08-09-0847-heartbeat.md:4:4 -->
- Ergebnis: Keine kritischen Systembefunde festgestellt. [score=0.844 recalls=0 avg=0.620 source=memory/2026-08-09-0847-heartbeat.md:4-4]
<!-- openclaw-memory-promotion:memory:memory/2026-08-09-1317-heartbeat.md:4:4 -->
- Ergebnis: Keine kritischen Systembefunde festgestellt. [score=0.844 recalls=0 avg=0.620 source=memory/2026-08-09-1317-heartbeat.md:4-4]
<!-- openclaw-memory-promotion:memory:memory/2026-08-08-1017-heartbeat.md:8:8 -->
- System-Checks (Sandbox): ps/vmstat/journalctl/free/uptime: im Sandbox-Container nicht verfügbar (Ersatz: /proc/meminfo, /proc/loadavg, /proc/uptime) [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-08-1017-heartbeat.md:8-8]
<!-- openclaw-memory-promotion:memory:memory/2026-08-08-2217-heartbeat.md:4:7 -->
- System: Disk: / 37% (503G, 305G frei) — OK (< 80%); Memory: 16G total, 11.7G verfügbar — OK; Load: 1.68 / 0.90 / 0.69 auf 10 Cores — OK; Uptime: ~4.6 Tage (Container) [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-08-2217-heartbeat.md:4-7]
<!-- openclaw-memory-promotion:memory:memory/2026-08-08-2217-heartbeat.md:8:9 -->
- System: Prozesse: nur 2 sichtbar im Sandbox-Namespace (ps/journalctl nicht verfügbar); Logs: journalctl im Sandbox nicht verfügbar, Host-Zugriff blockiert — keine kritischen Meldungen prüfbar, keine Auffälligkeiten [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-08-2217-heartbeat.md:8-9]
<!-- openclaw-memory-promotion:memory:memory/2026-08-09-0847-heartbeat.md:7:10 -->
- System-Checks: Disk: OK — `/` und `/workspace` bei 37% (178G/503G belegt, 305G frei); Memory: OK — MemTotal 16.325.864 kB, MemAvailable 11.831.840 kB, Swap 0 kB; Load: OK — loadavg 1.81 1.01 0.73, laufende Prozesse 18, blockiert 0; Uptime: 439245.60 s [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-09-0847-heartbeat.md:7-10]
<!-- openclaw-memory-promotion:memory:memory/2026-08-09-0847-heartbeat.md:11:12 -->
- System-Checks: CPU/VM: `/proc/stat` und `/proc/vmstat` gelesen; keine OOM-Kills (`oom_kill 0`), kein Swap-I/O; Prozesse/Logs: eingeschränkt prüfbar; `ps`, `top`, `journalctl`, `dmesg`, `free`, `uptime`, `vmstat`, `/var/log/syslog`, `/var/log/kern.log` in dieser Sandbox nicht verfügbar/erlaubt [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-09-0847-heartbeat.md:11-12]
<!-- openclaw-memory-promotion:memory:memory/2026-08-09-0847-heartbeat.md:15:18 -->
- Nicht erfolgreiche Prüfschritte: `free -h`: command not found; `uptime`: command not found; `vmstat`: command not found; `ps aux | head -n 20`: Pipe durch Policy blockiert; `ps` nicht vorhanden [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-09-0847-heartbeat.md:15-18]
<!-- openclaw-memory-promotion:memory:memory/2026-08-09-0847-heartbeat.md:19:22 -->
- Nicht erfolgreiche Prüfschritte: `journalctl -n 2000 --no-pager`: command not found; `dmesg -T`: Operation not permitted; `busybox ps aux`: command not found; `top -b -n 1`: command not found [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-09-0847-heartbeat.md:19-22]

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
