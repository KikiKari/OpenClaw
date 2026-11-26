// abstraction-provenance: {"artifact_sha256": "8d3f3c436c208680b06d3af272e7a179997846a9de85375f45ce4721d377e94e", "source_sha256": "86aad5ae0d9b77ebdb9a2aaecbf0c4875ad3a241571b573934c882ecd55df14e", "target_language": "fsharp"}
// node_health.py — portiert nach fsharp
// Quelle: python, workspace@local:git/skills/node-health-monitor/scripts/node_health.py
// auch in: workspace@local:skills/node-health-monitor/scripts/node_health.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

module NodeHealth

open System
open System.IO
open System.Diagnostics
open System.Text.Json
open System.Collections.Generic

// Konfiguration
let workspace = Path.Combine(Environment.GetEnvironmentVariable("HOME"), ".openclaw", "workspace")
let healthDb = Path.Combine(workspace, "db", "health.db")
let logFile = Path.Combine(workspace, "logs", "node-health.log")

// Node-Definitionen
let nodes = dict [
    ("node1", dict [("name", "Gateway"); ("host", "localhost"); ("user", "openclaw"); ("critical", "True")])
    ("node2", dict [("name", "Node2"); ("host", "100.82.198.122"); ("user", "root"); ("ssh_key", "/root/.ssh/id_ed25519_openclaw_admin")])
    ("node3", dict [("name", "Node3"); ("host", "100.73.154.125"); ("user", "root"); ("disk_warning", "85")])
    ("node4", dict [("name", "Redmi"); ("host", "100.94.134.39"); ("optional", "True"); ("ssh_enabled", "False")])
    ("node5", dict [("name", "Lenovo"); ("host", "100.103.140.35"); ("optional", "True"); ("ssh_enabled", "False")])
]

let log (message: string) (level: string) =
    let timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
    let entry = sprintf "[%s] [%s] %s" timestamp level message
    printfn "%s" entry
    Directory.CreateDirectory(Path.GetDirectoryName(logFile)) |> ignore
    File.AppendAllText(logFile, entry + "\n")

let checkPing (host: string) (timeout: int) =
    try
        let psi = ProcessStartInfo("ping", sprintf "-c 1 -W %d %s" timeout host)
        psi.UseShellExecute <- false
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        let proc = Process.Start(psi)
        proc.WaitForExit()
        proc.ExitCode = 0
    with
    | _ -> false

let checkSsh (nodeConfig: IDictionary<string, string>) =
    if nodeConfig.ContainsKey("ssh_enabled") && nodeConfig.["ssh_enabled"] = "False" then
        false
    else
        let host = nodeConfig.["host"]
        let user = if nodeConfig.ContainsKey("user") then nodeConfig.["user"] else "root"
        let mutable cmd = ["ssh"; "-o"; "ConnectTimeout=10"; "-o"; "BatchMode=yes"]
        if nodeConfig.ContainsKey("ssh_key") then
            cmd <- cmd @ ["-i"; Path.GetFullPath(nodeConfig.["ssh_key"]); "-o"; "IdentitiesOnly=yes"]
        cmd <- cmd @ [sprintf "%s@%s" user host; "echo OK"]
        
        try
            let psi = ProcessStartInfo()
            psi.FileName <- "ssh"
            psi.Arguments <- String.Join(" ", List.skip 1 cmd)
            psi.UseShellExecute <- false
            psi.RedirectStandardOutput <- true
            psi.RedirectStandardError <- true
            let proc = Process.Start(psi)
            proc.WaitForExit()
            proc.ExitCode = 0 && proc.StandardOutput.ReadToEnd().Contains("OK")
        with
        | _ -> false

