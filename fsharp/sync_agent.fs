// abstraction-provenance: {"artifact_sha256": "4d778a66d2e73180934defef5b126d544179c009ab1b383f3e040f9726bdc7e9", "source_sha256": "b470dd345a01d0a6c2fec8e2dd8ccd0a3b59e67f44ce1aa0e6f4d9c34420b355", "target_language": "fsharp"}
// sync_agent.py — portiert nach fsharp
// Quelle: python, OpenClaw@gateway2:skills/clawhub-git-sync-agent/scripts/sync_agent.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

namespace SyncAgent

open System
open System.IO
open System.Collections.Generic
open System.Text.Json
open System.Diagnostics
open System.Text

// Import sync functions (simulated)
module SyncFunctions =
    let sync_to_git (_: string) (_: bool) = true
    let sync_to_clawhub (_: string) (_: bool) = true
    let log (_: string) (?level: string) = ()
    let validate_skill (_: string) = true
    let get_file_hash (_: string) = ""
    let iter_sync_files (_: string) = Seq.empty
    let RESERVED_SKILL_NAMES = Set.empty

[<Literal>]
let CLAWHUB_DIR = "/home/openclaw/.openclaw/workspace/skills"

[<Literal>]
let GIT_DIR = "/home/openclaw/.openclaw/workspace/git/skills"

[<Literal>]
let STATE_FILE = "/home/openclaw/.openclaw/workspace/db/sync_state.json"

type SyncState = {
    sync_history: obj list
    pending: obj list
}

type SyncResult = {
    synced_to_git: string list
    synced_to_clawhub: string list
    updated_git: string list
    updated_clawhub: string list
    no_change: string list
    errors: string list
}

let load_state () : SyncState =
    if File.Exists STATE_FILE then
        let json = File.ReadAllText STATE_FILE
        JsonSerializer.Deserialize<SyncState>(json)
    else
        { sync_history = []; pending = [] }

let save_state (state: SyncState) =
    // Ensure the parent directory exists
    let dir = Path.GetDirectoryName STATE_FILE
    if not (Directory.Exists dir) then
        Directory.CreateDirectory dir |> ignore
    let json = JsonSerializer.Serialize(state, JsonSerializerOptions(WriteIndented = true))
    File.WriteAllText(STATE_FILE, json)

let get_all_skills () : Set<string> =
    let get_skills_from_dir dir =
        if Directory.Exists dir then
            Directory.GetDirectories(dir)
            |> Array.map Path.GetFileName
            |> Array.filter (fun name -> 
                not (name.StartsWith ".") 
                && not (Set.contains name SyncFunctions.RESERVED_SKILL_NAMES)
                && File.Exists(Path.Combine(dir, name, "SKILL.md")))
            |> set
        else
            Set.empty
    let clawhub_skills = get_skills_from_dir CLAWHUB_DIR
    let git_skills = get_skills_from_dir GIT_DIR
    Set.union clawhub_skills git_skills

let init_git_repo (skill_path: string) (skill_name: string) =
    let git_dir = Path.Combine(skill_path, ".git")
    if not (Directory.Exists git_dir) then
        let startInfo = ProcessStartInfo("git", "init")
        startInfo.WorkingDirectory <- skill_path
        startInfo.UseShellExecute <- false
        startInfo.RedirectStandardOutput <- true
        startInfo.RedirectStandardError <- true
        use proc = Process.Start(startInfo)
        proc.WaitForExit() |> ignore
        
        let startInfo2 = ProcessStartInfo("git", "add .")
        startInfo2.WorkingDirectory <- skill_path
        startInfo2.UseShellExecute <- false
        startInfo2.RedirectStandardOutput <- true
        startInfo2.RedirectStandardError <- true
        use proc2 = Process.Start(startInfo2)
        proc2.WaitForExit() |> ignore
        
        let startInfo3 = ProcessStartInfo("git", $"commit -m \"Initial commit: {skill_name} skill\"")
        startInfo3.WorkingDirectory <- skill_path
        startInfo3.UseShellExecute <- false
        startInfo3.RedirectStandardOutput <- true
        startInfo3.RedirectStandardError <- true
        use proc3 = Process.Start(startInfo3)
        proc3.WaitForExit() |> ignore
        
        SyncFunctions.log $"Git initialized for {skill_name}"

let get_hashes (skill_dir: string) : Map<string, string> =
    let mutable hashes = Map.empty
    for file_path, rel_path in SyncFunctions.iter_sync_files skill_dir do
        hashes <- hashes.Add(rel_path, SyncFunctions.get_file_hash file_path)
    hashes

