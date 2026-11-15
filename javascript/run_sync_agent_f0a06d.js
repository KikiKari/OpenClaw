#!/usr/bin/env node
// abstraction-provenance: {"artifact_sha256": "f204977a07bd5016fc743113b0336d8acc6a31fd67092b493b84ceaa3679c37a", "source_sha256": "f0a06da41ce49899ff38006fbb000208dc616b2b3aa7114e02d1872712549a43", "target_language": "javascript"}
// run_sync_agent.py — portiert nach javascript
// Quelle: python, gateway-workspace
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

'use strict';

// The downstream sync agent is Python; preserve its source path and arguments.
const { spawnSync } = require('child_process');
const launcher = `import sys
src = "/workspace/skills/clawhub-git-sync-agent/scripts/sync_agent.py"
sys.path.insert(0, "/workspace/scripts")
with open(src) as stream:
    code = stream.read().replace("/home/openclaw/.openclaw/workspace", "/workspace")
sys.argv = [src] + sys.argv[1:]
exec(compile(code, src, "exec"), {"__name__": "__main__", "__file__": src})`;
const result = spawnSync('python3', ['-c', launcher, ...process.argv.slice(2)], { stdio: 'inherit' });
if (result.error) {
  console.error(result.error.message);
  process.exit(1);
}
process.exit(result.status === null ? 1 : result.status);