let getNodeMetrics (nodeConfig: IDictionary<string, string>) =
    let metrics = Dictionary<string, obj>()
    metrics.Add("timestamp", DateTime.Now.ToString("o"))
    metrics.Add("available", box false)
    metrics.Add("cpu", null)
    metrics.Add("ram", null)
    metrics.Add("disk", null)
    metrics.Add("load", null)
    
    if nodeConfig.ContainsKey("ssh_enabled") && nodeConfig.["ssh_enabled"] = "False" then
        metrics
    else
        let host = nodeConfig.["host"]
        let user = if nodeConfig.ContainsKey("user") then nodeConfig.["user"] else "root"
        
        let remoteCmd = """
            # CPU
            echo "CPU:$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d"%" -f1)"
            
            # RAM
            echo "RAM:$(free | grep Mem | awk '{print ($3/$2) * 100.0}')"
            
            # Disk
            echo "DISK:$(df -h / | tail -1 | awk '{print $5}' | tr -d "%")"
            
            # Load
            echo "LOAD:$(uptime | awk -F"load average:" "{print $2}" | awk '{print $1}' | tr -d ",")"
            
            # Gateway Status
            if command -v openclaw >/dev/null 2>&1; then
                printf "GATEWAY:%s\n" "$(systemctl is-active openclaw-gateway 2>/dev/null || true)"
            fi
        """
        
        let mutable cmd = ["ssh"; "-o"; "ConnectTimeout=10"; "-o"; "BatchMode=yes"]
        if nodeConfig.ContainsKey("ssh_key") then
            cmd <- cmd @ ["-i"; Path.GetFullPath(nodeConfig.["ssh_key"]); "-o"; "IdentitiesOnly=yes"]
        cmd <- cmd @ [sprintf "%s@%s" user host; remoteCmd]
        
        try
            let psi = ProcessStartInfo()
            psi.FileName <- "ssh"
            psi.Arguments <- String.Join(" ", (List.skip 1 cmd))
            psi.UseShellExecute <- false
            psi.RedirectStandardOutput <- true
            psi.RedirectStandardError <- true
            let proc = Process.Start(psi)
            if proc.WaitForExit(15000) then
                if proc.ExitCode = 0 then
                    metrics.["available"] <- box true
                    for line in proc.StandardOutput.ReadToEnd().Trim().Split('\n') do
                        if line.Contains(":") then
                            let parts = line.Split(':')
                            let key = parts.[0].Trim()
                            let value = parts.[1].Trim()
                            match key with
                            | "CPU" -> metrics.["cpu"] <- box (float value)
                            | "RAM" -> metrics.["ram"] <- box (float value)
                            | "DISK" -> metrics.["disk"] <- box (int value)
                            | "LOAD" -> metrics.["load"] <- box (float value)
                            | "GATEWAY" -> metrics.["gateway_status"] <- box value
                            | _ -> ()
            metrics
        with
        | :? TimeoutException ->
            log (sprintf "SSH timeout for %s" (nodeConfig.["name"])) "WARN"
            metrics
        | ex ->
            log (sprintf "Error checking %s: %s" (nodeConfig.["name"]) ex.Message) "ERROR"
            metrics

let checkAlerts (nodeId: string) (nodeConfig: IDictionary<string, string>) (metrics: IDictionary<string, obj>) =
    let alerts = ResizeArray<Dictionary<string, string>>()
    
    // Verfügbarkeit
    if not ((metrics.["available"] :?> bool)) then
        if not (nodeConfig.ContainsKey("optional") && nodeConfig.["optional"] = "True") then
            let alert = Dictionary<string, string>()
            alert.Add("level", "CRITICAL")
            alert.Add("message", sprintf "Node %s nicht erreichbar!" nodeConfig.["name"])
            alerts.Add(alert)
    else
        // CPU
        if metrics.["cpu"] <> null && (metrics.["cpu"] :?> float) > 90.0 then
            let alert = Dictionary<string, string>()
            alert.Add("level", "WARNING")
            alert.Add("message", sprintf "Node %s: CPU bei %.1f%%" nodeConfig.["name"] (metrics.["cpu"] :?> float))
            alerts.Add(alert)
        
        // RAM
        if metrics.["ram"] <> null && (metrics.["ram"] :?> float) > 90.0 then
            let alert = Dictionary<string, string>()
            alert.Add("level", "WARNING")
            alert.Add("message", sprintf "Node %s: RAM bei %.1f%%" nodeConfig.["name"] (metrics.["ram"] :?> float))
            alerts.Add(alert)
        
        // Disk
        let diskThreshold = if nodeConfig.ContainsKey("disk_warning") then int nodeConfig.["disk_warning"] else 85
        if metrics.["disk"] <> null && (metrics.["disk"] :?> int) > diskThreshold then
            let level = if (metrics.["disk"] :?> int) > 95 then "CRITICAL" else "WARNING"
            let alert = Dictionary<string, string>()
            alert.Add("level", level)
            alert.Add("message", sprintf "Node %s: Disk bei %d%%" nodeConfig.["name"] (metrics.["disk"] :?> int))
            alerts.Add(alert)
        
        // Gateway
        if nodeConfig.ContainsKey("critical") && nodeConfig.["critical"] = "True" && 
           metrics.ContainsKey("gateway_status") && (metrics.["gateway_status"] :?> string) = "inactive" then
            let alert = Dictionary<string, string>()
            alert.Add("level", "CRITICAL")
            alert.Add("message", sprintf "Node %s: OpenClaw Gateway nicht aktiv!" nodeConfig.["name"])
            alerts.Add(alert)
    
    alerts

