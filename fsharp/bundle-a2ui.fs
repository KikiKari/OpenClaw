// abstraction-provenance: {"artifact_sha256": "3b4e4c1a09a49ea411142d2a54b112c4e8a5d6c70b2f036e698cad2eca1a4ccb", "source_sha256": "30b068d00de57f3979f795548c3348e1511fda4cab0dd01eb16a7d91c71fbb9d", "target_language": "fsharp"}
// bundle-a2ui.mjs — portiert nach fsharp
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

open System
open System.Diagnostics
open System.IO
open System.Security.Cryptography
open System.Text
open System.Threading.Tasks

let rootDir = Path.GetFullPath(Path.Combine(__SOURCE_DIRECTORY__, ".."))
let hashFile = Path.Combine(rootDir, "src", "canvas-host", "a2ui", ".bundle.hash")
let outputFile = Path.Combine(rootDir, "src", "canvas-host", "a2ui", "a2ui.bundle.js")
let a2uiRendererDir = Path.Combine(rootDir, "vendor", "a2ui", "renderers", "lit")
let a2uiAppDir = Path.Combine(rootDir, "apps", "shared", "OpenClawKit", "Tools", "CanvasA2UI")
let inputPaths = [|
    Path.Combine(rootDir, "package.json")
    Path.Combine(rootDir, "pnpm-lock.yaml")
    a2uiRendererDir
    a2uiAppDir
|]
let ignoredBundleHashInputPrefixes = [| "vendor/a2ui/renderers/lit/dist" |]

let normalizePath (filePath: string) =
    filePath.Replace(Path.DirectorySeparatorChar, '/').Replace(Path.AltDirectorySeparatorChar, '/')

let isBundleHashInputPath (filePath: string) (repoRoot: string) =
    let relativePath = normalizePath (Path.GetRelativePath(repoRoot, filePath))
    not (ignoredBundleHashInputPrefixes |> Array.exists (fun ignoredPath -> 
        relativePath = ignoredPath || relativePath.StartsWith($"{ignoredPath}/")))

let getLocalRolldownCliCandidates (repoRoot: string) =
    [|
        Path.Combine(repoRoot, "node_modules", "rolldown", "bin", "cli.mjs")
        Path.Combine(repoRoot, "node_modules", ".pnpm", "node_modules", "rolldown", "bin", "cli.mjs")
        Path.Combine(repoRoot, "node_modules", ".pnpm", "rolldown@1.0.0-rc.12", "node_modules", "rolldown", "bin", "cli.mjs")
    |]

let rec walkFiles (entryPath: string) (files: ResizeArray<string>) =
    async {
        if not (isBundleHashInputPath entryPath rootDir) then
            return ()
        else
            let! stat = File.GetAttributesAsync(entryPath) |> Async.AwaitTask
            if not (stat.HasFlag(FileAttributes.Directory)) then
                files.Add(entryPath)
            else
                let! entries = Directory.GetFileSystemEntriesAsync(entryPath) |> Async.AwaitTask
                for entry in entries do
                    do! walkFiles entry files
    }

let listTrackedInputFiles () =
    let startInfo = ProcessStartInfo(
        "git",
        $"ls-files -- {String.Join(" ", inputPaths |> Array.map (fun p -> Path.GetRelativePath(rootDir, p)))}",
        WorkingDirectory = rootDir,
        RedirectStandardOutput = true,
        RedirectStandardError = true
    )
    
    use proc = new Process(StartInfo = startInfo)
    proc.Start() |> ignore
    let output = proc.StandardOutput.ReadToEnd()
    let error = proc.StandardError.ReadToEnd()
    proc.WaitForExit()
    
    if proc.ExitCode <> 0 then
        None
    else
        output.Split([| '\n' |], StringSplitOptions.RemoveEmptyEntries)
        |> Array.map (fun filePath -> Path.Combine(rootDir, filePath))
        |> Array.filter (fun filePath -> isBundleHashInputPath filePath rootDir)
        |> Some

