// abstraction-provenance: {"artifact_sha256": "b9c61332bd83194bffdd8e7fe151e3de5a40199ac0b911adf9a5c6829e6e822a", "source_sha256": "daf78be577ece366a1908ac16ff31d6e57298b1256bb88185a5bc1cf5294a804", "target_language": "fsharp"}
// test_sync.py — portiert nach fsharp
// Quelle: python, OpenClaw@gateway1:scripts/test_sync.py
// auch in: OpenClaw@gateway2:scripts/test_sync.py
// auch in: workspace@local:scripts/test_sync.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

// Test für Sync-Script

#load "/home/openclaw/.openclaw/workspace/scripts/sync_clawhub_git.fsx"

open System
open System.IO

// Test: db-maintainer ClawHub → Git (DRY-RUN)
printfn "=== TEST: db-maintainer sync (DRY-RUN) ==="
let skill = "db-maintainer"
let result = sync_to_git skill true
printfn $"Result: %s{(if result then "SUCCESS" else "FAILED")}"
printfn "\n=== LOG-Inhalt ==="
use f = new StreamReader("/home/openclaw/.openclaw/workspace/logs/sync.log")
printfn "%s" (f.ReadToEnd())
