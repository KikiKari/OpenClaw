#!/usr/bin/env python3
# abstraction-provenance: {"artifact_sha256": "39953a20a2404a1543b7967ccc14a4478dda5359198ed3ad9a5934e9cfbc62b5", "source_sha256": "a1805aea1655d2760f0aa6fe9d137718ec6b67c1eb8b7d25c2b93d461eea3215", "target_language": "python"}
# build-docs-list.mjs — portiert nach python
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-docs-list.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

import os
import stat
from pathlib import Path

root = Path(__file__).resolve().parent.parent
bin_dir = root / "bin"
bin_path = bin_dir / "docs-list"

bin_dir.mkdir(parents=True, exist_ok=True)

wrapper = '''#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const script = path.join(here, "..", "scripts", "docs-list.js");

const result = spawnSync(process.execPath, [script], { stdio: "inherit" });
process.exit(result.status ?? 1);
'''

with open(bin_path, "w") as f:
    f.write(wrapper)

os.chmod(bin_path, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)
