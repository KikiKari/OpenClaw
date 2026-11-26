// abstraction-provenance: {"artifact_sha256": "d81cbce801e000a1a84e7753cf78b2a952976f0df50d3d8ca365f1bab742a4c2", "source_sha256": "ea352b99923506af9c3ce8c6a36ed51f94a6d895a48b5e6aeebdb0322ed9e62d", "target_language": "fsharp"}
// bundled-plugin-root-runtime-mirrors.mjs — portiert nach fsharp
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/bundled-plugin-root-runtime-mirrors.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

module CollectBundledPluginRootRuntimeMirrors

open System
open System.IO
open System.Text.RegularExpressions
open Newtonsoft.Json.Linq

let JS_EXTENSIONS = set [".cjs"; ".js"; ".mjs"]

type DependencyRecord = {
    Spec: string
    PluginIds: string list
    Conflicts: (string * string) list
}

type MirrorRecord = {
    Importers: Set<string>
    PluginIds: string list
    Spec: string
}

let collectRuntimeDependencySpecs (packageJson: JObject) =
    let getDeps key =
        match packageJson.[key] with
        | :? JObject as deps -> 
            deps.Properties()
            |> Seq.filter (fun prop -> 
                match prop.Value with
                | :? JValue as v -> v.Type = JTokenType.String && not (string v = "")
                | _ -> false)
            |> Seq.map (fun prop -> prop.Name, string prop.Value)
        | _ -> Seq.empty
    
    let deps = getDeps "dependencies"
    let optDeps = getDeps "optionalDependencies"
    Map.ofSeq (Seq.append deps optDeps)

let packageNameFromSpecifier (specifier: string) =
    if String.IsNullOrEmpty(specifier) || 
       specifier.StartsWith(".") || 
       specifier.StartsWith("/") || 
       specifier.StartsWith("node:") || 
       specifier.StartsWith("#") then
        None
    else
        let parts = specifier.Split('/')
        if parts.Length = 0 then
            None
        elif parts.[0].StartsWith("@") && parts.Length > 1 then
            Some $"{parts.[0]}/{parts.[1]}"
        else
            Some parts.[0]

let readJson (filePath: string) =
    File.ReadAllText(filePath) |> JObject.Parse

let collectPackageJsonPaths (rootDir: string) =
    if not (Directory.Exists(rootDir)) then
        []
    else
        Directory.GetDirectories(rootDir)
        |> Array.map (fun dir -> Path.Combine(dir, "package.json"))
        |> Array.filter File.Exists
        |> Array.sort
        |> List.ofArray

let collectBundledPluginRuntimeDependencySpecs (bundledPluginsDir: string) =
    let specs = System.Collections.Generic.Dictionary<string, DependencyRecord>()
    
    for packageJsonPath in collectPackageJsonPaths bundledPluginsDir do
        let packageJson = readJson packageJsonPath
        let pluginId = Path.GetFileName(Path.GetDirectoryName(packageJsonPath))
        let deps = collectRuntimeDependencySpecs packageJson
        
        for (name, spec) in deps do
            match specs.TryGetValue(name) with
            | true, existing ->
                if existing.Spec <> spec then
                    let conflicts = (pluginId, spec) :: existing.Conflicts
                    specs.[name] <- { existing with Conflicts = conflicts }
                elif not (List.contains pluginId existing.PluginIds) then
                    specs.[name] <- { existing with PluginIds = pluginId :: existing.PluginIds }
            | false, _ ->
                specs.[name] <- { Spec = spec; PluginIds = [pluginId]; Conflicts = [] }
    
    specs

let walkJavaScriptFiles (rootDir: string) =
    let files = ResizeArray<string>()
    if not (Directory.Exists(rootDir)) then
        files
    else
        let queue = ResizeArray<string>()
        queue.Add(rootDir)
        
        while queue.Count > 0 do
            let current = queue.[0]
            queue.RemoveAt(0)
            
            try
                for entry in Directory.GetFileSystemEntries(current) do
                    let info = DirectoryInfo(entry)
                    let isDir = Directory.Exists(entry)
                    
                    if isDir then
                        if not (entry.Split(Path.DirectorySeparatorChar).Contains("extensions")) then
                            queue.Add(entry)
                    else
                        let ext = Path.GetExtension(entry)
                        if JS_EXTENSIONS.Contains(ext) then
                            files.Add(entry)
            with
            | _ -> ()
        
        files.Sort(fun a b -> String.Compare(a, b))
        files

