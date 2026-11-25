// abstraction-provenance: {"artifact_sha256": "4baf7d0e682e9abadaa1dbcf414d2abd7039cf76cd06c622a45909fcbe51b1a5", "source_sha256": "9caa03d9bb15f9d91f7e2672653c8c81852b35f9076edf8b7f839f4f06ac7dfd", "target_language": "fsharp"}
// translation-worker-node.sh — portiert nach fsharp
// Quelle: shell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

// Run on the selected node after transferring its native worker. JSON stdin is
// forwarded unchanged to the worker in run mode.
open System
open System.IO
open System.Diagnostics
open System.Security.Cryptography

let sha256sum (filePath: string) : string =
    use sha256 = SHA256.Create()
    use fileStream = File.OpenRead(filePath)
    let hashBytes = sha256.ComputeHash(fileStream)
    BitConverter.ToString(hashBytes).Replace("-", "").ToLowerInvariant()

let main (args: string[]) : int =
    if args.Length <> 2 then
        eprintfn "Usage: translation-worker-node.sh node2|node3|node4|node6 prepare|health|run"
        exit 2

    let node = args.[0]
    let action = args.[1]

    let worker, expected =
        match node with
        | "node2" -> "/home/node/.openclaw/workers/translation-worker", "565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286"
        | "node3" -> "/home/openclaw/.openclaw/workers/translation-worker", "9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de"
        | "node4" -> "/root/.openclaw/workers/translation-worker", "565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286"
        | "node6" -> "/home/node/.openclaw/workers/translation-worker", "9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de"
        | _ -> eprintfn "Unknown or non-POSIX node"; exit 2

    match action with
    | "prepare" | "health" | "run" -> ()
    | _ -> eprintfn "Unknown action"; exit 2

    if not (File.Exists(worker)) || File.GetAttributes(worker) &&& FileAttributes.ReparsePoint <> enum 0 then
        eprintfn $"Missing worker or symlink rejected: {worker}"
        exit 1

    let actual = sha256sum worker
    if actual <> expected then
        eprintfn $"Worker checksum mismatch: {worker}"
        exit 1

    File.SetAttributes(worker, File.GetAttributes(worker) ||| FileAttributes.Executable)

    match action with
    | "prepare" -> printfn $"Worker verified and executable: {worker}"; 0
    | "health" ->
        let psi = ProcessStartInfo(worker, "--health")
        psi.UseShellExecute <- false
        let proc = Process.Start(psi)
        proc.WaitForExit()
        proc.ExitCode
    | "run" ->
        let psi = ProcessStartInfo(worker)
        psi.UseShellExecute <- false
        let proc = Process.Start(psi)
        proc.WaitForExit()
        proc.ExitCode
    | _ -> 0

exit (main Environment.GetCommandLineArgs())
