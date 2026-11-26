// abstraction-provenance: {"artifact_sha256": "c7a472aec463772408f6b4245fc2a96c302fe6780cf5f0f3b0b7e050f716fac0", "source_sha256": "580708ba8136a21db9caeff52911141c9a4f2ed6daed6f9b9dacaaf4beae3f0b", "target_language": "fsharp"}
// setup-xvfb-node2.sh — portiert nach fsharp
// Quelle: shell, OpenClaw@gateway1:scripts/setup-xvfb-node2.sh
// auch in: OpenClaw@gateway2:scripts/setup-xvfb-node2.sh
// auch in: workspace@local:scripts/setup-xvfb-node2.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

// Xvfb Setup für Node 2 (Netcup VPS)
// Erstellt: 2026-04-09

open System
open System.Diagnostics
open System.IO

let runCommand (cmd: string) (args: string) =
    let psi = ProcessStartInfo(cmd, args)
    psi.UseShellExecute <- false
    psi.RedirectStandardOutput <- true
    psi.RedirectStandardError <- true
    use proc = Process.Start(psi)
    proc.WaitForExit()
    if proc.ExitCode <> 0 then
        failwith $"Command failed: {cmd} {args}"

let runCommandWithSudo (args: string) =
    runCommand "sudo" args

[<EntryPoint>]
let main _ =
    try
        printfn "=== Xvfb + Chromium Setup für Node 2 ==="

        // Update & Install
        runCommandWithSudo "apt-get update"
        runCommandWithSudo "apt-get install -y xvfb chromium-browser chromium-chromedriver fonts-liberation libappindicator3-1 libasound2 libatk-bridge2.0-0 libatk1.0-0 libcups2 libgtk-3-0 libnspr4 libnss3 libxss1 xdg-utils"

        // Xvfb Systemd Service erstellen
        let serviceContent = """
[Unit]
Description=X Virtual Framebuffer
After=network.target

[Service]
Type=simple
User=openclaw
ExecStart=/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
"""
        
        File.WriteAllText("/tmp/xvfb.service", serviceContent)
        runCommandWithSudo "mv /tmp/xvfb.service /etc/systemd/system/xvfb.service"

        // Service aktivieren
        runCommandWithSudo "systemctl daemon-reload"
        runCommandWithSudo "systemctl enable xvfb"
        runCommandWithSudo "systemctl start xvfb"

        printfn "=== Xvfb läuft auf DISPLAY :99 ==="
        
        // Try to get Chromium version
        try
            runCommand "chromium-browser" "--version"
        with
        | _ -> printfn "Chromium nicht gefunden"

        printfn "=== Setup abgeschlossen ==="
        0
    with
    | ex ->
        eprintfn "Fehler: %s" ex.Message
        1