let extractModuleSpecifiers (source: string) =
    let specifiers = System.Collections.Generic.HashSet<string>()
    let patterns = [
        @"\bfrom\s*""([^""]+)"""
        @"\bimport\s*""([^""]+)"""
        @"\bimport\s*\(\s*""([^""]+)""\s*\)"
        @"\brequire\s*\(\s*""([^""]+)""\s*\)"
    ]
    
    for pattern in patterns do
        let regex = Regex(pattern)
        let matches = regex.Matches(source)
        for m in matches do
            if m.Groups.Count > 1 && not (String.IsNullOrEmpty(m.Groups.[1].Value)) then
                specifiers.Add(m.Groups.[1].Value) |> ignore
    
    specifiers

let collectRootDistBundledRuntimeMirrors (distDir: string) (bundledSpecs: Map<string, DependencyRecord>) =
    let mirrors = System.Collections.Generic.Dictionary<string, MirrorRecord>()
    
    for filePath in walkJavaScriptFiles distDir do
        let source = File.ReadAllText(filePath)
        let relativePath = Uri(distDir).MakeRelativeUri(Uri(filePath)).ToString().Replace("\\", "/")
        
        for specifier in extractModuleSpecifiers source do
            match packageNameFromSpecifier specifier with
            | Some dependencyName when bundledSpecs.ContainsKey(dependencyName) ->
                let bundledSpec = bundledSpecs.[dependencyName]
                match mirrors.TryGetValue(dependencyName) with
                | true, existing ->
                    mirrors.[dependencyName] <- { existing with Importers = Set.add relativePath existing.Importers }
                | false, _ ->
                    mirrors.[dependencyName] <- {
                        Importers = set [relativePath]
                        PluginIds = bundledSpec.PluginIds
                        Spec = bundledSpec.Spec
                    }
            | _ -> ()
    
    mirrors

let collectBundledPluginRootRuntimeMirrorErrors (rootPackageJson: JObject) (bundledRuntimeDependencySpecs: Map<string, DependencyRecord>) (requiredRootMirrors: Map<string, MirrorRecord>) =
    let rootRuntimeDeps = collectRuntimeDependencySpecs rootPackageJson
    let errors = ResizeArray<string>()
    
    for (dependencyName, record) in bundledRuntimeDependencySpecs do
        for (conflictPluginId, conflictSpec) in record.Conflicts do
            errors.Add($"bundled runtime dependency '{dependencyName}' has conflicting plugin specs: {String.Join(", ", record.PluginIds)} use '{record.Spec}', {conflictPluginId} uses '{conflictSpec}'.")
    
    for (dependencyName, mirror) in requiredRootMirrors do
        let rootSpec = 
            match rootRuntimeDeps.TryFind(dependencyName) with
            | Some spec -> spec
            | None -> ""
        
        let importers = mirror.Importers |> Set.toArray |> Array.sort
        let importerLabel = String.Join(", ", importers)
        let pluginLabel = mirror.PluginIds |> List.sort |> String.Join(", ")
        
        if String.IsNullOrEmpty(rootSpec) then
            errors.Add($"root dist imports bundled plugin runtime dependency '{dependencyName}' from {importerLabel}; mirror '{dependencyName}: {mirror.Spec}' in root package.json (declared by {pluginLabel}).")
        elif rootSpec <> mirror.Spec then
            errors.Add($"root dist imports bundled plugin runtime dependency '{dependencyName}' from {importerLabel}; root package.json has '{rootSpec}' but plugin manifest declares '{mirror.Spec}' ({pluginLabel}).")
    
    errors.ToArray()
