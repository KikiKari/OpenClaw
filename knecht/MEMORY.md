# Long-Term Memory


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

## Promoted From Short-Term Memory (2026-08-27)

<!-- openclaw-memory-promotion:memory:memory/2026-08-20-1519-heartbeat.md:7:10 -->
- System-Checks: Disk: OK — Root-Dateisystem 39% belegt (186G/503G).; Memory: OK — 7.8 GiB verfügbar; kein Swap konfiguriert.; CPU: OK — `vmstat` meldet 90% idle, keine I/O-Wartezeit.; Load: 5.29 / 3.04 / 2.14; keine CPU-Sättigung sichtbar. [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-20-1519-heartbeat.md:7-10]
<!-- openclaw-memory-promotion:memory:memory/2026-08-20-1519-heartbeat.md:13:15 -->
- Kritische Befunde: OpenRouter liefert wiederholt HTTP 403: tägliches Budget erschöpft.; Der erste Fallback `openai/gpt-5.6-sol` ist für das Projekt nicht zugelassen.; CLI/Gateway-Versionen sind inkonsistent: Konfiguration und Gateway-Service 2026.7.1-2, verfügbare CLI 2026.6.5. Dadurch werden aktive Plugins mit API-Anforderung >=2026.7.1 übersprungen. [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-20-1519-heartbeat.md:13-15]
<!-- openclaw-memory-promotion:memory:memory/2026-08-20-1519-heartbeat.md:18:20 -->
- Durchgeführte bzw. eingeschränkte Aktionen: Vorgeschriebene Host-Checks (`df`, `free`, `uptime`, `vmstat`, `ps`, `journalctl`) ausgeführt.; `openclaw doctor --yes`, `status`, `gateway status` und `nodes status` über den angegebenen absoluten CLI-Pfad geprüft; alle sind in der Sandbox durch Versionsdrift und schreibgeschütztes OpenClaw-Home eingeschränkt/fehlgeschlagen.; Meldung an `ops-hub` versucht, aber die Session ist aus dieser Sandbox nicht sichtbar (`forbidden`). [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-20-1519-heartbeat.md:18-20]
<!-- openclaw-memory-promotion:memory:memory/2026-08-20-1519-heartbeat.md:23:23 -->
- Offener Punkt: Operator muss Gateway/CLI auf dieselbe OpenClaw-Version bringen und die OpenRouter-/Fallback-Modellberechtigungen korrigieren; `ops-hub`-Benachrichtigung außerhalb der Sandbox zustellen. [score=0.825 recalls=0 avg=0.620 source=memory/2026-08-20-1519-heartbeat.md:23-23]
<!-- openclaw-memory-promotion:memory:memory/2026-08-21-0950-heartbeat.md:3:6 -->
- Heartbeat incident — 2026-08-21 09:50 CEST: Host diagnostics healthy: root disk 39% used, 12 GiB memory available, load average 1.54/1.13/0.87.; Journal repeatedly recorded OpenRouter `403 Budget limit exceeded` and unavailable `openai/gpt-5.6-sol`; fallback to `openai/gpt-5.6-terra` succeeded.; Required OpenClaw diagnostics found version drift: config/gateway `2026.7.1-2`, bundled CLI `2026.6.5`. Multiple active plugins require the newer API.; `doctor --yes`, `status`, and `nodes status` cannot complete because this sandbox exposes `/home/openclaw/.openclaw` read-only (`EROFS` while writing health/state files). [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-21-0950-heartbeat.md:3-6]
<!-- openclaw-memory-promotion:memory:memory/2026-08-21-0950-heartbeat.md:7:8 -->
- Heartbeat incident — 2026-08-21 09:50 CEST: `gateway status` reports the same service-version drift; connectivity probe failed with `EPERM` in this sandbox and systemd user services are unavailable.; Attempt to notify `ops-hub` via configured session was forbidden because that session is not visible from this sandbox. Follow-up is deferred to an agent with Gateway/host access: align the CLI and gateway versions and restore writable state storage. [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-21-0950-heartbeat.md:7-8]
<!-- openclaw-memory-promotion:memory:memory/2026-08-21-1047-heartbeat.md:3:6 -->
- Heartbeat — 2026-08-21 10:47 CEST: Host indicators were healthy: root disk 39% used, 12 GiB RAM available, load 1.49, no CPU wait or swap activity.; Journal revealed repeated provider failures: OpenRouter returned HTTP 403 (daily budget limit exceeded); fallback to `openai/gpt-5.6-sol` also lacked project access. The final fallback to `openai/gpt-5.6-terra` succeeded.; Required OpenClaw diagnostics could not complete reliably from this sandbox: the available CLI is 2026.6.5 while configuration and gateway are 2026.7.1-2, and CLI health-state writes fail with `EROFS`.... [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-21-1047-heartbeat.md:3-6]
<!-- openclaw-memory-promotion:memory:memory/2026-08-21-1047-heartbeat.md:8:8 -->
- Heartbeat — 2026-08-21 10:47 CEST: Follow-up: ops-hub / gateway administrator should use the gateway-host OpenClaw installation to reconcile the version drift and repair provider credentials/model access. [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-21-1047-heartbeat.md:8-8]
<!-- openclaw-memory-promotion:memory:memory/2026-08-21-1520-heartbeat.md:5:8 -->
- Host: Disk: `/` 39% used (186 GiB of 503 GiB); all mounts below the 80% threshold.; Memory: 12 GiB available of 15 GiB; no swap configured or in use.; CPU/load: load average 2.13 / 1.25 / 0.94; `vmstat` showed 95% idle in the sampled interval and no I/O wait.; Processes: no unexpected workload visible in the sandbox process view. [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-21-1520-heartbeat.md:5-8]
<!-- openclaw-memory-promotion:memory:memory/2026-08-21-1520-heartbeat.md:12:15 -->
- Platform issue detected: Journal records recurring OpenRouter `403 Budget limit exceeded (daily limit)` errors and a fallback failure because the project lacks access to `gpt-5.6-sol`. Requests later succeeded through `openai/gpt-5.6-terra`.; `/home/openclaw/.npm-global/bin/openclaw doctor --yes`, `status`, and `nodes status` found a version mismatch: config/gateway service is `2026.7.1-2`, but the CLI is `2026.6.5`.; As a result, numerous plugins require a newer plugin API and are skipped.... [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-21-1520-heartbeat.md:12-15]
