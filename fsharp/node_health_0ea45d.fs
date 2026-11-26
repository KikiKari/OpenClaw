// abstraction-provenance: {"artifact_sha256": "afdb84babec018d5f6a782ef0ef4e05c18971ff916fb4ceb59c4856996db8f1c", "source_sha256": "0ea45de4496e55f73aa9b10188cc6a04921d74e1cadbe0ac04a948d0f2772243", "target_language": "fsharp"}
// node_health.py — portiert nach fsharp
// Quelle: python, OpenClaw@gateway2:skills/node-health-monitor/scripts/node_health.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

open  System
open  System.Diagnostics
open  System.IO
open  System.Text.Json
open  System.Text.Json.Serialization

// Konfiguration
let workspace = "/home/openclaw/.openclaw/workspace"
let healthDb = Path.Combine(workspace, "db", "health.db")
let logFile = Path.Combine(workspace, "logs", "node-health.log")

// Node-Definitionen
type NodeConfig = {
    name: string
    host: string
    user: string
    port: int option
    ssh_key: string option
    ssh_opts: string option
    critical: bool option
    optional: bool option
    disk_warning: int option
}

let nodes = Map [
    ("node1", { 
        name = "Node 1"
        host = "localhost"
        user = "openclaw"
        port = None
        ssh_key = None
        ssh_opts = None
        critical = Some true
        optional = None
        disk_warning = None
    })
    ("node2", {
        name = "Node 2"
        host = "10.10.0.2"
        user = "root"
        port = None
        ssh_key = Some "~/.ssh/id_rsa"
        ssh_opts = Some "-o ConnectTimeout=10 -o BatchMode=yes"
        critical = None
        optional = None
        disk_warning = None
    })
    ("node3", {
        name = "Node 3"
        host = "localhost"
        user = "root"
        port = Some 18794
        ssh_key = None
        ssh_opts = Some "-p 18794 -o ConnectTimeout=10 -o BatchMode=yes"
        critical = None
        optional = None
        disk_warning = Some 85
    })
    ("node5", {
        name = "Redmi"
        host = "192.168.1.x"
        user = "openclaw"
        port = None
        ssh_key = None
        ssh_opts = None
        critical = None
        optional = Some true
        disk_warning = None
    })
]

type Metrics = {
    timestamp: string
    available: bool
    cpu: float option
    ram: float option
    disk: int option
    load: float option
    gateway_status: string option
}

type Alert = {
    level: string
    message: string
}

let log (message: string) (level: string) =
    let timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")
    let entry = sprintf "[%s] [%s] %s" timestamp level message
    printfn "%s" entry
    let logDir = Path.GetDirectoryName(logFile)
    Directory.CreateDirectory(logDir) |> ignore
    File.AppendAllText(logFile, entry + "\n")

let checkPing (host: string) (timeout: int) : bool =
    try
        let psi = ProcessStartInfo("ping", sprintf "-c 1 -W %d %s" timeout host)
        psi.UseShellExecute <- false
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        use proc = Process.Start(psi)
        proc.WaitForExit()
        proc.ExitCode = 0
    with
    | _ -> false

let checkSsh (nodeConfig: NodeConfig) : bool =
    let host = nodeConfig.host
    let user = defaultArg (Some nodeConfig.user) "root"
    let sshOpts = defaultArg nodeConfig.ssh_opts ""
    let portOpt = nodeConfig.port
    
    let cmdArgs = 
        let baseCmd = ["ssh"]
        let opts = if not (String.IsNullOrEmpty(sshOpts)) then sshOpts.Split(' ') |> List.ofArray else []
        let portCmd = match portOpt with Some p -> ["-p"; string p] | None -> []
        let finalCmd = baseCmd @ opts @ portCmd @ ["-o"; "ConnectTimeout=10"; "-o"; "BatchMode=yes"; sprintf "%s@%s" user host; "echo"; "\"OK\""]
        String.concat " " finalCmd
    
    try
        let psi = ProcessStartInfo("bash", sprintf "-c \"%s\"" cmdArgs)
        psi.UseShellExecute <- false
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        use proc = Process.Start(psi)
        let output = proc.StandardOutput.ReadToEnd()
        proc.WaitForExit()
        proc.ExitCode = 0 && output.Contains("OK")
    with
    | _ -> false

