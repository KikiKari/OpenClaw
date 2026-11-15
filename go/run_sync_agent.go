// abstraction-provenance: {"artifact_sha256": "60994ab82838a2df9e47d208075060a017f925724fec43d31c6b76063f29bd25", "source_sha256": "f0a06da41ce49899ff38006fbb000208dc616b2b3aa7114e02d1872712549a43", "target_language": "go"}
// run_sync_agent.py — portiert nach go
// Quelle: python, gateway-workspace
// Erzeugt: 2026-11-15 durch ABSTRACTIONS_MANAGER.py

package main

import (
    "fmt"
    "os"
    "os/exec"
)

// The source is a Python launcher: preserve its exact argv and __file__ behavior.
const launcher = `#!/usr/bin/env python3
"""Launcher: führt sync_agent.py mit Container-Pfaden (/workspace) aus."""
import sys, runpy

SRC = "/workspace/skills/clawhub-git-sync-agent/scripts/sync_agent.py"
sys.path.insert(0, "/workspace/scripts")

with open(SRC) as f:
    code = f.read().replace("/home/openclaw/.openclaw/workspace", "/workspace")

sys.argv = [SRC] + sys.argv[1:]
exec(compile(code, SRC, "exec"), {"__name__": "__main__", "__file__": SRC})
`

func main() {
    args := append([]string{"-c", launcher}, os.Args[1:]...)
    cmd := exec.Command("python3", args...)
    cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
    if err := cmd.Run(); err != nil {
        if exit, ok := err.(*exec.ExitError); ok { os.Exit(exit.ExitCode()) }
        fmt.Fprintln(os.Stderr, err)
        os.Exit(1)
    }
}
