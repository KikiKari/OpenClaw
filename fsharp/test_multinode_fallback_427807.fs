// abstraction-provenance: {"artifact_sha256": "9482eb3695aa76fc9227cd2902c05791717189ab826696b40bd345c6e63f8cb8", "source_sha256": "427807a362e6e00a5a3186533edce544430f9f5097e6eda1d8dac1a6ffaf2107", "target_language": "fsharp"}
// test_multinode_fallback.py — portiert nach fsharp
// Quelle: python, workspace@local:scripts/test_multinode_fallback.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

// Testet Multi-Node Fallback-Logik des db-maintainer
// Simuliert: Worker-Node nicht erreichbar → Fallback auf lokal

open System
open System.Diagnostics
open System.IO
open Newtonsoft.Json.Linq

let WORKSPACE = "/home/openclaw/.openclaw/workspace"

let checkNodeReachable (nodeId: string) =
    // Prüft den Verbindungseintrag dieses Nodes, nicht die Gesamtausgabe.
    let aliases = set [nodeId.ToLower()]
    let node2Names = set ["openclaw-node2"; "arm64-node"; "v2202604104722449961"; "v2202604104722449961.taild25fea.ts.net"]
    let aliases = 
        if node2Names |> Set.contains (nodeId.ToLower()) then
            Set.union aliases node2Names
        else
            aliases
    
    try
        let startInfo = ProcessStartInfo("openclaw", "nodes status --json")
        startInfo.UseShellExecute <- false
        startInfo.RedirectStandardOutput <- true
        startInfo.RedirectStandardError <- true
        
        use proc = Process.Start(startInfo)
        proc.WaitForExit(10000) |> ignore
        
        if proc.ExitCode <> 0 then
            false
        else
            let output = proc.StandardOutput.ReadToEnd()
            let payload = JObject.Parse(output)
            let nodes = payload.["nodes"] :?> JArray
            
            nodes
            |> Seq.exists (fun node ->
                match node with
                | :? JObject as nodeObj ->
                    let displayName = 
                        match nodeObj.TryGetValue("displayName") with
                        | true, value -> value.ToString().ToLower()
                        | _ -> ""
                    
                    let connected = 
                        match nodeObj.TryGetValue("connected") with
                        | true, value -> value.ToObject<bool>()
                        | _ -> false
                    
                    aliases |> Set.contains displayName && connected
                | _ -> false
            )
    with
    | :? Exception -> false

let spawnOnNode (nodeId: string) (task: string) =
    // Versucht Task auf Node auszuführen
    printfn $"Versuche Task auf Node {nodeId} zu starten..."
    try
        // Simuliert: openclaw agent spawn --node {node_id}
        let startInfo = ProcessStartInfo("echo", $"Spawned on {nodeId}: {task}")
        startInfo.UseShellExecute <- false
        startInfo.RedirectStandardOutput <- true
        startInfo.RedirectStandardError <- true
        
        use proc = Process.Start(startInfo)
        proc.WaitForExit(5000) |> ignore
        
        printfn $"✅ Erfolgreich delegiert an {nodeId}"
        true
    with
    | ex ->
        printfn $"❌ Node {nodeId} nicht erreichbar: {ex.Message}"
        false

let executeLocally (task: string) =
    // Führt Task lokal aus (Fallback)
    printfn "🔄 Fallback: Führe Task lokal aus..."
    try
        if task = "db_maintainer" then
            let scriptPath = Path.Combine(WORKSPACE, "skills", "db-maintainer", "scripts", "db_maintainer.py")
            let startInfo = ProcessStartInfo("python3", scriptPath)
            startInfo.UseShellExecute <- false
            startInfo.RedirectStandardOutput <- true
            startInfo.RedirectStandardError <- true
            
            use proc = Process.Start(startInfo)
            proc.WaitForExit(60000) |> ignore
            
            if proc.ExitCode = 0 then
                printfn "✅ Lokale Ausführung erfolgreich"
                true
            else
                let error = proc.StandardError.ReadToEnd()
                printfn $"❌ Fehler: {error.Substring(0, min 200 error.Length)}"
                false
        else
            false
    with
    | ex ->
        printfn $"❌ Lokale Ausführung fehlgeschlagen: {ex.Message}"
        false

let main () =
    printfn "============================================================"
    printfn "MULTI-NODE FALLBACK TEST"
    printfn "============================================================"
    printfn ""
    
    // Konfiguration
    let primaryNode = "v2202604104722449961.taild25fea.ts.net"  // Node 2
    let task = "db_maintainer"
    
    printfn $"Primärer Node: {primaryNode}"
    printfn $"Task: {task}"
    printfn ""
    
    // 1. Prüfe Node-Erreichbarkeit
    printfn "--- 1. Prüfe Node-Erreichbarkeit ---"
    if checkNodeReachable primaryNode then
        printfn $"✅ Node {primaryNode} ist erreichbar"
        
        // 2. Versuche Delegation
        printfn "\n--- 2. Versuche Delegation ---"
        if spawnOnNode primaryNode task then
            printfn "\n✅ MULTI-NODE: Task erfolgreich delegiert"
            0
        else
            printfn "\n⚠️ Delegation fehlgeschlagen, aktiviere Fallback..."
            1
    else
        printfn $"❌ Node {primaryNode} nicht erreichbar"
        printfn "🔄 Fallback wird aktiviert..."
        1
    |> fun result ->
        if result = 1 then
            // 3. Lokale Ausführung (Fallback)
            printfn "\n--- 3. Lokale Ausführung (Fallback) ---"
            if executeLocally task then
                printfn "\n✅ FALLBACK: Task lokal erfolgreich ausgeführt"
                0
            else
                printfn "\n❌ FEHLER: Weder Delegation noch Fallback erfolgreich"
                1
        else
            result

[<EntryPoint>]
let entryPoint args =
    main ()
