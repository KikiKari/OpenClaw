// abstraction-provenance: {"artifact_sha256": "92fc1b521922576cdeb167d72a367fae97fa900d42c5ff2c3e39ccd2185e161f", "source_sha256": "a77f5c2629fe7fafac268cfbf2f0b3e77a194322aee8f9c06967eb6c33db043e", "target_language": "fsharp"}
// openclaw-maintenance.sh — portiert nach fsharp
// Quelle: shell, OpenClaw@gateway2:scripts/openclaw-maintenance.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

open System
open System.Diagnostics

let openclawBin = 
    match Environment.GetEnvironmentVariable("OPENCLAW_BIN") with
    | null -> Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData) + "/bin/openclaw"
    | path -> path

let runCommand cmd args =
    let startInfo = ProcessStartInfo(cmd, args)
    startInfo.UseShellExecute <- false
    startInfo.RedirectStandardOutput <- true
    startInfo.RedirectStandardError <- true
    
    use proc = Process.Start(startInfo)
    proc.WaitForExit()
    
    if proc.ExitCode <> 0 then
        failwith $"Command failed: {cmd} {args}"
    proc.StandardOutput.ReadToEnd()

// Check if binary exists and is executable
if not (System.IO.File.Exists(openclawBin)) then
    eprintfn "ERROR: OpenClaw binary not found: %s" openclawBin
    exit 1

try
    // Display version
    let version = runCommand openclawBin "--version"
    printfn "Using OpenClaw: %s" version

    // === 1. Service-/Config-Drift ===
    runCommand openclawBin "doctor" |> ignore

    // === 2. Plugin-Stage (Registry refresh only; updates are explicit/manual) ===
    runCommand openclawBin "plugins registry --refresh" |> ignore
    
    match Environment.GetEnvironmentVariable("RUN_PLUGIN_UPDATE") with
    | "1" -> 
        runCommand openclawBin "plugins update --all" |> ignore
    | _ -> 
        printfn "Skipping plugin update. Run with RUN_PLUGIN_UPDATE=1 to enable."

    // === 3. Tasks ===
    runCommand openclawBin "tasks maintenance --apply" |> ignore

    // === 4. Sessions – alle Agents auf einmal ===
    runCommand openclawBin "sessions cleanup --enforce --all-agents" |> ignore

    // === 5. Memory – status/index decken alle Agents ab ===
    runCommand openclawBin "memory status --deep --fix" |> ignore
    runCommand openclawBin "memory index --force" |> ignore

    // === 6. Memory promote – MUSS pro Agent ===
    for agent in ["main"; "knecht"; "docs"; "ops-hub"; "cron"] do
        runCommand openclawBin $"memory promote --apply --agent {agent}" |> ignore

    // === 7. Secrets ===
    runCommand openclawBin "secrets reload" |> ignore

with
| ex -> 
    eprintfn "Error: %s" ex.Message
    exit 1
