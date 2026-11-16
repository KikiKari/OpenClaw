#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "22cb12518465fb7805f3dc2fad548f46d516a568a2726b95b0e925de704bf7ca", "source_sha256": "a1805aea1655d2760f0aa6fe9d137718ec6b67c1eb8b7d25c2b93d461eea3215", "target_language": "ruby"}
# build-docs-list.mjs — portiert nach ruby
# Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-docs-list.mjs
# Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

require 'fileutils'
require 'pathname'

root = File.expand_path('..', __dir__)
bin_dir = File.join(root, 'bin')
bin_path = File.join(bin_dir, 'docs-list')

FileUtils.mkdir_p(bin_dir)

wrapper = <<~WRAPPER
  #!/usr/bin/env node
  import { spawnSync } from "node:child_process";
  import path from "node:path";
  import { fileURLToPath } from "node:url";

  const here = path.dirname(fileURLToPath(import.meta.url));
  const script = path.join(here, "..", "scripts", "docs-list.js");

  const result = spawnSync(process.execPath, [script], { stdio: "inherit" });
  process.exit(result.status ?? 1);
WRAPPER

File.write(bin_path, wrapper)
File.chmod(0o755, bin_path)