let sendAlert (alert: IDictionary<string, string>) =
    try
        let scriptPath = Path.Combine(workspace, "skills", "channel-status-agent", "scripts", "channel_status.py")
        let psi = ProcessStartInfo("python3", sprintf "\"%s\" --type alert --message \"%s: %s\"" scriptPath alert.["level"] alert.["message"])
        psi.UseShellExecute <- false
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        let proc = Process.Start(psi)
        proc.WaitForExit()
        log (sprintf "Alert sent: %s" alert.["message"]) "INFO"
    with
    | ex -> log (sprintf "Failed to send alert: %s" ex.Message) "ERROR"

[<EntryPoint>]
let main argv =
    let args = argv |> List.ofArray
    
    let nodeArg = 
        let idx = args |> List.tryFindIndex ((=) "--node")
        match idx with
        | Some i when i + 1 < args.Length -> args.[i + 1]
        | _ -> "all"
    
    let checkArg = 
        let idx = args |> List.tryFindIndex ((=) "--check")
        match idx with
        | Some i when i + 1 < args.Length -> args.[i + 1]
        | _ -> "all"
    
    let alertFlag = args |> List.contains "--alert"
    
    // Nodes bestimmen
    let nodesToCheck = 
        if nodeArg = "all" then
            nodes
        else
            if nodes.ContainsKey(nodeArg) then
                dict [(nodeArg, nodes.[nodeArg])]
            else
                log (sprintf "Unknown node: %s" nodeArg) "ERROR"
                exit 1
    
    // Health-Checks durchführen
    let allAlerts = ResizeArray<Dictionary<string, string>>()
    
    for kvp in nodesToCheck do
        let nodeId = kvp.Key
        let nodeConfig = kvp.Value
        log (sprintf "Checking %s (%s)" nodeConfig.["name"] nodeId) "INFO"
        
        // Ping
        if checkArg = "ping" || checkArg = "all" then
            if nodeConfig.["host"] <> "localhost" then
                let pingOk = checkPing nodeConfig.["host"] 5
                log (sprintf "  Ping: %s" (if pingOk then "OK" else "FAILED")) "INFO"
        
        // SSH
        if checkArg = "ssh" || checkArg = "all" then
            if nodeConfig.ContainsKey("ssh_enabled") && nodeConfig.["ssh_enabled"] = "False" then
                log "  SSH: SKIPPED (nicht konfiguriert)" "INFO"
            else
                let sshOk = checkSsh nodeConfig
                log (sprintf "  SSH: %s" (if sshOk then "OK" else "FAILED")) "INFO"
        
        // Metriken
        if checkArg = "metrics" || checkArg = "all" then
            let metrics = getNodeMetrics nodeConfig
            
            if metrics.["available"] :?> bool then
                if metrics.["cpu"] <> null then
                    log (sprintf "  CPU: %.1f%%" (metrics.["cpu"] :?> float)) "INFO"
                else
                    log "  CPU: N/A" "INFO"
                
                if metrics.["ram"] <> null then
                    log (sprintf "  RAM: %.1f%%" (metrics.["ram"] :?> float)) "INFO"
                else
                    log "  RAM: N/A" "INFO"
                
                if metrics.["disk"] <> null then
                    log (sprintf "  Disk: %d%%" (metrics.["disk"] :?> int)) "INFO"
                else
                    log "  Disk: N/A" "INFO"
                
                if metrics.["load"] <> null then
                    log (sprintf "  Load: %f" (metrics.["load"] :?> float)) "INFO"
                else
                    log "  Load: N/A" "INFO"
            else
                log "  Metrics: UNAVAILABLE" "INFO"
            
            // Alerts prüfen
            let alerts = checkAlerts nodeId nodeConfig metrics
            for alert in alerts do
                allAlerts.Add(alert)
    
    // Alerts senden
    if alertFlag && allAlerts.Count > 0 then
        log (sprintf "\nSending %d alerts..." allAlerts.Count) "INFO"
        for alert in allAlerts do
            sendAlert alert
    elif allAlerts.Count > 0 then
        log (sprintf "\n%d alerts found (use --alert to send)" allAlerts.Count) "INFO"
    else
        log "\nPrüfung abgeschlossen; Details und nicht verfügbare Prüfungen siehe oben." "INFO"
    
    0
