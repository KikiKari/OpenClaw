# Long-Term Memory


## Promoted From Short-Term Memory (2026-08-05)

<!-- openclaw-memory-promotion:memory:memory/2026-07-30.md:3:6 -->
- 01:27 CEST heartbeat recovery check: host diagnostics healthy (root disk 35% used, 12 GiB memory available, load 0.74).; Recurring OpenClaw model-routing failures observed in journal: `openrouter/openrouter/auto` receives HTTP 404 due to guardrail/data-policy restrictions; fallback `openai/gpt-5.6-sol` is unavailable to project `proj_5x0o8Fuf4MRfDsdELuDq4vc6`; final fallback `openai/gpt-5.6-terra` succeeds.; Attempted to notify `ops-hub` through its agent session; delivery was forbidden because that session is not visible from this sandboxed agent session.... [score=0.812 recalls=0 avg=0.620 source=memory/2026-07-30.md:3-6]
<!-- openclaw-memory-promotion:memory:memory/2026-07-30.md:7:8 -->
- 20:57 CEST heartbeat recovery check: host diagnostics healthy (root disk 35% used, 13 GiB available, load 0.29). The model-routing failures remain active: `openrouter/auto` returns HTTP 404 because no endpoint matches the configured guardrail/data-policy restriction; fallback `openai/gpt-5.6-sol` is unauthorized for project `proj_5x0o8Fuf4MRfDsdELuDq4vc6`; `gpt-5.6-terra` later succeeds. A fresh `ops-hub` notification attempt was again forbidden because its session is not visible from this sandboxed agent session. Gateway-side repair remains pending.... [score=0.812 recalls=0 avg=0.620 source=memory/2026-07-30.md:7-8]

## Promoted From Short-Term Memory (2026-08-06)

<!-- openclaw-memory-promotion:memory:memory/2026-07-31.md:3:5 -->
- 00:42 CEST heartbeat recovery check: host diagnostics healthy (root disk 35% used, 13 GiB available, load 0.24). Journal shows recurring OpenRouter routing failure: `openrouter/auto` returns HTTP 404 ("All providers have been ignored"); `openai/gpt-5.6-sol` is unavailable to the configured project; final fallback `openai/gpt-5.6-terra` succeeds. Attempt to notify `ops-hub` was forbidden because its session is not visible from this sandboxed agent session. Gateway-side model configuration repair remains pending. - 19:27 CEST heartbeat recovery check: host diagnostics remain healthy (root disk 36% used, 11 GiB available, load 0.67).... [score=0.812 recalls=0 avg=0.620 source=memory/2026-07-31.md:3-5]

## Promoted From Short-Term Memory (2026-08-07)

<!-- openclaw-memory-promotion:memory:memory/2026-08-01.md:3:6 -->
- Heartbeat — 2026-08-01 11:12 CEST: Host diagnostics normal: root filesystem 36% used; 11 GiB memory available; load average 1.39/0.53/0.40; no swap activity.; Repeated model-routing fault observed in journal from 10:34 through 11:12: `openrouter/openrouter/auto` returns HTTP 404 ("All providers have been ignored"); fallback `openai/gpt-5.6-sol` is not accessible to the project; a subsequent fallback to `openai/gpt-5.6-terra` succeeds.; Failed heartbeat lanes include docs, cron, and knecht.... [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-01.md:3-6]
<!-- openclaw-memory-promotion:memory:memory/2026-08-01.md:10:13 -->
- Heartbeat — 2026-08-01 18:42 CEST: Host diagnostics remain normal: root filesystem 35% used; 11 GiB memory available; load average 1.17/0.48/0.39; no swap activity.; Gateway is reachable and active; the paired OpenClaw node is connected.; The same model-routing fault persists: configured `openrouter/openrouter/auto` receives HTTP 404 ("All providers have been ignored"), then the inaccessible `openai/gpt-5.6-sol` fallback fails before `openai/gpt-5.6-terra` succeeds.... [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-01.md:10-13]
<!-- openclaw-memory-promotion:memory:memory/2026-08-01.md:14:14 -->
- Heartbeat — 2026-08-01 18:42 CEST: Notification to `ops-hub` was again attempted through `sessions_send` and denied because the target session is not visible from this sandboxed agent session. [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-01.md:14-14]
<!-- openclaw-memory-promotion:memory:memory/2026-08-01.md:18:21 -->
- Heartbeat — 2026-08-01 19:27 CEST: Host diagnostics remain normal: root filesystem 35% used; 11 GiB memory available; load average 0.87/0.45/0.37; no swap activity.; Gateway is reachable, active, and its paired node is connected. The model-routing fault persists: configured `openrouter/openrouter/auto` returns HTTP 404, then unauthorized fallback `openai/gpt-5.6-sol` fails before `openai/gpt-5.6-terra` succeeds.; Ran the prescribed platform maintenance: `openclaw doctor --yes`, `doctor --force`, and a full memory-index rebuild.... [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-01.md:18-21]
<!-- openclaw-memory-promotion:memory:memory/2026-08-01.md:22:22 -->
- Heartbeat — 2026-08-01 19:27 CEST: Attempted to notify `ops-hub` through `sessions_send`; delivery was denied because the target session is not visible from this sandboxed agent session. The configured primary/fallback model chain still needs an ops-hub administrator correction. [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-01.md:22-22]

