// abstraction-provenance: {"artifact_sha256": "76dbb7a6eb8167c3052b3aa9d84df558eca7fdb901da865340f78fc808a764fb", "source_sha256": "52b3516148b12072bbff77599a6faac284607fbc005a73f93c2b7f4f349cf6f1", "target_language": "fsharp"}
// test_multinode_fallback.py — portiert nach fsharp
// Quelle: python, OpenClaw@gateway1:scripts/test_multinode_fallback.py
// auch in: OpenClaw@gateway2:scripts/test_multinode_fallback.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

// Testet Multi-Node Fallback-Logik des db-maintainer
// Simuliert: Worker-Node nicht erreichbar → Fallback auf lokal

open System
open System.Diagnostics
open System.IO

let WORKSPACE = Path.Combine("/home/openclaw/.openclaw/workspace")

/// Prüft ob Node erreichbar ist
let checkNodeReachable (nodeId: string) : bool =
    try
        // Versuche Node-Status abzufragen
        let psi = ProcessStartInfo("openclaw", "nodes status")
        psi.UseShellExecute <- false
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        let proc = Process.Start(psi)
        if proc.WaitForExit(10000) then
            let output = proc.StandardOutput.ReadToEnd()
            output.Contains(nodeId) && output.Contains("connected")
        else
            false
    with _ ->
        false

/// Versucht Task auf Node auszuführen
let spawnOnNode (nodeId: string) (task: string) : bool =
    printfn $"Versuche Task auf Node {nodeId} zu starten..."
    try
        // Simuliert: openclaw agent spawn --node {node_id}
        let psi = ProcessStartInfo("echo", $"Spawned on {nodeId}: {task}")
        psi.UseShellExecute <- false
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        let proc = Process.Start(psi)
        if proc.WaitForExit(5000) then
            printfn $"✅ Erfolgreich delegiert an {nodeId}"
            true
        else
            printfn $"❌ Node {nodeId} nicht erreichbar: Timeout"
            false
    with ex ->
        printfn $"❌ Node {nodeId} nicht erreichbar: {ex.Message}"
        false

/// Führt Task lokal aus (Fallback)
let executeLocally (task: string) : bool =
    printfn "🔄 Fallback: Führe Task lokal aus..."
    try
        if task = "db_maintainer" then
            let scriptPath = Path.Combine(WORKSPACE, "skills", "db-maintainer", "scripts", "db_maintainer.py")
            let psi = ProcessStartInfo("python3", scriptPath)
            psi.UseShellExecute <- false
            psi.RedirectStandardOutput <- true
            psi.RedirectStandardError <- true
            let proc = Process.Start(psi)
            if proc.WaitForExit(60000) then
                if proc.ExitCode = 0 then
                    printfn "✅ Lokale Ausführung erfolgreich"
                    true
                else
                    let error = proc.StandardError.ReadToEnd()
                    printfn $"❌ Fehler: {error.Substring(0, min 200 error.Length)}"
                    false
            else
                printfn "❌ Fehler: Timeout bei lokaler Ausführung"
                false
        else
            printfn "❌ Unbekannter Task"
            false
    with ex ->
        printfn $"❌ Lokale Ausführung fehlgeschlagen: {ex.Message}"
        false

[<EntryPoint>]
let main argv =
    printfn "============================================================"
    printfn "MULTI-NODE FALLBACK TEST"
    printfn "============================================================"
    printfn ""
    
    // Konfiguration
    let primaryNode = "v2202603104722445775"  // Node 2
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
            // 3. Lokale Ausführung (Fallback)
            printfn "\n--- 3. Lokale Ausführung (Fallback) ---"
            if executeLocally task then
                printfn "\n✅ FALLBACK: Task lokal erfolgreich ausgeführt"
                0
            else
                printfn "\n❌ FEHLER: Weder Delegation noch Fallback erfolgreich"
                1
    else
        printfn $"❌ Node {primaryNode} nicht erreichbar"
        printfn "🔄 Fallback wird aktiviert..."
        
        // 3. Lokale Ausführung (Fallback)
        printfn "\n--- 3. Lokale Ausführung (Fallback) ---"
        if executeLocally task then
            printfn "\n✅ FALLBACK: Task lokal erfolgreich ausgeführt"
            0
        else
            printfn "\n❌ FEHLER: Weder Delegation noch Fallback erfolgreich"
            1
