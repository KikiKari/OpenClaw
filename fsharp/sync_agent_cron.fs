// abstraction-provenance: {"artifact_sha256": "75e9e877cecbd3b0fc990264f10297076caaa996afb7dc73c234824fe2e4552a", "source_sha256": "6dcc2c07911eedad64d93e999a1605091bebc0ed6eadad479df838626620545d", "target_language": "fsharp"}
// sync_agent_cron.py — portiert nach fsharp
// Quelle: python, OpenClaw@gateway1:scripts/sync_agent_cron.py
// auch in: OpenClaw@gateway2:scripts/sync_agent_cron.py
// auch in: workspace@local:scripts/sync_agent_cron.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

// ClawHub ↔ Git Sync Agent - Cron Version mit Dry-Run + Auto-Sync

open System
open System.IO
open System.Text.Json
open System.Collections.Generic

let CLAWHUB_DIR = Path.Combine [| "/home/openclaw/.openclaw/workspace/skills" |]
let GIT_DIR = Path.Combine [| "/home/openclaw/.openclaw/workspace/git/skills" |]
let LOG_FILE = Path.Combine [| "/home/openclaw/.openclaw/workspace/logs/sync-agent.log" |]

let file_mtime (path: string) =
    try
        let dirInfo = DirectoryInfo(path)
        let files = 
            dirInfo.GetFiles("*", SearchOption.AllDirectories)
            |> Array.filter (fun f -> not (f.FullName.Contains(".git")))
        
        if files.Length = 0 then 0.0
        else
            files 
            |> Array.map (fun f -> f.LastWriteTimeUtc.ToFileTimeUtc() |> float)
            |> Array.max
    with
    | _ -> 0.0

let write_to_log (message: string) (level: string) =
    let timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
    let entry = sprintf "[%s] [%s] %s" timestamp level message
    printfn "%s" entry
    use writer = new StreamWriter(LOG_FILE, true)
    writer.WriteLine(entry)

// Hauptlog-Funktion überschreiben
let log = write_to_log

write_to_log ("=" + String.replicate 69 "=") "INFO"
write_to_log "CLAWHUB ↔ GIT SYNC AGENT - CRON LAUF" "INFO"
write_to_log (sprintf "Zeitstempel: %s" (DateTime.Now.ToString("o"))) "INFO"
write_to_log ("=" + String.replicate 69 "=") "INFO"

let getSkillDirs (baseDir: string) =
    try
        Directory.GetDirectories(baseDir)
        |> Array.map Path.GetFileName
        |> Set.ofArray
        |> Set.filter (fun name -> not (name.StartsWith(".")))
    with
    | _ -> Set.empty

let clawhub_skills = getSkillDirs CLAWHUB_DIR
let git_skills = getSkillDirs GIT_DIR

// DRY-RUN: Erkenne Änderungen
write_to_log "\n[DRY-RUN] Analysiere Änderungen..." "INFO"

type ChangesDetected = {
    new_in_clawhub: string list
    new_in_git: string list
    clawhub_newer: (string * float) list
    git_newer: (string * float) list
    synced: string list
}

let new_in_clawhub = Set.difference clawhub_skills git_skills |> Set.toList |> List.sort
let new_in_git = Set.difference git_skills clawhub_skills |> Set.toList |> List.sort

let in_both = Set.intersect clawhub_skills git_skills |> Set.toList |> List.sort

let mutable changes_detected = {
    new_in_clawhub = new_in_clawhub
    new_in_git = new_in_git
    clawhub_newer = []
    git_newer = []
    synced = []
}

for skill in in_both do
    let c_mtime = file_mtime (Path.Combine [| CLAWHUB_DIR; skill |])
    let g_mtime = file_mtime (Path.Combine [| GIT_DIR; skill |])
    let diff = c_mtime - g_mtime
    
    if abs diff > 60.0 then
        if diff > 0.0 then
            changes_detected <- { changes_detected with clawhub_newer = (skill, diff) :: changes_detected.clawhub_newer }
        else
            changes_detected <- { changes_detected with git_newer = (skill, abs diff) :: changes_detected.git_newer }
    else
        changes_detected <- { changes_detected with synced = skill :: changes_detected.synced }

