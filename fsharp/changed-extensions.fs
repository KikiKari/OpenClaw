// abstraction-provenance: {"artifact_sha256": "72e473169bc938eacdebbc1edcca8ccbeeefd51b3d655cc57340ca300b60ffa9", "source_sha256": "d97d27f12d9366bc18a828ca10d87d4ac159681dec9d4b6606e4827761c6ea72", "target_language": "fsharp"}
// changed-extensions.mjs — portiert nach fsharp
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/changed-extensions.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

module ChangedExtensions

open System
open System.IO
open System.Text.RegularExpressions
open System.Diagnostics
open BundledPluginPaths

let repoRoot = Path.GetFullPath(Path.Combine(__SOURCE_DIRECTORY__, "..", ".."))

let runGit (args: string[]) (options: ProcessStartInfo option) =
    let psi = ProcessStartInfo("git", String.concat " " args)
    psi.WorkingDirectory <- repoRoot
    psi.RedirectStandardOutput <- true
    psi.RedirectStandardError <- true
    psi.UseShellExecute <- false
    psi.StandardOutputEncoding <- Text.Encoding.UTF8
    match options with
    | Some opts -> 
        psi.WorkingDirectory <- opts.WorkingDirectory
        psi
    | None -> psi

    use proc = Process.Start(psi)
    let output = proc.StandardOutput.ReadToEnd()
    proc.WaitForExit()
    if proc.ExitCode <> 0 then
        failwith $"Git command failed: {String.concat " " args}"
    output

let normalizeRelative (inputPath: string) =
    inputPath.Replace(Path.DirectorySeparatorChar, '/')

let hasGitCommit (ref: string) =
    if String.IsNullOrEmpty(ref) || Regex.IsMatch(ref, @"^0+$") then
        false
    else
        try
            runGit [| "rev-parse"; "--verify"; $"{ref}^{{commit}}" |] None |> ignore
            true
        with _ -> false

let resolveChangedPathsBase (params_: {| base: string option; head: string option; fallbackBaseRef: string option |}) =
    let baseRef = params_.base
    let head = defaultArg params_.head "HEAD"
    let fallbackBaseRef = params_.fallbackBaseRef

    match baseRef with
    | Some b when hasGitCommit b -> b
    | _ ->
        match fallbackBaseRef with
        | Some fb ->
            let remoteBaseRef = if fb.StartsWith("origin/") then fb else $"origin/{fb}"
            if hasGitCommit remoteBaseRef then
                let mergeBase = (runGit [| "merge-base"; remoteBaseRef; head |] None).Trim()
                if hasGitCommit mergeBase then
                    mergeBase
                else
                    ""
            else
                ""
        | None -> ""

let listChangedPaths (baseRef: string) (head: string) =
    if String.IsNullOrEmpty(baseRef) then
        failwith "A git base revision is required to list changed extensions."
    
    (runGit [| "diff"; "--name-only"; baseRef; head |] None)
        .Split('\n')
        |> Array.map (fun line -> line.Trim())
        |> Array.filter (fun line -> not (String.IsNullOrEmpty(line)))

let hasExtensionPackage (extensionId: string) =
    File.Exists(Path.Combine(repoRoot, BUNDLED_PLUGIN_ROOT_DIR, extensionId, "package.json"))

let listAvailableExtensionIds () =
    let extensionsDir = Path.Combine(repoRoot, BUNDLED_PLUGIN_ROOT_DIR)
    if not (Directory.Exists(extensionsDir)) then
        [||]
    else
        Directory.GetDirectories(extensionsDir)
        |> Array.map Path.GetFileName
        |> Array.filter hasExtensionPackage
        |> Array.sort

let detectChangedExtensionIds (changedPaths: string[]) =
    let extensionIds = System.Collections.Generic.HashSet<string>()
    
    for rawPath in changedPaths do
        let relativePath = normalizeRelative (rawPath.Trim())
        if not (String.IsNullOrEmpty(relativePath)) then
            let extensionRegex = Regex($"^{Regex.Escape(BUNDLED_PLUGIN_PATH_PREFIX)}([^/]+)(?:/|$)")
            let extensionMatch = extensionRegex.Match(relativePath)
            if extensionMatch.Success then
                let extensionId = extensionMatch.Groups.[1].Value
                if hasExtensionPackage extensionId then
                    extensionIds.Add(extensionId) |> ignore
            else
                let pairedCoreRegex = Regex(@"^src/([^/]+)(?:/|$)")
                let pairedCoreMatch = pairedCoreRegex.Match(relativePath)
                if pairedCoreMatch.Success && hasExtensionPackage pairedCoreMatch.Groups.[1].Value then
                    extensionIds.Add(pairedCoreMatch.Groups.[1].Value) |> ignore
    
    extensionIds |> Seq.toArray |> Array.sort

let listChangedExtensionIds (params_: {| base: string option; head: string option; fallbackBaseRef: string option; unavailableBaseBehavior: string option |}) =
    let head = defaultArg params_.head "HEAD"
    let unavailableBaseBehavior = defaultArg params_.unavailableBaseBehavior "error"
    
    try
        let baseRef = resolveChangedPathsBase {| base = params_.base; head = Some head; fallbackBaseRef = params_.fallbackBaseRef |}
        detectChangedExtensionIds (listChangedPaths baseRef head)
    with ex ->
        match unavailableBaseBehavior with
        | "all" -> listAvailableExtensionIds()
        | "empty" -> [||]
        | _ -> failwith ex.Message
