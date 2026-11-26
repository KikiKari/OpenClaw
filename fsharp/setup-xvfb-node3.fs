// abstraction-provenance: {"artifact_sha256": "1a9237fe18fa9fc2ebe7c646f528547526c5e03db982d8c5185d3fa317b4c838", "source_sha256": "f85931ea8f1a58309ac3ba2c5899fd4b8f2c55777f90b132269efd74bb35362b", "target_language": "fsharp"}
// setup-xvfb-node3.sh — portiert nach fsharp
// Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node3.sh
// auch in: OpenClaw@gateway2:scripts/setup-xvfb-node3.sh
// auch in: workspace@local:scripts/setup-xvfb-node3.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

// Xvfb Setup für Node 3 (xNetX VPS)
// Erstellt: 2026-04-09
// Hinweis: Altes VNC-Setup wird entfernt

open System
open System.Diagnostics
open System.IO

let runCommand (cmd: string) (args: string) =
    let psi = ProcessStartInfo(cmd, args)
    psi.UseShellExecute <- false
    psi.RedirectStandardOutput <- true
    psi.RedirectStandardError <- true
    let proc = Process.Start(psi)
    proc.WaitForExit()
    proc.ExitCode

let runCommandIgnoreError (cmd: string) (args: string) =
    try
        runCommand cmd args |> ignore
    with _ -> ()

let writeFile (path: string) (content: string) =
    use writer = new StreamWriter(path)
    writer.Write(content)

[<EntryPoint>]
let main _ =
    printfn "=== Xvfb + Chromium Setup für Node 3 ==="
    printfn "=== Entferne altes VNC-Setup ==="

    // Altes VNC stoppen & entfernen (falls vorhanden)
    runCommandIgnoreError "sudo" "systemctl stop vncserver@*"
    runCommandIgnoreError "sudo" "systemctl disable vncserver@*"
    runCommandIgnoreError "sudo" "apt-get remove -y tightvncserver tigervnc-standalone-server"
    runCommandIgnoreError "sudo" "rm -rf ~/.vnc /tmp/.X11-unix/X*"

    printfn "=== Installiere Xvfb + Chromium ==="

    // Update & Install
    runCommand "sudo" "apt-get update" |> ignore
    runCommand "sudo" "apt-get install -y xvfb chromium chromium-driver fonts-liberation libappindicator3-1 libasound2 libatk-bridge2.0-0 libatk1.0-0 libcups2 libgtk-3-0 libnspr4 libnss3 libxss1 xdg-utils" |> ignore

    // Xvfb Systemd Service erstellen
    let serviceContent = """
[Unit]
Description=X Virtual Framebuffer
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
"""
    
    writeFile "/etc/systemd/system/xvfb.service" serviceContent

    // Service aktivieren
    runCommand "sudo" "systemctl daemon-reload" |> ignore
    runCommand "sudo" "systemctl enable xvfb" |> ignore
    runCommand "sudo" "systemctl start xvfb" |> ignore

    printfn "=== Xvfb läuft auf DISPLAY :99 ==="
    printfn "Chromium Version:"
    
    match runCommand "chromium" "--version" with
    | 0 -> () // Success, output already printed
    | _ -> printfn "Chromium nicht gefunden"

    printfn "=== Setup abgeschlossen ==="
    printfn "=== Altes VNC-Setup wurde entfernt ==="
    
    0
