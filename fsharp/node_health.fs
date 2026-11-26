// abstraction-provenance: {"artifact_sha256": "c8ffbd9374166f882339869fdaa1c16e03755403226b99f6b1ab77fdd2cb860a", "source_sha256": "8cb73cb9ea3a2ccee09205fcea5d8d2e1f29c369b21a3dfcf948b8029436a339", "target_language": "fsharp"}
// node_health.py — portiert nach fsharp
// Quelle: python, OpenClaw@gateway1:skills/node-health-monitor/scripts/node_health.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

// Node Health Monitor - Multi-Node Gesundheitsüberwachung

open System
open System.IO
open System.Diagnostics
open System.Collections.Generic
open Newtonsoft.Json

// Konfiguration
let WORKSPACE = Path.Combine(Environment.GetEnvironmentVariable("HOME"), ".openclaw", "workspace")
let HEALTH_DB = Path.Combine(WORKSPACE, "db", "health.db")
let LOG_FILE = Path.Combine(WORKSPACE, "logs", "node-health.log")

// Node-Definitionen
let NODES = dict [
    ("node1", dict [
        ("name", "Gateway" :> obj)
        ("host", "localhost" :> obj)
        ("user", "openclaw" :> obj)
        ("critical", true :> obj)
    ])
    ("node2", dict [
        ("name", "Worker" :> obj)
        ("host", "100.92.155.34" :> obj)
        ("user", "root" :> obj)
        ("ssh_key", "~/.ssh/id_rsa" :> obj)
    ])
    ("node3", dict [
        ("name", "Relay" :> obj)
        ("host", "185.242.xxx.xxx" :> obj)
        ("user", "root" :> obj)
        ("disk_warning", 85 :> obj)
    ])
    ("node5", dict [
        ("name", "Redmi" :> obj)
        ("host", "192.168.1.x" :> obj)
        ("user", "openclaw" :> obj)
        ("optional", true :> obj)
    ])
]

let log (message: string) (level: string) =
    /// Logging
    let timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
    let entry = sprintf "[%s] [%s] %s" timestamp level message
    printfn "%s" entry
    Directory.CreateDirectory(Path.GetDirectoryName(LOG_FILE)) |> ignore
    File.AppendAllLines(LOG_FILE, [entry])

let checkPing (host: string) (timeout: int) =
    /// Prüft Erreichbarkeit
    try
        let psi = ProcessStartInfo("ping", sprintf "-c 1 -W %d %s" timeout host)
        psi.UseShellExecute <- false
        psi.RedirectStandardOutput <- true
        let proc = Process.Start(psi)
        proc.WaitForExit()
        proc.ExitCode = 0
    with
    | _ -> false

let checkSsh (nodeConfig: IDictionary<string, obj>) =
    /// Prüft SSH-Verbindung
    let host = nodeConfig.["host"].ToString()
    let user = if nodeConfig.ContainsKey("user") then nodeConfig.["user"].ToString() else "root"
    
    let cmd = ["ssh"; "-o"; "ConnectTimeout=10"; "-o"; "BatchMode=yes";
               sprintf "%s@%s" user host; "echo \"OK\""]
    
    try
        let psi = ProcessStartInfo("ssh")
        psi.Arguments <- String.concat " " (List.tail cmd)
        psi.UseShellExecute <- false
        psi.RedirectStandardOutput <- true
        let proc = Process.Start(psi)
        let output = proc.StandardOutput.ReadToEnd()
        proc.WaitForExit()
        proc.ExitCode = 0 && output.Contains("OK")
    with
    | _ -> false

