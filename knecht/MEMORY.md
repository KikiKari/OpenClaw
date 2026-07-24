# Long-Term Memory


## Promoted From Short-Term Memory (2026-07-23)

<!-- openclaw-memory-promotion:memory:memory/2026-07-18-0127.md:3:5 -->
- Heartbeat — 2026-07-18 01:27 CEST: Host diagnostics were healthy: root disk 34% used; 11 GiB memory available; load average 1.11/0.68/0.81; CPU 90% idle.; Recent gateway logs repeatedly reported `openrouter/openrouter/auto` as unavailable (HTTP 404 / guardrail restrictions), followed by unavailable fallback `openai/gpt-5.6-sol`. The subsequent fallback to `openai/gpt-5.6-terra` succeeded.; Required follow-up could not be completed from this heartbeat: gateway execution is disallowed by session policy, and `ops-hub` is not visible to this sandboxed agent session (message send forbidden). Escalate to ops-hub when reachable. [score=0.812 recalls=0 avg=0.620 source=memory/2026-07-18-0127.md:3-5]

## Promoted From Short-Term Memory (2026-07-24)

<!-- openclaw-memory-promotion:memory:memory/2026-07-18-1242.md:3:6 -->
- Heartbeat — 2026-07-18 12:42 CEST: Host diagnostics are healthy: root disk 34% used; 12 GiB memory available; load average 0.96/0.45/0.33; CPU 90% idle.; Gateway logs continue to show the known model-routing fault: `openrouter/openrouter/auto` is rejected with HTTP 404 due to guardrail/data-policy restrictions, and fallback `openai/gpt-5.6-sol` is unauthorized. Fallback to `openai/gpt-5.6-terra` succeeds.; Required escalation to `ops-hub` was attempted but forbidden because `agent:ops-hub:main` is not visible to this sandboxed session.... [score=0.844 recalls=0 avg=0.620 source=memory/2026-07-18-1242.md:3-6]
<!-- openclaw-memory-promotion:memory:memory/2026-07-18-1242.md:7:8 -->
- Heartbeat — 2026-07-18 12:42 CEST: 20:57 CEST recheck: host remains healthy (root disk 35%; 10 GiB memory available; load 1.16/1.23/1.19; CPU 89% idle). The routing fault recurred: `openrouter/openrouter/auto` returned HTTP 404 (no matching endpoint under guardrail/data-policy restrictions) and `openai/gpt-5.6-sol` is not authorized; fallback `openai/gpt-5.6-terra` succeeds. Escalation to `ops-hub` was forbidden because that session is not visible, and the prescribed Gateway diagnostics could not run because Gateway host override is disallowed.... [score=0.844 recalls=0 avg=0.620 source=memory/2026-07-18-1242.md:7-8]
