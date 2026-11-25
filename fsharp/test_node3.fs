// abstraction-provenance: {"artifact_sha256": "c4a372564857f801623f57c5e75c9dee6a8613504201b26f2ac00f713eb6c95b", "source_sha256": "151279ec3dae16c8f81904c36418b5f9c6040036a0a98adef5ec52bfea0b57ab", "target_language": "fsharp"}
// test_node3.sh — portiert nach fsharp
// Quelle: shell, OpenClaw@gateway1:scripts/test_node3.sh
// auch in: OpenClaw@gateway2:scripts/test_node3.sh
// auch in: workspace@local:scripts/test_node3.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

// Test Node 3 Connection
open System
open System.Diagnostics

let runNodeConnectionTest () =
    // Set environment variable
    Environment.SetEnvironmentVariable("OPENCLAW_ALLOW_INSECURE_PRIVATE_WS", "1")
    
    printfn "Starting node connection test..."
    
    // Create process to run the command
    let psi = ProcessStartInfo()
    psi.FileName <- "/usr/local/bin/openclaw"
    psi.Arguments <- "node run --host 152.53.145.65 --port 18789"
    psi.UseShellExecute <- false
    psi.RedirectStandardOutput <- true
    psi.RedirectStandardError <- true
    
    use process = new Process()
    process.StartInfo <- psi
    
    // Start the process
    process.Start() |> ignore
    
    // Read output and error streams
    let output = process.StandardOutput.ReadToEnd()
    let error = process.StandardError.ReadToEnd()
    
    // Wait for exit or timeout after 15 seconds
    let exited = process.WaitForExit(15000)
    
    if not exited then
        process.Kill()
        process.WaitForExit() |> ignore
        
    // Print output and error
    if not (String.IsNullOrEmpty(output)) then
        printf "%s" output
    if not (String.IsNullOrEmpty(error)) then
        fprintf stderr "%s" error
    
    printfn "Exit code: %d" process.ExitCode
    process.ExitCode

// Run the test
runNodeConnectionTest () |> ignore