let getNodeMetrics (nodeConfig: IDictionary<string, obj>) =
    /// Holt Metriken via SSH
    let host = nodeConfig.["host"].ToString()
    let user = if nodeConfig.ContainsKey("user") then nodeConfig.["user"].ToString() else "root"
    
    let metrics = Dictionary<string, obj>()
    metrics.["timestamp"] <- DateTime.Now.ToString("o") :> obj
    metrics.["available"] <- false :> obj
    metrics.["cpu"] <- null :> obj
    metrics.["ram"] <- null :> obj
    metrics.["disk"] <- null :> obj
    metrics.["load"] <- null :> obj
    
    // SSH-Command für alle Metriken
    let cmd = sprintf """
        ssh -o ConnectTimeout=10 %s@%s '
            # CPU
            echo "CPU:$(top -bn1 | grep "Cpu(s)" | awk "{print \$2}" | cut -d"%%" -f1)"
            
            # RAM
            echo "RAM:$(free | grep Mem | awk "{print (\$3/\$2) * 100.0}")"
            
            # Disk
            echo "DISK:$(df -h / | tail -1 | awk "{print \$5}" | tr -d "%%")"
            
            # Load
            echo "LOAD:$(uptime | awk -F"load average:" "{print \$2}" | awk "{print \$1}" | tr -d ",")"
            
            # Gateway Status
            if command -v openclaw >/dev/null 2>&1; then
                systemctl is-active openclaw-gateway 2>/dev/null || echo "GATEWAY:inactive"
            fi
        '
    """ user host
    
    try
        let psi = ProcessStartInfo("bash")
        psi.Arguments <- sprintf "-c \"%s\"" cmd
        psi.UseShellExecute <- false
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        let proc = Process.Start(psi)
        let outputTask = proc.StandardOutput.ReadToEndAsync()
        let errorTask = proc.StandardError.ReadToEndAsync()
        let finished = proc.WaitForExit(15000)
        
        if finished && proc.ExitCode = 0 then
            metrics.["available"] <- true :> obj
            let output = outputTask.Result
            
            for line in output.Trim().Split('\n') do
                if line.Contains(":") then
                    let parts = line.Split(':')
                    let key = parts.[0].Trim()
                    let value = parts.[1].Trim()
                    match key with
                    | "CPU" -> 
                        if Double.TryParse(value, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, ref 0.0) then
                            metrics.["cpu"] <- float value :> obj
                    | "RAM" -> 
                        if Double.TryParse(value, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, ref 0.0) then
                            metrics.["ram"] <- float value :> obj
                    | "DISK" -> 
                        if Int32.TryParse(value) then
                            metrics.["disk"] <- int value :> obj
                    | "LOAD" -> 
                        if Double.TryParse(value, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, ref 0.0) then
                            metrics.["load"] <- float value :> obj
                    | "GATEWAY" -> metrics.["gateway_status"] <- value :> obj
                    | _ -> ()
    with
    | :? TimeoutException -> log (sprintf "SSH timeout for %s" (nodeConfig.["name"].ToString())) "WARN"
    | ex -> log (sprintf "Error checking %s: %s" (nodeConfig.["name"].ToString()) ex.Message) "ERROR"
    
    metrics

let checkAlerts (nodeId: string) (nodeConfig: IDictionary<string, obj>) (metrics: IDictionary<string, obj>) =
    /// Prüft Schwellwerte und generiert Alerts
    let alerts = ResizeArray<Dictionary<string, string>>()
    
    // Verfügbarkeit
    if not ((metrics.["available"] :?> bool)) then
        if not (nodeConfig.ContainsKey("optional") && (nodeConfig.["optional"] :?> bool)) then
            let alert = Dictionary<string, string>()
            alert.["level"] <- "CRITICAL"
            alert.["message"] <- sprintf "Node %s nicht erreichbar!" (nodeConfig.["name"].ToString())
            alerts.Add(alert)
    else
        // CPU
        if metrics.ContainsKey("cpu") && metrics.["cpu"] <> null then
            let cpuValue = metrics.["cpu"] :?> float
            if cpuValue > 90.0 then
                let alert = Dictionary<string, string>()
                alert.["level"] <- "WARNING"
                alert.["message"] <- sprintf "Node %s: CPU bei %.1f%%" (nodeConfig.["name"].ToString()) cpuValue
                alerts.Add(alert)
        
        // RAM
        if metrics.ContainsKey("ram") && metrics.["ram"] <> null then
            let ramValue = metrics.["ram"] :?> float
            if ramValue > 90.0 then
                let alert = Dictionary<string, string>()
                alert.["level"] <- "WARNING"
                alert.["message"] <- sprintf "Node %s: RAM bei %.1f%%" (nodeConfig.["name"].ToString()) ramValue
                alerts.Add(alert)
        
        // Disk
        if metrics.ContainsKey("disk") && metrics.["disk"] <> null then
            let diskThreshold = if nodeConfig.ContainsKey("disk_warning") then nodeConfig.["disk_warning"] :?> int else 85
            let diskValue = metrics.["disk"] :?> int
            if diskValue > diskThreshold then
                let level = if diskValue > 95 then "CRITICAL" else "WARNING"
                let alert = Dictionary<string, string>()
                alert.["level"] <- level
                alert.["message"] <- sprintf "Node %s: Disk bei %d%%" (nodeConfig.["name"].ToString()) diskValue
                alerts.Add(alert)
        
        // Gateway
        if nodeConfig.ContainsKey("critical") && (nodeConfig.["critical"] :?> bool) && 
           metrics.ContainsKey("gateway_status") && metrics.["gateway_status"].ToString() = "inactive" then
            let alert = Dictionary<string, string>()
            alert.["level"] <- "CRITICAL"
            alert.["message"] <- sprintf "Node %s: OpenClaw Gateway nicht aktiv!" (nodeConfig.["name"].ToString())
            alerts.Add(alert)
    
    alerts