let getNodeMetrics (nodeConfig: NodeConfig) : Metrics =
    let host = nodeConfig.host
    let user = defaultArg (Some nodeConfig.user) "root"
    
    let metrics = {
        timestamp = DateTime.Now.ToString("o")
        available = false
        cpu = None
        ram = None
        disk = None
        load = None
        gateway_status = None
    }
    
    let cmd = sprintf """ssh -o ConnectTimeout=10 %s@%s '
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
    '""" user host
    
    try
        let psi = ProcessStartInfo("bash", sprintf "-c \"%s\"" cmd)
        psi.UseShellExecute <- false
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        use proc = Process.Start(psi)
        let outputTask = proc.StandardOutput.ReadToEndAsync()
        let errorTask = proc.StandardError.ReadToEndAsync()
        if proc.WaitForExit(15000) then
            let output = outputTask.Result
            if proc.ExitCode = 0 then
                let mutable newMetrics = { metrics with available = true }
                for line in output.Trim().Split('\n') do
                    if line.Contains(":") then
                        let parts = line.Split(':')
                        let key = parts.[0].Trim()
                        let value = parts.[1].Trim()
                        match key with
                        | "CPU" -> 
                            if not (String.IsNullOrEmpty(value)) then
                                match Double.TryParse(value) with
                                | (true, v) -> newMetrics <- { newMetrics with cpu = Some v }
                                | _ -> ()
                        | "RAM" -> 
                            if not (String.IsNullOrEmpty(value)) then
                                match Double.TryParse(value) with
                                | (true, v) -> newMetrics <- { newMetrics with ram = Some v }
                                | _ -> ()
                        | "DISK" -> 
                            if not (String.IsNullOrEmpty(value)) then
                                match Int32.TryParse(value) with
                                | (true, v) -> newMetrics <- { newMetrics with disk = Some v }
                                | _ -> ()
                        | "LOAD" -> 
                            if not (String.IsNullOrEmpty(value)) then
                                match Double.TryParse(value) with
                                | (true, v) -> newMetrics <- { newMetrics with load = Some v }
                                | _ -> ()
                        | "GATEWAY" -> newMetrics <- { newMetrics with gateway_status = Some value }
                        | _ -> ()
                newMetrics
            else
                metrics
        else
            log (sprintf "SSH timeout for %s" nodeConfig.name) "WARN"
            metrics
    with
    | ex -> 
        log (sprintf "Error checking %s: %s" nodeConfig.name ex.Message) "ERROR"
        metrics

let checkAlerts (nodeId: string) (nodeConfig: NodeConfig) (metrics: Metrics) : Alert list =
    let alerts = ResizeArray<Alert>()
    
    // Verfügbarkeit
    if not metrics.available then
        if not (defaultArg nodeConfig.optional false) then
            alerts.Add({ level = "CRITICAL"; message = sprintf "Node %s nicht erreichbar!" nodeConfig.name })
    else
        // CPU
        match metrics.cpu with
        | Some cpu when cpu > 90.0 ->
            alerts.Add({ level = "WARNING"; message = sprintf "Node %s: CPU bei %.1f%%" nodeConfig.name cpu })
        | _ -> ()
        
        // RAM
        match metrics.ram with
        | Some ram when ram > 90.0 ->
            alerts.Add({ level = "WARNING"; message = sprintf "Node %s: RAM bei %.1f%%" nodeConfig.name ram })
        | _ -> ()
        
        // Disk
        let diskThreshold = defaultArg nodeConfig.disk_warning 85
        match metrics.disk with
        | Some disk when disk > diskThreshold ->
            let level = if disk > 95 then "CRITICAL" else "WARNING"
            alerts.Add({ level = level; message = sprintf "Node %s: Disk bei %d%%" nodeConfig.name disk })
        | _ -> ()
        
        // Gateway
        if (defaultArg nodeConfig.critical false) && (match metrics.gateway_status with Some "inactive" -> true | _ -> false) then
            alerts.Add({ level = "CRITICAL"; message = sprintf "Node %s: OpenClaw Gateway nicht aktiv!" nodeConfig.name })
    
    List.ofSeq alerts

