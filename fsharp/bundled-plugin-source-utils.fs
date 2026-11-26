// abstraction-provenance: {"artifact_sha256": "ba43b03e3e78f0fbe521660852b026319d58290cf885580112940de9b63df946", "source_sha256": "2d35fb0177cdd721585255bbae6415badcc488d34a5deef965207b8fd1e561ad", "target_language": "fsharp"}
// bundled-plugin-source-utils.mjs — portiert nach fsharp
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-source-utils.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

module BundledPluginSourceUtils

open System
open System.IO
open Newtonsoft.Json

let readIfExists (filePath: string) =
    try
        File.ReadAllText(filePath) |> Some
    with
    | _ -> None

type PluginEntry = {
    DirName: string
    PluginDir: string
    ManifestPath: string
    Manifest: obj
    PackageJsonPath: string option
    PackageJson: obj option
}

let collectBundledPluginSources (repoRoot: string option) (requirePackageJson: bool) =
    let repoRoot = 
        match repoRoot with
        | Some path -> Path.GetFullPath(path)
        | None -> Directory.GetCurrentDirectory()
    
    let extensionsRoot = Path.Combine(repoRoot, "extensions")
    
    if not (Directory.Exists(extensionsRoot)) then
        []
    else
        let dirs = Directory.GetDirectories(extensionsRoot)
        
        dirs
        |> Array.filter (fun dir ->
            let manifestPath = Path.Combine(dir, "openclaw.plugin.json")
            File.Exists(manifestPath) && 
            (not requirePackageJson || File.Exists(Path.Combine(dir, "package.json")))
        )
        |> Array.map (fun dir ->
            let dirName = Path.GetFileName(dir)
            let manifestPath = Path.Combine(dir, "openclaw.plugin.json")
            let packageJsonPath = Path.Combine(dir, "package.json")
            
            let manifestContent = File.ReadAllText(manifestPath)
            let manifest = JsonConvert.DeserializeObject(manifestContent)
            
            let packageJsonContent, packageJson = 
                if File.Exists(packageJsonPath) then
                    let content = File.ReadAllText(packageJsonPath)
                    content, Some (JsonConvert.DeserializeObject(content))
                else
                    "", None
            
            {
                DirName = dirName
                PluginDir = dir
                ManifestPath = manifestPath
                Manifest = manifest
                PackageJsonPath = if packageJson.IsSome then Some packageJsonPath else None
                PackageJson = packageJson
            }
        )
        |> Array.sortBy (fun entry -> entry.DirName)
        |> Array.toList
