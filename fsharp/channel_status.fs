// abstraction-provenance: {"artifact_sha256": "c1697fb4068657015de3da67815ad71b83dd595acbdccd9d9ee0d0a77198275f", "source_sha256": "d23aced948e2cbccfa5bfa57ad3b48adfc5d5f7a42c2fbdf665f8c185b8545eb", "target_language": "fsharp"}
// channel_status.py — portiert nach fsharp
// Quelle: python, workspace@local:git/skills/channel-status-agent/scripts/channel_status.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

module ChannelStatus

open System
open System.Diagnostics
open System.IO
open System.Text.Json
open System.Collections.Generic

// Konfiguration
let WORKSPACE = "/home/openclaw/.openclaw/workspace"
let LOGS_DB = Path.Combine(WORKSPACE, "db/logs.db")
let CONFIG_FILE = Path.Combine(WORKSPACE, "config/channel-status.json")
let LOG_FILE = Path.Combine(WORKSPACE, "logs/channel-status.log")

let log (message: string) (level: string) =
    let timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
    let entry = sprintf "[%s] [%s] %s" timestamp level message
    printfn "%s" entry
    Directory.CreateDirectory(Path.GetDirectoryName(LOG_FILE)) |> ignore
    File.AppendAllText(LOG_FILE, entry + "\n")

let NODE_NAMES = 
    dict [
        "node2", set ["openclaw-node2"; "arm64-node"; "v2202604104722449961"; "v22026041047222449961.taild25fea.ts.net"; "100.82.198.122"]
        "node3", set ["openclaw-node3"; "openclaw-node3.taild25fea.ts.net"; "100.73.154.125"]
        "node4", set ["openclaw-node4"; "redmi-note-11s"; "redmi-note-11s.taild25fea.ts.net"; "100.94.134.39"]
        "node5", set ["openclaw-node5"; "lenovo-node7"; "lenovo-node7.taild25fea.ts.net"; "100.103.140.35"]
    ]

let fetchNodeStatus () =
    try
        let startInfo = ProcessStartInfo("openclaw", "nodes status --json")
        startInfo.UseShellExecute <- false
        startInfo.RedirectStandardOutput <- true
        startInfo.RedirectStandardError <- true
        use proc = Process.Start(startInfo)
        proc.WaitForExit(10000) |> ignore
        if proc.ExitCode <> 0 then failwith "Process failed"
        
        let output = proc.StandardOutput.ReadToEnd()
        let payload = JsonSerializer.Deserialize<JsonElement>(output)
        
        if payload.ValueKind <> JsonValueKind.Object then None
        elif not (payload.TryGetProperty("nodes", Nullable<JsonElement>())) then None
        else
            let nodesProp = payload.GetProperty("nodes")
            if nodesProp.ValueKind <> JsonValueKind.Array then None
            else
                let states = Dictionary<string, bool>()
                for kvp in NODE_NAMES do states.[kvp.Key] <- false
                
                for item in nodesProp.EnumerateArray() do
                    if item.ValueKind = JsonValueKind.Object then
                        let names = HashSet<string>()
                        for key in ["displayName"; "nodeId"; "remoteIp"] do
                            match item.TryGetProperty(key) with
                            | true, prop -> names.Add(prop.GetString().ToLower()) |> ignore
                            | _ -> ()
                        
                        for nodeAliases in NODE_NAMES do
                            let node = nodeAliases.Key
                            let aliases = nodeAliases.Value
                            if Set.intersect names aliases |> Set.isEmpty |> not then
                                match item.TryGetProperty("connected") with
                                | true, connected when connected.GetBoolean() -> states.[node] <- true
                                | _ -> ()
                
                states.["node1"] <- true // successful Gateway status request
                Some(states)
    with
    | _ -> None

