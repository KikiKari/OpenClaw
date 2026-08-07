# Long-Term Memory


## Promoted From Short-Term Memory (2026-07-31)

<!-- openclaw-memory-promotion:memory:memory/2026-07-25.md:5:8 -->
- Heartbeat — 04:27 CEST: Host diagnostics normal: root filesystem 35% used; 10 GiB RAM available; load average 1.49 / 1.12 / 1.16; no swap or I/O pressure.; `journalctl -n 2000` shows repeated OpenClaw model-routing failures: `openrouter/auto` returns HTTP 404 due to privacy guardrails; fallback `openai/gpt-5.6-sol` is unavailable to the configured project.... [score=0.812 recalls=0 avg=0.620 source=memory/2026-07-25.md:5-8]

## Promoted From Short-Term Memory (2026-08-01)

<!-- openclaw-memory-promotion:memory:memory/2026-07-26.md:3:5 -->
- 14:57 CEST heartbeat: host diagnostics normal (root disk 35% used; 10 GiB memory available; load 1.55/1.41/1.31; no swap pressure).; Unresolved platform alert: repeated `openrouter/auto` 404 failures and unauthorized fallback to `openai/gpt-5.6-sol`; automatic fallback to `openai/gpt-5.6-terra` succeeds. Observed around 14:19, 14:36, 14:49, and 14:56 CEST.; Attempt to notify `ops-hub` was forbidden because that agent session is not visible from this sandboxed session. Gateway-only diagnostic/maintenance commands were therefore not run. [score=0.812 recalls=0 avg=0.620 source=memory/2026-07-26.md:3-5]

## Promoted From Short-Term Memory (2026-08-02)

<!-- openclaw-memory-promotion:memory:memory/2026-07-27.md:3:4 -->
- 17:12 CEST heartbeat: Linux resources healthy (root disk 35% used; 9.4 GiB memory available; load 1.40). Journal contained recurring OpenRouter configuration failures: `openrouter/auto` returned 404 due to guardrail/data-policy restrictions, then `openai/gpt-5.6-sol` was inaccessible to project `proj_5x0o8Fuf4MRfDsdELuDq4vc6`; runs ultimately fell back to `openai/gpt-5.6-terra`. - Required escalation to `ops-hub` was attempted through `sessions_send`, but was rejected because `agent:ops-hub:main` is not visible from this sandboxed agent session. The model configuration issue remains unreported to ops-hub from this agent. [score=0.812 recalls=0 avg=0.620 source=memory/2026-07-27.md:3-4]

## Promoted From Short-Term Memory (2026-08-04)

<!-- openclaw-memory-promotion:memory:memory/2026-07-29.md:5:8 -->
- 17:13 CEST — Heartbeat recovery check: Host diagnostics healthy: root disk 35% used; 12 GiB memory available; load 1.10; 97% CPU idle; no swap or blocked processes observed.; `journalctl -n 2000` found repeated gateway model-routing failures for `openrouter/auto` (HTTP 404/no eligible endpoint), fallback failures because the project lacks access to `openai/gpt-5.6-sol`, and a gateway memory-pressure warning (RSS 1.68 GiB versus 1.5 GiB threshold).; Required gateway checks could not be completed: configured OpenClaw execution host disallows `gateway`; its `auto` host does not contain `/home/openclaw/.npm-global/bin/openclaw`.;... [score=0.812 recalls=0 avg=0.620 source=memory/2026-07-29.md:5-8]
<!-- openclaw-memory-promotion:memory:memory/2026-07-29.md:12:14 -->
- 22:27 CEST — Heartbeat recovery check: Host diagnostics healthy: root disk 35% used; 12 GiB memory available; load 0.66; 96% CPU idle; no swap or blocked processes observed.; `journalctl -n 2000` again found recurring gateway model-routing failures: `openrouter/auto` receives HTTP 404 because no endpoint meets its privacy/guardrail restrictions, then `openai/gpt-5.6-sol` fails because the project lacks access.... [score=0.812 recalls=0 avg=0.620 source=memory/2026-07-29.md:12-14]

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
