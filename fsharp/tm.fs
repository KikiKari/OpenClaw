// abstraction-provenance: {"artifact_sha256": "b23af1bee43c86b0c7e362a395a1ba3613c2ff59b6db06a95dcadd2fd4852211", "source_sha256": "bd1408a3d37597ed2c41b37fe2104f806ee5ea009396e16c58748eb01356bfb6", "target_language": "fsharp"}
// tm.go — portiert nach fsharp
// Quelle: go, workspace@local:skills/github-clones/openclaw/scripts/docs-i18n/tm.go
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

namespace TranslationMemory

open System
open System.IO
open System.Collections.Generic
open System.Text.Json
open System.Linq

type TMEntry = {
    CacheKey: string
    SegmentID: string
    SourcePath: string
    TextHash: string
    Text: string
    Translated: string
    Provider: string
    Model: string
    SrcLang: string
    TgtLang: string
    UpdatedAt: string
}

type TranslationMemory(path: string) =
    let entries = Dictionary<string, TMEntry>()

    do
        if File.Exists(path) then
            use file = new FileStream(path, FileMode.Open, FileAccess.Read)
            use reader = new StreamReader(file)
            let mutable line = reader.ReadLine()
            while line <> null do
                let trimmed = line.Trim()
                if not (String.IsNullOrEmpty(trimmed)) then
                    try
                        let entry = JsonSerializer.Deserialize<TMEntry>(trimmed)
                        if not (String.IsNullOrEmpty(entry.CacheKey)) && not (String.IsNullOrWhiteSpace(entry.Translated)) then
                            entries.[entry.CacheKey] <- entry
                    with
                    | ex -> failwith $"translation memory decode failed: {ex.Message}"
                line <- reader.ReadLine()

    member _.Get(cacheKey: string) =
        match entries.TryGetValue(cacheKey) with
        | true, entry ->
            if String.IsNullOrWhiteSpace(entry.Translated) then
                None
            else
                Some entry
        | false, _ -> None

    member _.Put(entry: TMEntry) =
        if not (String.IsNullOrEmpty(entry.CacheKey)) then
            entries.[entry.CacheKey] <- entry

    member _.Save() =
        if String.IsNullOrEmpty(path) then
            ()
        else
            let dir = Path.GetDirectoryName(path)
            if not (String.IsNullOrEmpty(dir)) then
                Directory.CreateDirectory(dir) |> ignore
            
            let tmpPath = path + ".tmp"
            
            use file = new FileStream(tmpPath, FileMode.Create, FileAccess.Write)
            use writer = new StreamWriter(file)
            
            let sortedKeys = entries.Keys |> Seq.sort |> Seq.toArray
            
            for key in sortedKeys do
                let entry = entries.[key]
                let payload = JsonSerializer.Serialize(entry)
                writer.WriteLine(payload)
            
            writer.Flush()
            
            File.Move(tmpPath, path, true)