let getSystemStatus () =
    let status = Dictionary<string, obj>()
    status.["timestamp"] <- DateTime.Now.ToString("o")
    status.["nodes"] <- Dictionary<string, obj>()
    status.["agents"] <- Dictionary<string, obj>()
    status.["system"] <- Dictionary<string, string>()
    
    let states = fetchNodeStatus()
    let names = dict [("node1", "Gateway"); ("node2", "Node2"); ("node3", "Node3"); ("node4", "Redmi"); ("node5", "Lenovo")]
    let nodesDict = status.["nodes"] :?> Dictionary<string, obj>
    
    for node in names.Keys do
        let nodeInfo = Dictionary<string, string>()
        nodeInfo.["name"] <- names.[node]
        match states with
        | None -> nodeInfo.["status"] <- "unknown"
        | Some(s) -> nodeInfo.["status"] <- if s.[node] then "online" else "offline"
        nodesDict.[node] <- nodeInfo :> obj
    
    // Agent-Status aus Cron
    let agentsDict = status.["agents"] :?> Dictionary<string, obj>
    try
        let startInfo = ProcessStartInfo("crontab", "-l")
        startInfo.UseShellExecute <- false
        startInfo.RedirectStandardOutput <- true
        use proc = Process.Start(startInfo)
        proc.WaitForExit() |> ignore
        let output = proc.StandardOutput.ReadToEnd()
        let cronLines = output.Split('\n').Length - output.Split('#').Length
        agentsDict.["active_crons"] <- box cronLines
    with
    | _ -> agentsDict.["active_crons"] <- "unknown" :> obj
    
    // System-Metriken
    let systemDict = status.["system"] :?> Dictionary<string, string>
    try
        // Disk usage
        let startInfo = ProcessStartInfo("df", "-h /")
        startInfo.UseShellExecute <- false
        startInfo.RedirectStandardOutput <- true
        use proc = Process.Start(startInfo)
        proc.WaitForExit() |> ignore
        let output = proc.StandardOutput.ReadToEnd()
        for line in output.Split('\n') do
            if line.Contains("/") && line.Contains("%") then
                let parts = line.Split(' ', System.StringSplitOptions.RemoveEmptyEntries)
                if parts.Length > 4 then
                    systemDict.["disk_used"] <- parts.[4]
                break
        
        // RAM usage
        let startInfo = ProcessStartInfo("free", "-h")
        startInfo.UseShellExecute <- false
        startInfo.RedirectStandardOutput <- true
        use proc = Process.Start(startInfo)
        proc.WaitForExit() |> ignore
        let output = proc.StandardOutput.ReadToEnd()
        for line in output.Split('\n') do
            if line.Contains("Mem:") then
                let parts = line.Split(' ', System.StringSplitOptions.RemoveEmptyEntries)
                if parts.Length > 2 then
                    systemDict.["ram_total"] <- parts.[1]
                    systemDict.["ram_used"] <- parts.[2]
                break
    with
    | _ -> ()
    
    status

let formatDailyStatus (status: Dictionary<string, obj>) =
    let nodes = status.["nodes"] :?> Dictionary<string, obj>
    let onlineCount = nodes.Values |> Seq.cast<Dictionary<string, string>> |> Seq.filter (fun n -> n.["status"] = "online") |> Seq.length
    
    let mutable message = sprintf "📊 **Täglicher Status-Report**\n🗓️ %s\n\n**🖥️ Nodes (%d/%d online):**\n" (DateTime.Now.ToString("yyyy-MM-dd HH:mm")) onlineCount nodes.Count
    
    for nodeKvp in nodes do
        let info = nodeKvp.Value :?> Dictionary<string, string>
        let emoji = 
            match info.["status"] with
            | "online" -> "🟢"
            | "offline" -> "🔴"
            | _ -> "🟡"
        message <- message + sprintf "%s %s: %s" emoji info.["name"] info.["status"]
        if info.ContainsKey("reason") then
            message <- message + sprintf " (%s)" info.["reason"]
        message <- message + "\n"
    
    message <- message + "\n**🤖 Agents:**\n"
    let agents = status.["agents"] :?> Dictionary<string, obj>
    message <- message + sprintf "Aktive Cron-Jobs: %A\n" agents.["active_crons"]
    
    let system = status.["system"] :?> Dictionary<string, string>
    if system.ContainsKey("disk_used") then
        message <- message + "\n**💾 System:**\n"
        message <- message + sprintf "Disk: %s belegt\n" system.["disk_used"]
        message <- message + sprintf "RAM: %s / %s\n" system.["ram_used"] system.["ram_total"]
    
    message