## Promoted From Short-Term Memory (2026-08-08)

<!-- openclaw-memory-promotion:memory:memory/2026-08-03.md:5:8 -->
- Heartbeat recovery check (02:12–02:14 CEST): Host healthy: root filesystem 36% used; 11 GiB available RAM; load 0.57; no swap or I/O pressure.; Gateway is active and reachable at `ws://127.0.0.1:18789`; one paired node is connected.; Repeated model failures observed in the journal: configured `openrouter/openrouter/auto` returns HTTP 404 ("All providers have been ignored"), and fallback `openai/gpt-5.6-sol` is inaccessible to the configured project.... [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-03.md:5-8]
<!-- openclaw-memory-promotion:memory:memory/2026-08-03.md:9:9 -->
- Heartbeat recovery check (02:12–02:14 CEST): Required notification to `ops-hub` could not be delivered: the message API lacked scope and direct session send was forbidden because `agent:ops-hub:main` is not visible from this sandboxed session. [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-03.md:9-9]

## Promoted From Short-Term Memory (2026-08-09)

<!-- openclaw-memory-promotion:memory:memory/2026-08-03.md:13:16 -->
- Heartbeat recovery check (05:12–05:14 CEST): Host healthy: root filesystem 36% used; 11 GiB available RAM; load 0.58; no swap or I/O pressure.; Gateway remains active, reachable, and connected to one paired node.; The model-routing failure remains active: `openrouter/openrouter/auto` returns HTTP 404 ("All providers have been ignored"); `openai/gpt-5.6-sol` is unavailable to the configured project; automatic fallback to `openai/gpt-5.6-terra` succeeds. It affects heartbeat sessions for main, docs, cron, and knecht.; `openclaw doctor --yes` refreshed the stale `codex` plugin and indexed 75/88 plugins.... [score=0.811 recalls=0 avg=0.620 source=memory/2026-08-03.md:13-16]
<!-- openclaw-memory-promotion:memory:memory/2026-08-03.md:17:17 -->
- Heartbeat recovery check (05:12–05:14 CEST): Required notification to `ops-hub` was attempted but blocked: `sessions_send` returned `forbidden` because `agent:ops-hub:main` is not visible from this sandboxed session. No destructive maintenance was run. [score=0.811 recalls=0 avg=0.620 source=memory/2026-08-03.md:17-17]
<!-- openclaw-memory-promotion:memory:memory/2026-08-03.md:21:23 -->
- Heartbeat recovery check (09:41–09:42 CEST): Host healthy: root filesystem 36% used; 11 GiB available RAM; load 1.05; no swap or I/O pressure.; The model-routing failure remains active: `openrouter/openrouter/auto` returns HTTP 404 ("All providers have been ignored"); fallback `openai/gpt-5.6-sol` is inaccessible to the configured project, which causes embedded heartbeat lane failures.; Required notification to `ops-hub` was attempted and blocked: `sessions_send` returned `forbidden` because `agent:ops-hub:main` is not visible from this sandboxed session. No maintenance commands were run. [score=0.811 recalls=0 avg=0.620 source=memory/2026-08-03.md:21-23]
<!-- openclaw-memory-promotion:memory:memory/2026-08-03.md:27:30 -->
- Heartbeat recovery check (12:41–12:43 CEST): Host healthy: root filesystem 36% used; 11 GiB available RAM; load 1.26; no swap or I/O pressure.; Gateway is active and reachable; one paired node is connected.; The model-routing failure remains active: primary `openrouter/openrouter/auto` returns HTTP 404 ("All providers have been ignored") and the first fallback `openai/gpt-5.6-sol` is not accessible to the configured project.... [score=0.811 recalls=0 avg=0.620 source=memory/2026-08-03.md:27-30]
<!-- openclaw-memory-promotion:memory:memory/2026-08-03.md:31:31 -->
- Heartbeat recovery check (12:41–12:43 CEST): Required notification to `ops-hub` was attempted and blocked: `sessions_send` returned `forbidden` because `agent:ops-hub:main` is not visible from this sandboxed session. [score=0.811 recalls=0 avg=0.620 source=memory/2026-08-03.md:31-31]
