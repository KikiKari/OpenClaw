// abstraction-provenance: {"artifact_sha256": "f9d451eb2c58c511c53918d9b81dbca308b6c382369aeb54ca54fccb6e7a585a", "source_sha256": "e86a7b42e9bd3c3d2f9321883c9d29b0e6b2774e4eb99056dd5093ca64b5b5c8", "target_language": "fsharp"}
// sync_bulk.py — portiert nach fsharp
// Quelle: python, OpenClaw@gateway1:skills/sync-utils/scripts/sync_bulk.py
// auch in: OpenClaw@gateway2:skills/sync-utils/scripts/sync_bulk.py
// auch in: workspace@local:git/skills/sync-utils/scripts/sync_bulk.py
// auch in: workspace@local:skills/sync-utils/scripts/sync_bulk.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

// Bulk Sync - Synchronisiert alle Skills

open System
open System.IO
open System.Collections.Generic
open System.Diagnostics

// Configuration paths
let CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"
let GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills"

// Helper functions for file operations
let getDirectories path =
    if Directory.Exists(path) then
        Directory.GetDirectories(path)
        |> Array.map Path.GetFileName
        |> Set.ofArray
    else
        Set.empty

let directoryExists path = Directory.Exists(path)

let getMaxMtime path =
    let rec getAllFiles acc dir =
        let files = 
            try 
                Directory.GetFiles(dir, "*", SearchOption.TopDirectoryOnly)
                |> Array.filter (fun f -> not (f.Contains(".git")))
            with :? UnauthorizedAccessException -> [||]
        
        let subdirs = 
            try 
                Directory.GetDirectories(dir)
            with :? UnauthorizedAccessException -> [||]
        
        let newAcc = Array.append acc files
        Array.fold getAllFiles newAcc subdirs
    
    try
        getAllFiles [||] path
        |> Array.map (fun f -> 
            try 
                FileInfo(f).LastWriteTimeUtc.ToUnixTimeSeconds()
            with _ -> 0L)
        |> Array.max
    with _ -> 0L

// Logging function
let log (message: string) (level: string) =
    let timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
    printfn "[%s] %s: %s" timestamp level message

let logInfo message = log message "INFO"
let logError message = log message "ERROR"

// Validation placeholder - needs actual implementation
let validate_skill (path: string) =
    // Placeholder validation logic
    try
        Directory.Exists(path) && Directory.GetFileSystemEntries(path).Length > 0
    with _ -> false

// Sync functions placeholders - need actual implementation
let sync_to_git (skill: string) (dryRun: bool) =
    logInfo $"Syncing {skill} to Git..."
    // Actual sync logic would go here
    true

let sync_to_clawhub (skill: string) (dryRun: bool) =
    logInfo $"Syncing {skill} to ClawHub..."
    // Actual sync logic would go here
    true

type SyncResult = {
    Synced: string list
    Skipped: string list
    Failed: string list
}

let sync_all_skills (dry_run: bool) =
    // Alle Skills finden
    let mutable all_skills = Set.empty
    all_skills <- Set.union all_skills (getDirectories CLAWHUB_DIR)
    all_skills <- Set.union all_skills (getDirectories GIT_DIR)
    
    logInfo $"Bulk Sync: {all_skills.Count} Skills gefunden"
    
    let results = {
        Synced = []
        Skipped = []
        Failed = []
    }
    
    let processSkill (results: SyncResult) (skill: string) =
        let clawhub_path = Path.Combine(CLAWHUB_DIR, skill)
        let git_path = Path.Combine(GIT_DIR, skill)
        
        try
            // Nur in ClawHub → zu Git
            if directoryExists clawhub_path && not (directoryExists git_path) then
                if validate_skill clawhub_path then
                    logInfo $"Syncing {skill} to Git..."
                    if sync_to_git skill dry_run then
                        { results with Synced = $"{skill} → Git" :: results.Synced }
                    else
                        { results with Failed = skill :: results.Failed }
                else
                    { results with Skipped = $"{skill} (validation failed)" :: results.Skipped }
            
            // Nur in Git → zu ClawHub
            elif directoryExists git_path && not (directoryExists clawhub_path) then
                if validate_skill git_path then
                    logInfo $"Syncing {skill} to ClawHub..."
                    if sync_to_clawhub skill dry_run then
                        { results with Synced = $"{skill} → ClawHub" :: results.Synced }
                    else
                        { results with Failed = skill :: results.Failed }
                else
                    { results with Skipped = $"{skill} (validation failed)" :: results.Skipped }
            
            // In beiden - prüfe ob Update nötig
            elif directoryExists clawhub_path && directoryExists git_path then
                let clawhub_mtime = getMaxMtime clawhub_path
                let git_mtime = getMaxMtime git_path
                
                if abs (clawhub_mtime - git_mtime) > 60L then
                    if clawhub_mtime > git_mtime then
                        logInfo $"Updating {skill} in Git..."
                        if sync_to_git skill dry_run then
                            { results with Synced = $"{skill} → Git (update)" :: results.Synced }
                        else
                            { results with Failed = skill :: results.Failed }
                    else
                        logInfo $"Updating {skill} in ClawHub..."
                        if sync_to_clawhub skill dry_run then
                            { results with Synced = $"{skill} → ClawHub (update)" :: results.Synced }
                        else
                            { results with Failed = skill :: results.Failed }
                else
                    { results with Skipped = $"{skill} (already synced)" :: results.Skipped }
            else
                results
        with ex ->
            logError $"Error processing {skill}: {ex.Message}"
            { results with Failed = skill :: results.Failed }
    
    let finalResults = 
        Set.toArray all_skills
        |> Array.sort
        |> Array.fold processSkill results
    
    // Zusammenfassung
    printfn "\n%s" (String.replicate 60 "=")
    let mode = if dry_run then "DRY-RUN" else "EXECUTED"
    printfn $"Bulk Sync {mode} - Zusammenfassung"
    printfn "%s" (String.replicated 60 "=")
    printfn $"✅ Synchronisiert: {finalResults.Synced.Length}"
    finalResults.Synced |> List.rev |> List.iter (printfn "   - %s")
    
    printfn $"\n⏭️  Übersprungen: {finalResults.Skipped.Length}"
    if finalResults.Skipped.Length <= 10 then
        finalResults.Skipped |> List.rev |> List.iter (printfn "   - %s")
    else
        printfn $"   - {finalResults.Skipped.Length} Skills (bereits synchron oder Validierung fehlgeschlagen)"
    
    printfn $"\n❌ Fehlgeschlagen: {finalResults.Failed.Length}"
    finalResults.Failed |> List.rev |> List.iter (printfn "   - %s")
    printfn "%s" (String.replicated 60 "=")
    
    finalResults

[<EntryPoint>]
let main argv =
    let dryRun = ref false
    let execute = ref false
    
    // Simple argument parsing
    for arg in argv do
        match arg with
        | "--dry-run" -> dryRun := true
        | "--execute" -> execute := true
        | _ -> ()
    
    if not !dryRun && not !execute then
        printfn "Bitte --dry-run oder --execute angeben"
        1
    else
        sync_all_skills !dryRun |> ignore
        0
