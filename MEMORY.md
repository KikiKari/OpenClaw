# MEMORY.md

[2026-06-13] Heartbeat poll received. No pending tasks or alerts.

[2026-06-15] ARCHIVE_MEMORY reminder handled. No memory files older than 30 days were found, so nothing was archived.

[2026-06-07] Daily memory maintenance performed. No new decisions, projects, or tasks found in yesterday's or today's logs.

[2026-05-30] Daily memory maintenance performed. No new decisions, projects, or tasks found in yesterday's or today's logs. Archived memory files older than 30 days (none found). All clear.

[2026-05-29] ARCHIVE_MEMORY reminder handled: old memory files (>30 days) should be archived. (Manual archiving pending)

*No entries yet. This file will be updated with important decisions, projects, and tasks extracted from daily memory logs.*

[2026-05-28] Executed ARCHIVE_MEMORY reminder: logged archiving timestamp and noted completion. Future archiving will compress older daily logs (>30 days) into archive folder.

## 2026-05-24 Updates

- **Decision:** Prioritize porting scripts from `skills/` and `scripts/` into alternative languages. High priority: `skill-creator`, `json-utils`, `scripting-utils`. Medium priority: other workspace scripts. Low priority: remaining scripts.
- **Project:** Port scripts to alternative languages (Perl5, Raku, JS, Python, Bash, PowerShell, Tcl, Ruby, Lua, Go).
- **ToDo:** Schedule and execute script porting; track progress; commit changes to repository.
- **Cron Job Added:** Archive old memory files (>30 days) daily at 02:00 Europe/Berlin.


## Recent Updates (2026-05-22-23)

## 2026-05-26 Updates

- **Decision:** Continue script porting task; prioritize high‑priority items (`skill-creator`, `json‑utils`, `scripting‑utils`).
- **Project:** Run cron job "Portiere_Scripte" every 6 hours to execute `abstractions_manager.py` and advance script porting to alternative languages (Perl5, Raku, JS, Python, Bash, PowerShell, Tcl, Ruby, Lua, Go).
- **ToDo:** Monitor cron job execution, ensure Git commits after each batch, and report any failures.


## 2026-05-25 Updates

- **Decision:** Created cron job "Portiere_Scripte" to run every 6 hours for script porting.
- **Project:** Script porting automation via abstractions_manager.py.
- **ToDo:** Monitor cron job execution; ensure Git commits after each batch.

- **Project:** Initiated manual run of `clawhub-git-sync` cron job to perform bidirectional sync between ClawHub and Git. (2026-05-22)
- **Task:** Pending execution of `abstractions_manager.py` script and subsequent Git commit for porting scripts. (2026-05-23)

## Archive: 2026-05-27 (automated)

- 2026-05-25 09:37 — TikTok extraction session: attempted to extract direct stream for `@marry_live`; no FLV URL found. Likely causes: age/region restrictions, short capture window, or creator privacy settings. Recommended next steps: retry with a longer capture window, run with logged-in TikTok cookies, or open the `/live` page directly (e.g., `mpv "https://www.tiktok.com/@marry_live/live"`). Note: visual live-badge checks can be false positives; augment with network or yt-dlp checks.

- 2026-05-25 — Created cron job `Portiere_Scripte` to run every 6 hours, executing `abstractions_manager.py` to orchestrate script-porting work.

- 2026-05-26 — Handled internal reminder to port scripts across multiple languages (Perl5, Raku, JS, Python, Bash, PowerShell, Tcl, Ruby, Lua, Go). Priorities: High — `skill-creator`, `json-utils`, `scripting-utils`; Medium — workspace scripts; Low — others. Commits will be made after each batch. Reference: `./skills/script-abstractions-manager/scripts/abstractions_manager.py`.

## 2026-05-28 Updates

- **Decision:** Execution of `abstractions-publish-gateway` script pending due to missing approval.
- **Project:** Publish abstractions to gateway.
- **ToDo:** Obtain required approval and run the script; schedule execution after approval.


## Promoted From Short-Term Memory (2026-07-02)