let sendAlert (alert: IDictionary<string, string>) =
    /// Sendet Alert via channel-status-agent
    try
        let scriptPath = Path.Combine(WORKSPACE, "skills", "channel-status-agent", "scripts", "channel_status.py")
        let cmd = ["python3"; scriptPath; "--type"; "alert"; "--message"; sprintf "%s: %s" alert.["level"] alert.["message"]]
        
        let psi = ProcessStartInfo("python3")
        psi.Arguments <- String.concat " " (List.tail cmd)
        psi.UseShellExecute <- false
        psi.RedirectStandardOutput <- true
        let proc = Process.Start(psi)
        proc.WaitForExit() |> ignore
        log (sprintf "Alert sent: %s" alert.["message"]) "INFO"
    with
    | ex -> log (sprintf "Failed to send alert: %s" ex.Message) "ERROR"

[<EntryPoint>]
let main argv =
    /// Hauptfunktion
    let args = argv |> List.ofArray
    
    let mutable nodeArg = "all"
    let mutable checkArg = "all"
    let mutable sendAlerts = false
    
    // Simple argument parsing
    for i = 0 to args.Length - 1 do
        match args.[i] with
        | "--node" when i + 1 < args.Length -> nodeArg <- args.[i + 1]
        | "--check" when i + 1 < args.Length -> checkArg <- args.[i + 1]
        | "--alert" -> sendAlerts <- true
        | _ -> ()
    
    // Nodes bestimmen
    let nodesToCheck = 
        if nodeArg = "all" then
            NODES
        else
            let nodeDict = Dictionary<string, IDictionary<string, obj>>()
            if NODES.ContainsKey(nodeArg) then
                nodeDict.[nodeArg] <- NODES.[nodeArg]
            else
                log (sprintf "Unknown node: %s" nodeArg) "ERROR"
                exit 1
            nodeDict :> IDictionary<string, IDictionary<string, obj>>
    
    // Health-Checks durchführen
    let allAlerts = ResizeArray<Dictionary<string, string>>()
    
    for kvp in nodesToCheck do
        let nodeId = kvp.Key
        let nodeConfig = kvp.Value
        log (sprintf "Checking %s (%s)" (nodeConfig.["name"].ToString()) nodeId) "INFO"
        
        // Ping
        if (checkArg = "ping" || checkArg = "all") && nodeConfig.["host"].ToString() <> "localhost" then
            let pingOk = checkPing (nodeConfig.["host"].ToString()) 5
            log (sprintf "  Ping: %s" (if pingOk then "OK" else "FAILED")) "INFO"
        
        // SSH
        if checkArg = "ssh" || checkArg = "all" then
            let sshOk = checkSsh nodeConfig
            log (sprintf "  SSH: %s" (if sshOk then "OK" else "FAILED")) "INFO"
        
        // Metriken
        if checkArg = "metrics" || checkArg = "all" then
            let metrics = getNodeMetrics nodeConfig
            
            if (metrics.["available"] :?> bool) then
                if metrics.ContainsKey("cpu") && metrics.["cpu"] <> null then
                    log (sprintf "  CPU: %.1f%%" (metrics.["cpu"] :?> float)) "INFO"
                else
                    log "  CPU: N/A" "INFO"
                    
                if metrics.ContainsKey("ram") && metrics.["ram"] <> null then
                    log (sprintf "  RAM: %.1f%%" (metrics.["ram"] :?> float)) "INFO"
                else
                    log "  RAM: N/A" "INFO"
                    
                if metrics.ContainsKey("disk") && metrics.["disk"] <> null then
                    log (sprintf "  Disk: %d%%" (metrics.["disk"] :?> int)) "INFO"
                else
                    log "  Disk: N/A" "INFO"
                    
                if metrics.ContainsKey("load") && metrics.["load"] <> null then
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
    if sendAlerts && allAlerts.Count > 0 then
        log (sprintf "\nSending %d alerts..." allAlerts.Count) "INFO"
        for alert in allAlerts do
            sendAlert alert
    elif allAlerts.Count > 0 then
        log (sprintf "\n%d alerts found (use --alert to send)" allAlerts.Count) "INFO"
    else
        log "\nAll nodes healthy!" "INFO"
    
    0