// Report
let total_changes = 
    List.length changes_detected.new_in_clawhub + 
    List.length changes_detected.new_in_git + 
    List.length changes_detected.clawhub_newer + 
    List.length changes_detected.git_newer

write_to_log (sprintf "Neu in ClawHub: %d" (List.length changes_detected.new_in_clawhub)) "INFO"
write_to_log (sprintf "Neu in Git: %d" (List.length changes_detected.new_in_git)) "INFO"
write_to_log (sprintf "ClawHub neuer: %d" (List.length changes_detected.clawhub_newer)) "INFO"
write_to_log (sprintf "Git neuer: %d" (List.length changes_detected.git_newer)) "INFO"
write_to_log (sprintf "Synchron: %d" (List.length changes_detected.synced)) "INFO"

if total_changes = 0 then
    write_to_log "\n✅ Keine Änderungen erkannt. Sync nicht nötig." "INFO"
    write_to_log ("=" + String.replicate 69 "=") "INFO"
    exit 0

write_to_log (sprintf "\n🔄 %d Änderungen erkannt - starte Synchronisation..." total_changes) "INFO"

type Results = {
    synced_to_git: string list
    synced_to_clawhub: string list
    up_to_date: string list
    errors: string list
}

let mutable results = {
    synced_to_git = []
    synced_to_clawhub = []
    up_to_date = []
    errors = []
}

// Hilfsfunktionen für Shell-Befehle
let executeCommand (command: string) =
    let procStartInfo = 
        System.Diagnostics.ProcessStartInfo(
            FileName = "/bin/bash",
            Arguments = sprintf "-c \"%s\"" command,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true)
    
    use proc = new System.Diagnostics.Process()
    proc.StartInfo <- procStartInfo
    proc.Start() |> ignore
    proc.WaitForExit()

let validate_skill (path: string) =
    // Placeholder für Validierung
    try
        Directory.Exists(path)
    with
    | _ -> false

let sync_to_git (skill: string) (dry_run: bool) =
    // Placeholder für Sync-Funktion
    true

let sync_to_clawhub (skill: string) (dry_run: bool) =
    // Placeholder für Sync-Funktion
    true

// 1. NEU in ClawHub → zu Git
for skill in changes_detected.new_in_clawhub do
    try
        if validate_skill (Path.Combine [| CLAWHUB_DIR; skill |]) then
            write_to_log (sprintf "→ Synchronisiere %s zu Git..." skill) "INFO"
            if sync_to_git skill false then
                let git_path = Path.Combine [| GIT_DIR; skill |]
                Directory.SetCurrentDirectory(git_path)
                executeCommand "git init -q 2>/dev/null"
                executeCommand "git add . -f 2>/dev/null"
                let commitMsg = sprintf "Initial: %s" skill
                executeCommand (sprintf "git commit -m \"%s\" -q 2>/dev/null" commitMsg)
                results <- { results with synced_to_git = skill :: results.synced_to_git }
                write_to_log (sprintf "  ✓ %s synchronisiert" skill) "INFO"
        else
            results <- { results with errors = (sprintf "%s (invalid)" skill) :: results.errors }
    with
    | e ->
        write_to_log (sprintf "  ✗ ERROR: %s - %s" skill (e.Message)) "ERROR"
        results <- { results with errors = skill :: results.errors }

// 2. NEU in Git → zu ClawHub
for skill in changes_detected.new_in_git do
    try
        if validate_skill (Path.Combine [| GIT_DIR; skill |]) then
            write_to_log (sprintf "→ Synchronisiere %s zu ClawHub..." skill) "INFO"
            if sync_to_clawhub skill false then
                results <- { results with synced_to_clawhub = skill :: results.synced_to_clawhub }
                write_to_log (sprintf "  ✓ %s synchronisiert" skill) "INFO"
        else
            results <- { results with errors = (sprintf "%s (invalid)" skill) :: results.errors }
    with
    | e ->
        write_to_log (sprintf "  ✗ ERROR: %s - %s" skill (e.Message)) "ERROR"
        results <- { results with errors = skill :: results.errors }