let preview_changes (source_dir: string) (target_dir: string) : string list =
    let mutable changes = []
    for src_file, rel_path in SyncFunctions.iter_sync_files source_dir do
        let tgt_file = Path.Combine(target_dir, rel_path)
        if not (File.Exists tgt_file) then
            changes <- $"ADD {rel_path}" :: changes
        elif SyncFunctions.get_file_hash(src_file) <> SyncFunctions.get_file_hash(tgt_file) then
            changes <- $"UPDATE {rel_path}" :: changes
    changes

let newest_mtime (skill_dir: string) : float =
    let mtimes = 
        [for file_path, _ in SyncFunctions.iter_sync_files skill_dir ->
            FileInfo(file_path).LastWriteTime.Ticks |> float]
    if List.isEmpty mtimes then 0.0 else List.max mtimes

let sync_skill_bidirectional (skill_name: string) : string =
    let clawhub_path = Path.Combine(CLAWHUB_DIR, skill_name)
    let git_path = Path.Combine(GIT_DIR, skill_name)
    
    let clawhub_exists = Directory.Exists clawhub_path
    let git_exists = Directory.Exists git_path
    
    // Fall 1: Nur in ClawHub → zu Git
    if clawhub_exists && not git_exists then
        SyncFunctions.log $"NEW in ClawHub: {skill_name} → syncing to Git"
        if SyncFunctions.sync_to_git skill_name false then
            init_git_repo git_path skill_name
            "synced_to_git"
        else
            "error"
    
    // Fall 2: Nur in Git → zu ClawHub
    elif git_exists && not clawhub_exists then
        SyncFunctions.log $"NEW in Git: {skill_name} → syncing to ClawHub"
        if SyncFunctions.sync_to_clawhub skill_name false then
            "synced_to_clawhub"
        else
            "error"
    
    // Fall 3: In beiden vorhanden
    elif clawhub_exists && git_exists then
        if not (SyncFunctions.validate_skill clawhub_path) then
            SyncFunctions.log $"Validation failed for ClawHub skill: {skill_name}" "ERROR"
            "error"
        elif not (SyncFunctions.validate_skill git_path) then
            SyncFunctions.log $"Validation failed for Git skill: {skill_name}" "ERROR"
            "error"
        else
            let clawhub_changes = preview_changes clawhub_path git_path
            let git_changes = preview_changes git_path clawhub_path
            
            if List.isEmpty clawhub_changes && List.isEmpty git_changes then
                SyncFunctions.log $"Content is identical for: {skill_name}"
                "no_change"
            elif not (List.isEmpty clawhub_changes) && List.isEmpty git_changes then
                SyncFunctions.log $"Content difference detected for: {skill_name}"
                SyncFunctions.log $"UPDATE: {skill_name} ClawHub content is newer or different → syncing to Git"
                if SyncFunctions.sync_to_git skill_name false then
                    let startInfo = ProcessStartInfo("git", "add .")
                    startInfo.WorkingDirectory <- git_path
                    startInfo.UseShellExecute <- false
                    startInfo.RedirectStandardOutput <- true
                    use proc = Process.Start(startInfo)
                    proc.WaitForExit() |> ignore
                    
                    let timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm")
                    let startInfo2 = ProcessStartInfo("git", $"commit -m \"Sync from ClawHub content diff: {timestamp}\"")
                    startInfo2.WorkingDirectory <- git_path
                    startInfo2.UseShellExecute <- false
                    startInfo2.RedirectStandardOutput <- true
                    use proc2 = Process.Start(startInfo2)
                    proc2.WaitForExit() |> ignore
                    "updated_git"
                else
                    SyncFunctions.log $"Failed to sync {skill_name} to Git after content diff" "ERROR"
                    "error"
            elif not (List.isEmpty git_changes) && List.isEmpty clawhub_changes then
                SyncFunctions.log $"Content difference detected for: {skill_name}"
                SyncFunctions.log $"UPDATE: {skill_name} Git content is newer or different → syncing to ClawHub"
                if SyncFunctions.sync_to_clawhub skill_name false then
                    "updated_clawhub"
                else
                    SyncFunctions.log $"Failed to sync {skill_name} to ClawHub after content diff" "ERROR"
                    "error"
            else
                SyncFunctions.log $"Content difference detected for: {skill_name}"
                if newest_mtime clawhub_path >= newest_mtime git_path then
                    SyncFunctions.log $"UPDATE: {skill_name} ClawHub content is newer or different → syncing to Git"
                    if SyncFunctions.sync_to_git skill_name false then
                        let startInfo = ProcessStartInfo("git", "add .")
                        startInfo.WorkingDirectory <- git_path
                        startInfo.UseShellExecute <- false
                        startInfo.RedirectStandardOutput <- true
                        use proc = Process.Start(startInfo)
                        proc.WaitForExit() |> ignore
                        
                        let timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm")
                        let startInfo2 = ProcessStartInfo("git", $"commit -m \"Sync from ClawHub content diff: {timestamp}\"")
                        startInfo2.WorkingDirectory <- git_path
                        startInfo2.UseShellExecute <- false
                        startInfo2.RedirectStandardOutput <- true
                        use proc2 = Process.Start(startInfo2)
                        proc2.WaitForExit() |> ignore
                        "updated_git"
                    else
                        SyncFunctions.log $"Failed to sync {skill_name} to Git after content diff" "ERROR"
                        "error"
                else
                    SyncFunctions.log $"UPDATE: {skill_name} Git content is newer or different → syncing to ClawHub"
                    if SyncFunctions.sync_to_clawhub skill_name false then
                        "updated_clawhub"
                    else
                        SyncFunctions.log $"Failed to sync {skill_name} to ClawHub after content diff" "ERROR"
                        "error"
    else
        "no_change"