let sendAlert (alert: Alert) =
    try
        let scriptPath = Path.Combine(workspace, "skills", "channel-status-agent", "scripts", "channel_status.py")
        let cmdArgs = sprintf "python3 \"%s\" --type alert --message \"%s: %s\"" scriptPath alert.level alert.message
        
        let psi = ProcessStartInfo("bash", sprintf "-c \"%s\"" cmdArgs)
        psi.UseShellExecute <- false
        psi.RedirectStandardOutput <- true
        psi.RedirectStandardError <- true
        use proc = Process.Start(psi)
        proc.WaitForExit() |> ignore
        log (sprintf "Alert sent: %s" alert.message) "INFO"
    with
    | ex -> log (sprintf "Failed to send alert: %s" ex.Message) "ERROR"

[<EntryPoint>]
let main argv =
    let args = argv |> List.ofArray
    
    let mutable nodeArg = "all"
    let mutable checkArg = "all"
    let mutable sendAlerts = false
    
    let rec parseArgs remaining =
        match remaining with
        | "--node" :: value :: rest -> nodeArg <- value; parseArgs rest
        | "--check" :: value :: rest -> checkArg <- value; parseArgs rest
        | "--alert" :: rest -> sendAlerts <- true; parseArgs rest
        | _ :: rest -> parseArgs rest
        | [] -> ()
    
    parseArgs (List.tail args) // Skip program name
    
    let nodesToCheck = 
        if nodeArg = "all" then
            Map.toList nodes
        else
            match Map.tryFind nodeArg nodes with
            | Some config -> [(nodeArg, config)]
            | None -> 
                log (sprintf "Unknown node: %s" nodeArg) "ERROR"
                exit 1
    
    let allAlerts = ResizeArray<Alert>()
    
    for (nodeId, nodeConfig) in nodesToCheck do
        log (sprintf "Checking %s (%s)" nodeConfig.name nodeId) "INFO"
        
        // Ping
        if (checkArg = "ping" || checkArg = "all") && nodeConfig.host <> "localhost" then
            let pingOk = checkPing nodeConfig.host 10
            log (sprintf "  Ping: %s" (if pingOk then "OK" else "FAILED")) "INFO"
        
        // SSH
        if checkArg = "ssh" || checkArg = "all" then
            let sshOk = checkSsh nodeConfig
            log (sprintf "  SSH: %s" (if sshOk then "OK" else "FAILED")) "INFO"
        
        // Metriken
        if checkArg = "metrics" || checkArg = "all" then
            let metrics = getNodeMetrics nodeConfig
            
            if metrics.available then
                match metrics.cpu with Some cpu -> log (sprintf "  CPU: %.1f%%" cpu) "INFO" | None -> log "  CPU: N/A" "INFO"
                match metrics.ram with Some ram -> log (sprintf "  RAM: %.1f%%" ram) "INFO" | None -> log "  RAM: N/A" "INFO"
                match metrics.disk with Some disk -> log (sprintf "  Disk: %d%%" disk) "INFO" | None -> log "  Disk: N/A" "INFO"
                match metrics.load with Some load -> log (sprintf "  Load: %.2f" load) "INFO" | None -> log "  Load: N/A" "INFO"
            else
                log "  Metrics: UNAVAILABLE" "INFO"
            
            // Alerts prüfen
            let alerts = checkAlerts nodeId nodeConfig metrics
            for alert in alerts do
                allAlerts.Add(alert)
    
    // Alerts senden
    if sendAlerts && Seq.length allAlerts > 0 then
        log (sprintf "\nSending %d alerts..." (Seq.length allAlerts)) "INFO"
        for alert in allAlerts do
            sendAlert alert
    elif Seq.length allAlerts > 0 then
        log (sprintf "\n%d alerts found (use --alert to send)" (Seq.length allAlerts)) "INFO"
    else
        log "\nAll nodes healthy!" "INFO"
    
    0
