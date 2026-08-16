---
name: script-abstractions-manager
description: Port source files from the configured KikiKari repositories into six complete, model-generated language implementations. Use for operating, diagnosing, dry-running, or documenting the scheduled OpenClaw abstraction workflow and its gateway1-abstractions output branch.
---

# Script Abstractions Manager

Run the bundled manager as the single implementation of this workflow:

```bash
/home/openclaw/.openclaw/scripts/abstractions-manager-cron.sh --prioritaet high --anzahl 1 --probelauf
```

- Keep `QUELLEN`, `MODELLE`, prompts, validation, and CLI behavior unchanged.
- Read `OPENROUTER_API_KEY` from the server environment; never print or version it.
- Write only to the checkout `workspace/git/OpenClaw-gateway1-abstractions` on branch `gateway1-abstractions`.
- Use `--probelauf` to refresh the inventory without model requests.
- Use `--prioritaet high|medium|low|alle` and `--anzahl N` to bound a live run.
- Treat rejected placeholder output as a failed translation, not as a usable artifact.
- Read `workspace/docs/abstractions/OPERATIONS.md` for backup, scheduling, recovery, and publication details.