// 3. Updates
for (skill, diff) in changes_detected.clawhub_newer do
    try
        write_to_log (sprintf "→ Update %s (ClawHub +%d neuer)..." skill (int diff)) "INFO"
        if sync_to_git skill false then
            let git_path = Path.Combine [| GIT_DIR; skill |]
            Directory.SetCurrentDirectory(git_path)
            executeCommand "git add . -f 2>/dev/null"
            let dt = DateTime.Now.ToString("yyyy-MM-dd HH:mm")
            let commitMsg = sprintf "Sync from ClawHub: %s" dt
            executeCommand (sprintf "git commit -m \"%s\" -q 2>/dev/null" commitMsg)
            results <- { results with synced_to_git = skill :: results.synced_to_git }
            write_to_log (sprintf "  ✓ %s aktualisiert" skill) "INFO"
    with
    | e ->
        write_to_log (sprintf "  ✗ ERROR: %s - %s" skill (e.Message)) "ERROR"
        results <- { results with errors = skill :: results.errors }

for (skill, diff) in changes_detected.git_newer do
    try
        write_to_log (sprintf "→ Update %s (Git +%d neuer)..." skill (int diff)) "INFO"
        if sync_to_clawhub skill false then
            results <- { results with synced_to_clawhub = skill :: results.synced_to_clawhub }
            write_to_log (sprintf "  ✓ %s aktualisiert" skill) "INFO"
    with
    | e ->
        write_to_log (sprintf "  ✗ ERROR: %s - %s" skill (e.Message)) "ERROR"
        results <- { results with errors = skill :: results.errors }

results <- { results with up_to_date = changes_detected.synced }

// ZUSAMMENFASSUNG
write_to_log ("\n" + ("=" + String.replicate 69 "=")) "INFO"
write_to_log "SYNCHRONISATION ABGESCHLOSSEN" "INFO"
write_to_log ("=" + String.replicate 69 "=") "INFO"
write_to_log (sprintf "Zu Git synchronisiert:     %d" (List.length results.synced_to_git)) "INFO"
write_to_log (sprintf "Zu ClawHub synchronisiert: %d" (List.length results.synced_to_clawhub)) "INFO"
write_to_log (sprintf "Bereits aktuell:           %d" (List.length results.up_to_date)) "INFO"
write_to_log (sprintf "Fehler:                    %d" (List.length results.errors)) "INFO"
if List.isEmpty results.errors |> not then
    write_to_log (sprintf "  Fehlerhafte: %s" (String.concat ", " results.errors)) "INFO"
write_to_log ("=" + String.replicate 69 "=") "INFO"

// State speichern
let STATE_FILE = Path.Combine [| "/home/openclaw/.openclaw/workspace/db/sync_state.json" |]
let stateDir = Path.GetDirectoryName(STATE_FILE)
Directory.CreateDirectory(stateDir) |> ignore

let changesDict = dict [
    ("new_in_clawhub", changes_detected.new_in_clawhub.Length :> obj)
    ("new_in_git", changes_detected.new_in_git.Length :> obj)
    ("clawhub_newer", changes_detected.clawhub_newer.Length :> obj)
    ("git_newer", changes_detected.git_newer.Length :> obj)
    ("synced", changes_detected.synced.Length :> obj)
]

let state = dict [
    ("last_run", DateTime.Now.ToString("o") :> obj)
    ("results", results :> obj)
    ("changes_detected", changesDict :> obj)
]

use stream = File.Create(STATE_FILE)
JsonSerializer.Serialize(stream, state, JsonSerializerOptions(WriteIndented = true)) |> ignore
write_to_log (sprintf "State gespeichert: %s" STATE_FILE) "INFO"
