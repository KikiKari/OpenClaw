// abstraction-provenance: {"artifact_sha256": "7ca0cdcee0e7b5c879c0524016d4cccd48467e0572e665bce6c3adc736c1eba3", "source_sha256": "c372bc97113533b0ca2400d318d3cd0e8cd55cea37f0cc563ab714990cc9efb6", "target_language": "fsharp"}
// run_sync_agent.py — portiert nach fsharp
// Quelle: python, OpenClaw@gateway2:scripts/run_sync_agent.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO

[<EntryPoint>]
let main argv =
    // F# does not have sys.path, but we can set the current directory or use reflection
    // to modify the assembly search path if needed. However, for this simple case,
    // we'll just ensure our assemblies are in the correct location or referenced properly.
    
    // Set the working directory to /workspace if needed for relative paths
    Directory.SetCurrentDirectory "/workspace"
    
    // Since F# doesn't support dynamic importing like Python, 
    // we assume sync_agent is compiled into an assembly that's already referenced
    
    // Define constants similar to the Python version
    let WS = "/workspace"
    ClawHubSyncAgent.clawhubDir <- Path.Combine(WS, "skills")
    ClawHubSyncAgent.gitDir <- Path.Combine(WS, "git", "skills")
    ClawHubSyncAgent.stateFile <- Path.Combine(WS, "db", "sync_state.json")
    
    // Call the main function from the module
    ClawHubSyncAgent.main()
    0
