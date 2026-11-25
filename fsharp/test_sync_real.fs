// abstraction-provenance: {"artifact_sha256": "3a8771769482c6af9935467f8710e3659833853ea30adb6b5116175fcfe9b052", "source_sha256": "f8c56b5aecfa8cd091cc5fe50697c5613148d19f0d4e0eb311bf6d129c600018", "target_language": "fsharp"}
// test_sync_real.py — portiert nach fsharp
// Quelle: python, OpenClaw@gateway1:scripts/test_sync_real.py
// auch in: OpenClaw@gateway2:scripts/test_sync_real.py
// auch in: workspace@local:scripts/test_sync_real.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

// Test echte Synchronisation

#load "/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.fsx"

open System
open System.IO

// Test: db-maintainer ClawHub → Git (ECHT)
printfn "=== TEST: db-maintainer sync (REAL) ==="
let skill = "db-maintainer"
let result = sync_clawhub_git.sync_to_git skill false
printfn $"Result: %s{(if result then "SUCCESS" else "FAILED")}"

// Prüfe Ergebnis
let target = "/home/openclaw/.openclaw/workspace/git/skills/db-maintainer"
if Directory.Exists(target) then
    printfn $"\n✅ Git-Repo erstellt: {target}"
    let rec printDir level (dirInfo: DirectoryInfo) =
        let indent = String(' ', 2 * level)
        printfn $"{indent}{dirInfo.Name}/"
        let subindent = String(' ', 2 * (level + 1))
        for file in dirInfo.GetFiles() do
            printfn $"{subindent}{file.Name}"
        for subdir in dirInfo.GetDirectories() do
            printDir (level + 1) subdir
    printDir 0 (DirectoryInfo(target))
