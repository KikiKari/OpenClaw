// abstraction-provenance: {"artifact_sha256": "b185a2f9181ee80dff5a2d21af3a73ae940e719e09133bc67a3a1bb66ad92479", "source_sha256": "a1805aea1655d2760f0aa6fe9d137718ec6b67c1eb8b7d25c2b93d461eea3215", "target_language": "go"}
// build-docs-list.mjs — portiert nach go
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/build-docs-list.mjs
// Erzeugt: 2026-11-16 durch ABSTRACTIONS_MANAGER.py

package main

import (
	"os"
	"path/filepath"
)

func main() {
	// Get the directory of the current script
	_, filename, _, _ := runtime.Caller(0)
	root := filepath.Join(filepath.Dir(filename), "..")
	binDir := filepath.Join(root, "bin")
	binPath := filepath.Join(binDir, "docs-list")

	// Create bin directory recursively
	err := os.MkdirAll(binDir, 0755)
	if err != nil {
		panic(err)
	}

	// Wrapper content as a Go string
	wrapper := `#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const script = path.join(here, "..", "scripts", "docs-list.js");

const result = spawnSync(process.execPath, [script], { stdio: "inherit" });
process.exit(result.status ?? 1);
`

	// Write the wrapper to the file with executable permissions
	err = os.WriteFile(binPath, []byte(wrapper), 0755)
	if err != nil {
		panic(err)
	}
}
