# Long-Term Memory


## Promoted From Short-Term Memory (2026-07-28)

<!-- openclaw-memory-promotion:memory:memory/2026-07-22-0557.md:3:5 -->
- Heartbeat incident — 2026-07-22 05:57 CEST: Host diagnostics were healthy: root filesystem 35% used; 13 GiB RAM available; load average 0.17/0.13/0.15; no swap or CPU-pressure indication.; Gateway journal shows recurring model-routing failures for heartbeats: `openrouter/auto` returns HTTP 404 because no endpoints match the account guardrail/data-policy restrictions, then fallback `openai/gpt-5.6-sol` is denied for the project. `openai/gpt-5.6-terra` subsequently succeeds.; Attempted to notify `ops-hub` through the configured agent session.... [score=0.812 recalls=0 avg=0.620 source=memory/2026-07-22-0557.md:3-5]
<!-- openclaw-memory-promotion:memory:memory/2026-07-22-1927.md:3:6 -->
- Heartbeat – 2026-07-22 19:27 CEST: Host checks healthy: root filesystem 35% used; 9.8 GiB memory available; CPU idle 87–95%; no swap pressure.; Gateway journal shows a recurring model routing fault: `openrouter/auto` returns 404 under current guardrail/data-policy restrictions; fallback `openai/gpt-5.6-sol` is not accessible to the project; routing eventually succeeds with `openai/gpt-5.6-terra` after roughly 25–30 seconds.; Required diagnostics on the Gateway could not run because this session is not permitted to override the OpenClaw exec host to `gateway`.; Required escalation to `ops-hub` was attempted via `sessions_send` but... [score=0.812 recalls=0 avg=0.620 source=memory/2026-07-22-1927.md:3-6]
<!-- openclaw-memory-promotion:memory:memory/2026-07-22-2057.md:3:5 -->
- Heartbeat – 2026-07-22 20:57 CEST: Host diagnostics healthy: root filesystem 35% used; 9.2 GiB memory available; CPU 95% idle; no swap pressure.; Gateway journal confirms the recurring routing problem remains active: `openrouter/auto` returns HTTP 404 under the configured privacy/guardrail policy, and fallback `openai/gpt-5.6-sol` is unauthorized for project `proj_5x0o8Fuf4MRfDsdELuDq4vc6`. Impacted heartbeat lanes include knecht, docs, cron, and main.; A required escalation to `ops-hub` was attempted through `sessions_send`, but it was rejected because `agent:ops-hub:main` is not visible from this sandboxed session.... [score=0.812 recalls=0 avg=0.620 source=memory/2026-07-22-2057.md:3-5]

## Promoted From Short-Term Memory (2026-07-30)

<!-- openclaw-memory-promotion:memory:memory/2026-07-24.md:5:8 -->
- 16:27 CEST — heartbeat recovery check: Host diagnostics: disk 35% used on `/`; 9.3 GiB RAM available; CPU 87% idle. No host-capacity issue detected.; `journalctl -n 2000` shows recurring OpenRouter/API configuration failures. `openrouter/auto` returns HTTP 404 (no endpoint matches the guardrail/data policy), and fallback `openai/gpt-5.6-sol` is inaccessible to the project.... [score=0.812 recalls=0 avg=0.620 source=memory/2026-07-24.md:5-8]
<!-- openclaw-memory-promotion:memory:memory/2026-07-24.md:9:9 -->
- 16:27 CEST — heartbeat recovery check: Open point: an agent/session with Gateway and `ops-hub` visibility must correct the model routing/access configuration and run the listed Gateway checks. [score=0.812 recalls=0 avg=0.620 source=memory/2026-07-24.md:9-9]
<!-- openclaw-memory-promotion:memory:memory/2026-07-24.md:13:16 -->
- 23:12 CEST — heartbeat recovery check: Host diagnostics remain healthy: root disk 35% used, 9.6 GiB RAM available, load average 1.31 / 1.19 / 1.16, and CPU 86% idle.; The recurring model-routing failures persist: `openrouter/auto` returns HTTP 404 due to guardrail/data-policy restrictions, while fallback `openai/gpt-5.6-sol` is inaccessible to the project. This again failed the `knecht` heartbeat lane.; Attempting the required OpenClaw diagnostics from this sandbox exposed an additional restriction: `openclaw doctor --yes` cannot write its health state because the platform state database is read-only.... [score=0.812 recalls=0 avg=0.620 source=memory/2026-07-24.md:13-16]

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
