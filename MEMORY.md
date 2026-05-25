# MEMORY.md

*No entries yet. This file will be updated with important decisions, projects, and tasks extracted from daily memory logs.*

## 2026-05-24 Updates

- **Decision:** Prioritize porting scripts from `skills/` and `scripts/` into alternative languages. High priority: `skill-creator`, `json-utils`, `scripting-utils`. Medium priority: other workspace scripts. Low priority: remaining scripts.
- **Project:** Port scripts to alternative languages (Perl5, Raku, JS, Python, Bash, PowerShell, Tcl, Ruby, Lua, Go).
- **ToDo:** Schedule and execute script porting; track progress; commit changes to repository.
- **Cron Job Added:** Archive old memory files (>30 days) daily at 02:00 Europe/Berlin.


## Recent Updates (2026-05-22-23)

## 2026-05-25 Updates

- **Decision:** Created cron job "Portiere_Scripte" to run every 6 hours for script porting.
- **Project:** Script porting automation via abstractions_manager.py.
- **ToDo:** Monitor cron job execution; ensure Git commits after each batch.

- **Project:** Initiated manual run of `clawhub-git-sync` cron job to perform bidirectional sync between ClawHub and Git. (2026-05-22)
- **Task:** Pending execution of `abstractions_manager.py` script and subsequent Git commit for porting scripts. (2026-05-23)

## Promoted From Short-Term Memory (2026-05-23)

<!-- openclaw-memory-promotion:memory:memory/2026-05-17-0217.md:18:21 -->
- Continue the task if needed, then reply to the user in a helpful way. If it succeeded, share the relevant output. If it failed, explain what went wrong. user: [Sun 2026-05-17 02:15 GMT+2] An async command the user already approved has completed. [score=0.814 recalls=0 avg=0.620 source=memory/2026-05-17-0217.md:18-21]
<!-- openclaw-memory-promotion:memory:memory/2026-05-17-0217.md:22:24 -->
- Do not run the command again. If the task requires more steps, continue from this result before replying to the user. Only ask the user for help if you are actually blocked. [score=0.814 recalls=0 avg=0.620 source=memory/2026-05-17-0217.md:22-24]
<!-- openclaw-memory-promotion:memory:memory/2026-05-17-0217.md:26:27 -->
- Exact completion details: Exec finished (gateway id=1faef2c7-ae69-4324-93e4-d0e155186217, session=lucky-dune, code 0) [score=0.814 recalls=0 avg=0.620 source=memory/2026-05-17-0217.md:26-27]

## Promoted From Short-Term Memory (2026-05-24)

<!-- openclaw-memory-promotion:memory:memory/2026-05-17-0217.md:9:12 -->
- user: [Sun 2026-05-17 02:15 GMT+2] An async command the user already approved has completed. Do not run the command again. If the task requires more steps, continue from this result before replying to the user. [score=0.824 recalls=0 avg=0.620 source=memory/2026-05-17-0217.md:9-11]
<!-- openclaw-memory-promotion:memory:memory/2026-05-17-0217.md:14:16 -->
- Exact completion details: Exec finished (gateway id=27f05cdc-2b52-4c15-be41-aef6a5d2c82e, session=quick-summit, code 0) /home/openclaw/.openclaw/logs: commands.log config-audit.jsonl config-health.json gateway-restart.log [score=0.824 recalls=0 avg=0.620 source=memory/2026-05-17-0217.md:14-16]