<!-- openclaw-memory-promotion:memory:memory/2026-06-26-0010.md:3:5 -->
- Session: 2026-06-26 00:10:49 GMT+2: **Session Key**: agent:main:main; **Session ID**: 92b6a78b-5354-4b0d-ac8d-7bf2b2af1912; **Source**: webchat [score=0.893 recalls=0 avg=0.620 source=memory/2026-06-26-0010.md:3-5]
<!-- openclaw-memory-promotion:memory:memory/2026-06-26-0010.md:9:12 -->
- Conversation Summary: assistant: ✅ Session reset. assistant: ⚙️ Reasoning visibility enabled. assistant: 🦞 OpenClaw 2026.6.10 (aa69b12) ⏱️ Uptime: gateway 5m 40s · system 12d 10h [score=0.893 recalls=0 avg=0.620 source=memory/2026-06-26-0010.md:9-12]
<!-- openclaw-memory-promotion:memory:memory/2026-06-25-2325.md:13:13 -->
- Conversation Summary: For example, would you like me to: [score=0.886 recalls=0 avg=0.620 source=memory/2026-06-25-2325.md:13-13]
<!-- openclaw-memory-promotion:memory:memory/2026-06-25-2325.md:14:16 -->
- Conversation Summary: Check if `@iman.hayatiii` is currently live?; Monitor `@iman.hayatiii`'s channel for future live streams?; Retrieve information about their account? [score=0.886 recalls=0 avg=0.620 source=memory/2026-06-25-2325.md:14-16]
<!-- openclaw-memory-promotion:memory:memory/2026-06-25-2325.md:18:21 -->
- Conversation Summary: Please provide more details on what you'd like to do with the "tiktok-live" skill. assistant: [[reply_to:eea08e52-e99d-4521-af7b-c06255d01b4f]]Audio reply assistant: I couldn't find any direct information indicating that `@iman.hayatiii` is currently live on TikTok through a quick web search. The search results were for general TikTok LIVE streams and not specific to that user. assistant: [[reply_to:d2ddd994-cb34-475b-94e6-f41b660e2d2b]]Audio reply [score=0.886 recalls=0 avg=0.620 source=memory/2026-06-25-2325.md:18-21]
<!-- openclaw-memory-promotion:memory:memory/2026-06-25-2325.md:22:22 -->
- Conversation Summary: assistant: I can use the `tiktok-live-mon` skill to monitor `@iman.hayatiii`'s TikTok account. [score=0.886 recalls=0 avg=0.620 source=memory/2026-06-25-2325.md:22-22]
<!-- openclaw-memory-promotion:memory:memory/2026-06-25-2325.md:3:5 -->
- Session: 2026-06-25 23:25:39 GMT+2: **Session Key**: agent:main:main; **Session ID**: 91a21436-9118-4ca2-9424-be0a0759f9f4; **Source**: webchat [score=0.886 recalls=0 avg=0.620 source=memory/2026-06-25-2325.md:3-5]
<!-- openclaw-memory-promotion:memory:memory/2026-06-25-2325.md:9:11 -->
- Conversation Summary: assistant: Could you please specify what you'd like to do with the TikTok Live skill and the username `@iman.hayatiii`? For example, are you trying to watch a live stream, get information about a user, or something else? assistant: [[reply_to:48b1cfca-47c2-46e1-b36f-9b315fcf0960]]Audio reply assistant: I understand you'd like to use the "tiktok-live" skill for the username `@iman.hayatiii`. However, I need to know what specific action you want to perform. [score=0.886 recalls=0 avg=0.620 source=memory/2026-06-25-2325.md:9-11]
<!-- openclaw-memory-promotion:memory:memory/2026-06-25-2340.md:12:15 -->
- Conversation Summary: If you can provide the command or a specific tool function to use, I would be happy to proceed. assistant: I cannot directly execute skills by their names. I need a specific tool or command that allows me to invoke the "tiktok-live" skill. Could you please provide the exact command or tool to use? user: [OpenClaw heartbeat poll] assistant: HEARTBEAT_OK [score=0.886 recalls=0 avg=0.620 source=memory/2026-06-25-2340.md:12-15]
<!-- openclaw-memory-promotion:memory:memory/2026-06-25-2340.md:3:5 -->
- Session: 2026-06-25 23:40:50 GMT+2: **Session Key**: agent:main:main; **Session ID**: 181f587d-cb17-4018-8b3e-afdc34ce225c; **Source**: webchat [score=0.886 recalls=0 avg=0.620 source=memory/2026-06-25-2340.md:3-5]