let computeHash () =
    async {
        let files = 
            match listTrackedInputFiles() with
            | Some tracked -> tracked
            | None ->
                let filesList = ResizeArray<string>()
                for inputPath in inputPaths do
                    walkFiles inputPath filesList |> Async.RunSynchronously
                filesList.ToArray()

        let sortedFiles = 
            files 
            |> Array.sortBy (fun f -> normalizePath (Path.GetRelativePath(rootDir, f)))

        using (SHA256.Create()) (fun hash ->
            for filePath in sortedFiles do
                let relativePath = normalizePath (Path.GetRelativePath(rootDir, filePath))
                hash.TransformBlock(Encoding.UTF8.GetBytes(relativePath), 0, Encoding.UTF8.GetByteCount(relativePath), null, 0) |> ignore
                hash.TransformBlock(Encoding.UTF8.GetBytes("\0"), 0, 1, null, 0) |> ignore
                let fileBytes = File.ReadAllBytes(filePath)
                hash.TransformBlock(fileBytes, 0, fileBytes.Length, null, 0) |> ignore
                hash.TransformBlock(Encoding.UTF8.GetBytes("\0"), 0, 1, null, 0) |> ignore
            hash.TransformFinalBlock(Array.empty, 0, 0) |> ignore
            BitConverter.ToString(hash.Hash).Replace("-", "").ToLowerInvariant()
        )
    }

let runStep (command: string) (args: string[]) (options: ProcessStartInfo option) =
    let startInfo = 
        match options with
        | Some opts -> opts
        | None -> ProcessStartInfo()
    
    startInfo.FileName <- command
    startInfo.Arguments <- String.Join(" ", args)
    startInfo.WorkingDirectory <- rootDir
    startInfo.UseShellExecute <- false
    
    use proc = new Process(StartInfo = startInfo)
    proc.Start() |> ignore
    proc.WaitForExit()
    
    if proc.ExitCode <> 0 then
        Environment.Exit(if proc.ExitCode > 0 then proc.ExitCode else 1)

let runPnpm (pnpmArgs: string[]) =
    // Simplified implementation - would need actual logic to resolve pnpm runner
    runStep "pnpm" pnpmArgs None

let main () =
    async {
        let! hasRendererDir = File.ExistsAsync(a2uiRendererDir) |> Async.AwaitTask
        let! hasAppDir = File.ExistsAsync(a2uiAppDir) |> Async.AwaitTask
        let! hasOutputFile = File.ExistsAsync(outputFile) |> Async.AwaitTask
        
        if not hasRendererDir || not hasAppDir then
            if hasOutputFile then
                printfn "A2UI sources missing; keeping prebuilt bundle."
                return ()
            elif Environment.GetEnvironmentVariable("OPENCLAW_SPARSE_PROFILE") <> null || 
                 Environment.GetEnvironmentVariable("OPENCLAW_A2UI_SKIP_MISSING") = "1" then
                eprintfn "A2UI sources missing; skipping bundle because OPENCLAW_A2UI_SKIP_MISSING=1 or OPENCLAW_SPARSE_PROFILE is set."
                return ()
            else
                failwith $"A2UI sources missing and no prebuilt bundle found at: {outputFile}"

        let! currentHash = computeHash ()
        let! hashFileExists = File.ExistsAsync(hashFile) |> Async.AwaitTask
        
        if hashFileExists then
            let! previousHash = File.ReadAllTextAsync(hashFile) |> Async.AwaitTask
            if (previousHash.Trim() = currentHash) && hasOutputFile then
                printfn "A2UI bundle up to date; skipping."
                return ()

        runPnpm [| "-s"; "exec"; "tsc"; "-p"; Path.Combine(a2uiRendererDir, "tsconfig.json") |]

        let localRolldownCliCandidates = getLocalRolldownCliCandidates rootDir
        let mutable localRolldownCli = None
        
        for candidate in localRolldownCliCandidates do
            let! exists = File.ExistsAsync(candidate) |> Async.AwaitTask
            if exists then
                localRolldownCli <- Some candidate
                break

        match localRolldownCli with
        | Some cli ->
            runStep (
                Process.GetCurrentProcess().MainModule.FileName
            ) ( [| cli; "-c"; Path.Combine(a2uiAppDir, "rolldown.config.mjs") |] ) None
        | None ->
            runPnpm [| "-s"; "exec"; "rolldown"; "-c"; Path.Combine(a2uiAppDir, "rolldown.config.mjs") |]

        do! File.WriteAllTextAsync(hashFile, $"{currentHash}\n") |> Async.AwaitTask
    }

[<EntryPoint>]
let entryPoint argv =
    try
        main () |> Async.RunSynchronously
        0
    with
    | ex ->
        eprintfn "%s" ex.Message
        eprintfn "A2UI bundling failed. Re-run with: pnpm canvas:a2ui:bundle"
        eprintfn "If this persists, verify pnpm deps and try again."
        1
