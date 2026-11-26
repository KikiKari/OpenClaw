// abstraction-provenance: {"artifact_sha256": "78a38a678e3d0058b5fa0a74e6cbbd7056c1a2e0e43df86ab2376081a505cf29", "source_sha256": "2a9ca592fdc915cfb281aa77dde9f07ffd3de83ce5abb8d87c77d46668d75dd6", "target_language": "fsharp"}
// openclaw-maintenance.sh — portiert nach fsharp
// Quelle: shell, OpenClaw@gateway1:scripts/openclaw-maintenance.sh
// auch in: workspace@local:scripts/openclaw-maintenance.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

// openclaw-maintenance.fsx

open System

let runOpenClawCommand (command: string) =
    let psi = System.Diagnostics.ProcessStartInfo()
    psi.FileName <- "openclaw"
    psi.Arguments <- command
    psi.UseShellExecute <- false
    psi.RedirectStandardOutput <- true
    psi.RedirectStandardError <- true
    
    use proc = System.Diagnostics.Process.Start(psi)
    proc.WaitForExit()
    
    if proc.ExitCode <> 0 then
        let error = proc.StandardError.ReadToEnd()
        failwith $"Command 'openclaw {command}' failed with exit code {proc.ExitCode}: {error}"

// === 1. Service-/Config-Drift ===
runOpenClawCommand "doctor"

// === 2. Plugin-Stage (aktive Varianten, NICHT plugins doctor) ===
runOpenClawCommand "plugins registry --refresh"
runOpenClawCommand "plugins update --all"

// === 3. Tasks ===
runOpenClawCommand "tasks maintenance --apply"

// === 4. Sessions – alle Agents auf einmal ===
runOpenClawCommand "sessions cleanup --enforce --all-agents"

// === 5. Memory – status/index decken alle Agents ab ===
runOpenClawCommand "memory status --deep --fix"
runOpenClawCommand "memory index --force"

// === 6. Memory promote – MUSS pro Agent ===
["main"; "knecht"; "docs"; "ops-hub"; "cron"]
|> List.iter (fun agent -> 
    runOpenClawCommand $"memory promote --apply --agent \"{agent}\"")

// === 7. Secrets ===
runOpenClawCommand "secrets reload"
