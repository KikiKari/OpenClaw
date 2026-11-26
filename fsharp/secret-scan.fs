// abstraction-provenance: {"artifact_sha256": "3a7084de3094820d7075dbb50a338108a05b056c1e5c9391bf5cb2ea243d3d5c", "source_sha256": "5ea1a8c9a13631404f27bfdb1410099cd81f89038616abac4b49bd62666db56a", "target_language": "fsharp"}
// secret-scan.mjs — portiert nach fsharp
// Quelle: javascript, Onboarding@main:scripts/secret-scan.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Text.RegularExpressions
open System.Collections.Generic

let root = Path.GetDirectoryName(Path.GetDirectoryName(__SOURCE_FILE__))
let skipped = set [
    "node_modules"
    ".next"
    ".git"
    ".pytest_cache"
    "__pycache__"
    "media-production/raw"
    "media-production/private"
]
let patterns = [|
    Regex(@"sk-(?:proj|svcacct|ant|or-v1|admin)-[A-Za-z0-9_-]{20,}")
    Regex(@"(?:nvapi|lin_api|ntn|vcp)_[A-Za-z0-9_-]{20,}")
    Regex(@"ELEVENLABS_API_KEY\s*=\s*[""]?[A-Za-z0-9]{20,}")
    Regex(@"WAVESPEED_API_KEY\s*=\s*[""]?[A-Za-z0-9]{20,}")
|]
let findings = ResizeArray<string>()

let rec walk (dirPath: string) (relative: string) =
    async {
        try
            let! entries = Directory.EnumerateFileSystemEntries(dirPath) |> Seq.toArray |> Async.AwaitTask
            for entry in entries do
                let entryName = Path.GetFileName(entry)
                let rel = Path.Combine(relative, entryName)
                
                if entryName = ".env" || 
                   (entryName.StartsWith(".env.") && entryName <> ".env.example") ||
                   skipped |> Seq.exists (fun item -> 
                       rel = item || 
                       rel.StartsWith(sprintf "%s%c" item Path.DirectorySeparatorChar) ||
                       rel.Split(Path.DirectorySeparatorChar) |> Array.contains item) then
                    ()
                else
                    let isDir = Directory.Exists(entry)
                    if isDir then
                        do! walk entry rel
                    else
                        let fileInfo = FileInfo(entry)
                        if fileInfo.Length < 2000000L then
                            try
                                use stream = File.OpenRead(entry)
                                if stream.Length > 0L then
                                    use reader = new StreamReader(stream)
                                    let! content = reader.ReadToEndAsync() |> Async.AwaitTask
                                    for pattern in patterns do
                                        if pattern.IsMatch(content) then
                                            findings.Add(rel)
                            with _ -> ()
        with _ -> ()
    }

[<EntryPoint>]
let main argv =
    async {
        do! walk root ""
        if findings.Count > 0 then
            let uniqueFindings = findings |> Seq.distinct |> Seq.toArray
            eprintfn "Secret-Scan fehlgeschlagen: %s" (String.Join(", ", uniqueFindings))
            return 1
        else
            printfn "Secret-Scan bestanden."
            return 0
    } |> Async.RunSynchronously