let formatWeeklyStatus (status: Dictionary<string, obj>) =
    let lines = [
        "📈 **Wöchentlicher Report**"
        sprintf "📅 Woche %s - %s" (DateTime.Now.ToString("VV")) (DateTime.Now.ToString("yyyy"))
        ""
        "**Nodes:**"
    ]
    
    let nodes = status.["nodes"] :?> Dictionary<string, obj>
    let nodeLines = 
        nodes.Values 
        |> Seq.cast<Dictionary<string, string>>
        |> Seq.map (fun item -> sprintf "- %s: %s" item.["name"] item.["status"])
        |> List.ofSeq
    
    String.concat "\n" (lines @ nodeLines) + "\n"

let sendToChannel (message: string) (channelType: string) (channelId: string) =
    if channelType = "telegram" then
        let cmd = sprintf "openclaw message send --target %s --message \"%s\"" channelId (message.Replace("\"", "\\\""))
        try
            let startInfo = ProcessStartInfo("bash", sprintf "-c \"%s\"" cmd)
            startInfo.UseShellExecute <- false
            startInfo.RedirectStandardOutput <- true
            startInfo.RedirectStandardError <- true
            use proc = Process.Start(startInfo)
            proc.WaitForExit() |> ignore
            if proc.ExitCode = 0 then
                log (sprintf "Message sent to %s %s" channelType channelId) "INFO"
                true
            else
                let stderr = proc.StandardError.ReadToEnd()
                log (sprintf "Failed to send: %s" stderr) "ERROR"
                false
        with
        | ex -> 
            log (sprintf "Send error: %s" ex.Message) "ERROR"
            false
    else
        log (sprintf "Channel type %s not implemented" channelType) "WARN"
        false

[<EntryPoint>]
let main argv =
    Directory.CreateDirectory(Path.GetDirectoryName(LOG_FILE)) |> ignore
    
    let args = argv |> List.ofArray
    let argType = 
        match args |> List.tryFindIndex ((=) "--type") with
        | Some(i) when i + 1 < args.Length -> args.[i + 1]
        | _ -> ""
    
    let message = 
        match args |> List.tryFindIndex ((=) "--message") with
        | Some(i) when i + 1 < args.Length -> args.[i + 1]
        | _ -> ""
    
    let channel = 
        match args |> List.tryFindIndex ((=) "--channel") with
        | Some(i) when i + 1 < args.Length -> args.[i + 1]
        | _ -> "-1002381931352"
    
    let dryRun = args |> List.contains "--dry-run"
    
    log (sprintf "Starting %s status update" argType) "INFO"
    
    // Status sammeln
    let status = getSystemStatus()
    
    // Message formatieren
    let formattedMessage = 
        match argType with
        | "daily" -> formatDailyStatus status
        | "weekly" -> formatWeeklyStatus status
        | "alert" -> sprintf "🚨 **ALERT**\n%s" (if String.IsNullOrEmpty(message) then "Manual alert" else message)
        | _ -> ""
    
    // Senden oder Dry-Run
    if dryRun then
        printfn "\n--- DRY RUN ---"
        printfn "%s" formattedMessage
        printfn "--- END ---"
    else
        sendToChannel formattedMessage "telegram" channel |> ignore
    
    log "Status update completed" "INFO"
    0
