// abstraction-provenance: {"artifact_sha256": "d3404e82627fbc791b5b42fe92cecbce66f41fdd8e393a5ca8f8a5e20d7a83a2", "source_sha256": "b6d33ba222e838d8ea4e8f134b161c60019978c5abaa86299906dfe095635a2b", "target_language": "fsharp"}
// callsite-guard.mjs — portiert nach fsharp
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/callsite-guard.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

module CallsiteGuard

open System
open System.IO
open System.Collections.Generic
open TsGuardUtils

type CallsiteGuardParams = {
    ImportMetaUrl: string
    SourceRoots: string list
    ExtraTestSuffixes: string list option
    SkipRelativePath: (string -> bool) option
    FindCallLines: (string -> string -> int list)
    AllowCallsite: (string -> bool) option
    Header: string
    Footer: string option
    SortViolations: bool option
}

let runCallsiteGuard (params: CallsiteGuardParams) =
    async {
        let repoRoot = resolveRepoRoot params.ImportMetaUrl
        let sourceRoots = resolveSourceRoots repoRoot params.SourceRoots
        let! files = collectTypeScriptFilesFromRoots sourceRoots { ExtraTestSuffixes = params.ExtraTestSuffixes }
        
        let violations = List<string>()
        
        for filePath in files do
            let relPath = Path.GetRelativePath(repoRoot, filePath).Replace(Path.DirectorySeparatorChar, '/')
            
            match params.SkipRelativePath with
            | Some skip when skip relPath -> ()
            | _ ->
                let! content = File.ReadAllTextAsync(filePath) |> Async.AwaitTask
                let lines = params.FindCallLines content filePath
                for line in lines do
                    let callsite = $"{relPath}:{line}"
                    match params.AllowCallsite with
                    | Some allow when allow callsite -> ()
                    | _ -> violations.Add(callsite)
        
        if violations.Count = 0 then
            return ()
        else
            Console.Error.WriteLine(params.Header)
            
            let sortedViolations = 
                match params.SortViolations with
                | Some false -> violations
                | _ -> violations |> Seq.sort |> List.ofSeq
            
            for violation in sortedViolations do
                Console.Error.WriteLine($"- {violation}")
                
            match params.Footer with
            | Some footer -> Console.Error.WriteLine(footer)
            | None -> ()
            
            Environment.Exit(1)
    }
