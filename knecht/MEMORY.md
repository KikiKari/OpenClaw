# Long-Term Memory


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

## Promoted From Short-Term Memory (2026-08-10)

<!-- openclaw-memory-promotion:memory:memory/2026-08-04.md:5:8 -->
- Heartbeat recovery check (16:26–16:31 CEST): Host healthy: root filesystem 36% used; 11 GiB available RAM; load 0.95; 96% CPU idle; no swap or I/O pressure.; Gateway is active and reachable; one paired node is connected.; Repeated model-routing failure remains: primary `openrouter/openrouter/auto` returns HTTP 404 ("All providers have been ignored") and the first fallback `openai/gpt-5.6-sol` is unavailable to the configured project.... [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-04.md:5-8]
<!-- openclaw-memory-promotion:memory:memory/2026-08-04.md:9:11 -->
- Heartbeat recovery check (16:26–16:31 CEST): Session maintenance completed: main store now has 34 entries and 19 unreferenced artifacts were pruned; all agent stores were cleaned.; `memory index --force` updated `main` and `ops-hub` then made no progress/output and was interrupted after two minutes; remaining agents were not indexed in this run.; Required notification to `ops-hub` was attempted but blocked: `sessions_send` returned `forbidden` because `agent:ops-hub:main` is not visible from this sandboxed session. [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-04.md:9-11]

## Promoted From Short-Term Memory (2026-08-12)

<!-- openclaw-memory-promotion:memory:memory/2026-08-06.md:3:3 -->
- 19:27 CEST heartbeat: host diagnostics normal (root disk 36% used, 12 GiB available memory, CPU 96% idle). Repeated OpenClaw model-routing failures found in journal: `openrouter/openrouter/auto` returns 404 (all providers ignored) and fallback `openai/gpt-5.6-sol` is unauthorized, causing heartbeat lane failures. Attempted to notify `ops-hub`; delivery was forbidden because its session is not visible from this sandboxed agent session. [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-06.md:3-3]

## Promoted From Short-Term Memory (2026-08-13)

<!-- openclaw-memory-promotion:memory:memory/2026-08-07.md:3:6 -->
- Heartbeat recovery — 2026-08-07 13:28 CEST: Host health normal: root disk 36% used (176G / 495G), 13 GiB available RAM, load average 0.26 / 0.19 / 0.17, no swap activity.; Gateway is active and reachable on loopback; paired node is connected.; Repeated model-selection failure observed: primary `openrouter/openrouter/auto` returns 404 for tool-use requests; fallback `openai/gpt-5.6-sol` is unauthorized for the project. Affected sessions have successfully selected `openai/gpt-5.6-terra` as fallback.... [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-07.md:3-6]
<!-- openclaw-memory-promotion:memory:memory/2026-08-07.md:7:8 -->
- Heartbeat recovery — 2026-08-07 13:28 CEST: Ran required `openclaw sessions cleanup --enforce`: 34 current entries; 16 unreferenced artifacts pruned.; Attempted to notify `ops-hub` through its configured session; delivery was forbidden because this sandboxed agent session cannot view `agent:ops-hub:main`. [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-07.md:7-8]
<!-- openclaw-memory-promotion:memory:memory/2026-08-07.md:12:14 -->
- Heartbeat recovery — 2026-08-07 16:27 CEST: Host health remains normal: root disk 36% used, 13 GiB available RAM, load average 0.26 / 0.14 / 0.22, with no swap, CPU, or I/O pressure.; The same OpenClaw model-routing issue remains in the journal: `openrouter/openrouter/auto` returns 404 for tool-use requests; `openai/gpt-5.6-sol` is unauthorized, before fallback to `openai/gpt-5.6-terra` succeeds.; Required gateway diagnostics could not be run: the gateway execution target is not permitted for this session. A retry to notify `ops-hub` was also forbidden because `agent:ops-hub:main` is not visible from this sandboxed agent session. [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-07.md:12-14]
<!-- openclaw-memory-promotion:memory:memory/2026-08-07.md:18:21 -->
- Heartbeat recovery — 2026-08-07 20:12 CEST: Host health normal: root disk 36% used, 13 GiB available RAM, load average 0.46 / 0.30 / 0.32, no swap, and no CPU or I/O pressure.; The persistent model-routing failure is still occurring: `openrouter/openrouter/auto` returns HTTP 404 for tool-use requests, then `openai/gpt-5.6-sol` is unauthorized for the project; `openai/gpt-5.6-terra` ultimately succeeds.; `openclaw doctor --yes` additionally reported an Anthropic CLI auth token for agent `claude` expiring in about 4 hours, one missing recent-session transcript, 645 orphan transcripts, stale disabled `memory-lancedb` configuration,... [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-07.md:18-21]
<!-- openclaw-memory-promotion:memory:memory/2026-08-07.md:25:28 -->
- Heartbeat recovery — 2026-08-07 23:12 CEST: Host health normal: root disk 36% used, 12 GiB available RAM, load average 1.21 / 0.82 / 0.65, no swap, and no CPU or I/O pressure.; Gateway is active and reachable; the paired node is connected. The persistent model-routing failure remains: primary `openrouter/openrouter/auto` returns HTTP 404 for tool-use requests, and `openai/gpt-5.6-sol` is unauthorized; `openai/gpt-5.6-terra` succeeds as a fallback.; Ran prescribed recovery checks and maintenance: `openclaw doctor --yes` removed redundant bundled plugin aliases and refreshed the stale Codex plugin; `openclaw doctor --force`, forced... [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-07.md:25-28]
<!-- openclaw-memory-promotion:memory:memory/2026-08-07.md:29:29 -->
- Heartbeat recovery — 2026-08-07 23:12 CEST: Attempt to notify `ops-hub` was forbidden because `agent:ops-hub:main` is not visible from this sandboxed session. [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-07.md:29-29]

## Promoted From Short-Term Memory (2026-08-14)

<!-- openclaw-memory-promotion:memory:memory/2026-08-08.md:3:5 -->
- 15:42 CEST — heartbeat recovery check: Host diagnostics healthy: root disk 36% used; ~12 GiB RAM available; load average 1.05/0.44/0.33; no CPU, I/O, or swap pressure.; Journal reports recurring OpenRouter HTTP 402 insufficient-credit failures. Failover then selects `openai/gpt-5.6-sol`, which the project cannot access; affected heartbeat runs include `knecht` at 15:41.; Attempted to notify `ops-hub` through its configured session, but access was forbidden because `agent:ops-hub:main` is not visible from this sandboxed session. Escalation remains pending. [score=0.812 recalls=0 avg=0.620 source=memory/2026-08-08.md:3-5]