let main () =
    SyncFunctions.log "=== ClawHub ↔ Git Sync Agent gestartet ==="
    
    // Load previous state
    let state = load_state()
    let all_skills = get_all_skills()
    SyncFunctions.log $"Gefundene Skills: {Set.count all_skills}"
    
    // Dry-Run Phase: only report changes, no actual modifications
    SyncFunctions.log "--- Dry-Run Phase Start ---"
    for skill in Set.toArray all_skills |> Array.sort do
        // Perform dry-run sync in both directions to capture potential changes
        SyncFunctions.sync_to_git skill true |> ignore
        SyncFunctions.sync_to_clawhub skill true |> ignore
    SyncFunctions.log "--- Dry-Run Phase End ---"
    
    let mutable results = {
        synced_to_git = []
        synced_to_clawhub = []
        updated_git = []
        updated_clawhub = []
        no_change = []
        errors = []
    }
    
    // Actual Sync Phase
    for skill in Set.toArray all_skills |> Array.sort do
        try
            let result = sync_skill_bidirectional skill
            match result with
            | "synced_to_git" -> results <- { results with synced_to_git = skill :: results.synced_to_git }
            | "synced_to_clawhub" -> results <- { results with synced_to_clawhub = skill :: results.synced_to_clawhub }
            | "updated_git" -> results <- { results with updated_git = skill :: results.updated_git }
            | "updated_clawhub" -> results <- { results with updated_clawhub = skill :: results.updated_clawhub }
            | "no_change" -> results <- { results with no_change = skill :: results.no_change }
            | _ -> results <- { results with errors = skill :: results.errors }
        with
        | ex -> 
            SyncFunctions.log $"ERROR syncing {skill}: {ex.Message}" "ERROR"
            results <- { results with errors = skill :: results.errors }
    
    // Zusammenfassung
    SyncFunctions.log "\n=== SYNC ZUSAMMENFASSUNG ==="
    SyncFunctions.log $"Neu in Git: {List.length results.synced_to_git} - {results.synced_to_git}"
    SyncFunctions.log $"Neu in ClawHub: {List.length results.synced_to_clawhub} - {results.synced_to_clawhub}"
    SyncFunctions.log $"Git aktualisiert: {List.length results.updated_git} - {results.updated_git}"
    SyncFunctions.log $"ClawHub aktualisiert: {List.length results.updated_clawhub} - {results.updated_clawhub}"
    SyncFunctions.log $"Keine Änderung: {List.length results.no_change}"
    SyncFunctions.log $"Fehler: {List.length results.errors} - {results.errors}"
    
    // State speichern
    let new_history_entry = dict [
        "timestamp", box (DateTime.Now.ToString("o"))
        "results", box results
    ]
    
    let updated_history = 
        (state.sync_history @ [new_history_entry]) 
        |> List.rev 
        |> List.take (min 100 (List.length state.sync_history + 1)) 
        |> List.rev
    
    let updated_state = { state with sync_history = updated_history }
    save_state updated_state
    
    SyncFunctions.log "=== Sync Agent beendet ===\n"

[<EntryPoint>]
let entryPoint _ =
    main()
    0
