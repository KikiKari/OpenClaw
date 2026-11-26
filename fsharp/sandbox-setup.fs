// abstraction-provenance: {"artifact_sha256": "d369ae4dd84f9a62ba1daba99fd2487bff4978a7026b98bca9117a4acf297051", "source_sha256": "7b2c2cb6fd7efb0ae2db61fbe33805abf06e72ace6dee56ecc1c14b6e6bcf9cf", "target_language": "fsharp"}
// sandbox-setup.sh — portiert nach fsharp
// Quelle: shell, Onboarding@main:scripts/sandbox-setup.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

// Provisioniert die Claude-Code-Sandbox (Remote-Umgebung) reproduzierbar:
//   - Node-Dependencies (Frontend, npm)
//   - Python-Dependencies (Backend inkl. pytest)
//   - Medien-Tools: ffmpeg, ImageMagick, GIMP, Blender headless (apt) —
//     Fehlschlag blockiert die Session nicht; --skip-heavy laesst GIMP/Blender aus
// Idempotent: bereits Vorhandenes wird uebersprungen; der Container-Cache der
// Umgebung macht die apt-Installation zum Einmal-Aufwand.

open System
open System.Diagnostics
open System.IO
open System.Text.RegularExpressions

let private skipHeavy = Array.contains "--skip-heavy" Environment.GetCommandLineArgs()

let private log (message: string) =
    printfn $"[sandbox-setup] {message}"

let private executeCommand (cmd: string) (args: string) =
    let startInfo = ProcessStartInfo(cmd, args)
    startInfo.RedirectStandardOutput <- true
    startInfo.RedirectStandardError <- true
    startInfo.UseShellExecute <- false
    use proc = new Process(StartInfo = startInfo)
    proc.Start() |> ignore
    let output = proc.StandardOutput.ReadToEnd()
    let error = proc.StandardError.ReadToEnd()
    proc.WaitForExit()
    (proc.ExitCode, output, error)

let private runOrExit (description: string) (cmd: string) (args: string) =
    let (exitCode, _, _) = executeCommand cmd args
    if exitCode <> 0 then
        log $"FEHLER: {description} fehlgeschlagen"
        exit 1

let private aptUpdated = ref false

let private aptInstall (pkg: string) (bin: string) =
    let (_, output, _) = executeCommand "which" bin
    if String.IsNullOrWhiteSpace(output) |> not then
        let (_, versionOutput, _) = executeCommand bin "-version"
        let versionLine = versionOutput.Split('\n').[0]
        log $"{pkg} bereits vorhanden ({versionLine})"
        true
    else
        log $"Installiere {pkg} ..."
        if not !aptUpdated.contents then
            let (updateCode, _, _) = executeCommand "apt-get" "update -qq"
            if updateCode = 0 then aptUpdated := true
        if !aptUpdated.contents then
            let envVars = ["DEBIAN_FRONTEND", "noninteractive"]
            let startInfo = ProcessStartInfo("apt-get", $"install -y -qq {pkg}")
            startInfo.EnvironmentVariables.Clear()
            for (k,v) in envVars do startInfo.EnvironmentVariables.Add(k, v)
            startInfo.RedirectStandardOutput <- true
            startInfo.RedirectStandardError <- true
            startInfo.UseShellExecute <- false
            use proc = new Process(StartInfo = startInfo)
            proc.Start() |> ignore
            proc.WaitForExit()
            if proc.ExitCode = 0 then
                true
            else
                log $"WARNUNG: {pkg} konnte nicht installiert werden (Netzwerk-Policy?) — Medien-Schritte ggf. eingeschraenkt"
                false
        else
            false

let private setupNodeDependencies () =
    log "Node-Dependencies (npm install) ..."
    runOrExit "npm install" "npm" "install --no-audit --no-fund"

let private setupPythonDependencies () =
    log "Python-Dependencies (backend/requirements-dev.txt) ..."
    runOrExit "pip install" "pip3" "install --quiet -r backend/requirements-dev.txt"

let private setupMediaTools () =
    aptInstall "ffmpeg" "ffmpeg" |> ignore
    aptInstall "imagemagick" "convert" |> ignore
    if not skipHeavy then
        aptInstall "gimp" "gimp" |> ignore
        aptInstall "blender" "blender" |> ignore

let private setupVisualQA () =
    aptInstall "xvfb" "Xvfb" |> ignore
    aptInstall "x11-utils" "xdpyinfo" |> ignore
    aptInstall "libnss3-tools" "certutil" |> ignore
    
    let (_, chromeOutput, _) = executeCommand "which" "google-chrome-stable"
    if String.IsNullOrWhiteSpace(chromeOutput) then
        log "Installiere Google Chrome Stable ..."
        let tempDeb = Path.GetTempFileName() + ".deb"
        try
            use client = new System.Net.WebClient()
            client.DownloadFile("https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb", tempDeb)
            
            let envVars = ["DEBIAN_FRONTEND", "noninteractive"]
            let startInfo = ProcessStartInfo("apt-get", $"install -y -qq {tempDeb}")
            startInfo.EnvironmentVariables.Clear()
            for (k,v) in envVars do startInfo.EnvironmentVariables.Add(k, v)
            startInfo.RedirectStandardOutput <- true
            startInfo.RedirectStandardError <- true
            startInfo.UseShellExecute <- false
            use proc = new Process(StartInfo = startInfo)
            proc.Start() |> ignore
            proc.WaitForExit()
            
            if proc.ExitCode = 0 then
                let (_, versionOutput, _) = executeCommand "google-chrome-stable" "--version"
                log $"Chrome installiert: {versionOutput.Trim()}"
            else
                log "WARNUNG: Chrome-Installation fehlgeschlagen"
        with
        | :? System.Net.WebException ->
            log "WARNUNG: Chrome-Download fehlgeschlagen (Netzwerk-Policy?)"
        finally
            if File.Exists(tempDeb) then File.Delete(tempDeb)
    
    // Proxy-CA in Chromes NSS-DB
    let (_, certutilOutput, _) = executeCommand "which" "certutil"
    if String.IsNullOrWhiteSpace(certutilOutput) |> not && File.Exists("/root/.ccr/ca-bundle.crt") then
        let homeDir = Environment.GetEnvironmentVariable("HOME")
        let nssdbPath = Path.Combine(homeDir, ".pki/nssdb")
        Directory.CreateDirectory(nssdbPath) |> ignore
        
        let (_, _, _) = executeCommand "certutil" $"-d sql:{nssdbPath} -N --empty-password"
        
        let (_, listOutput, _) = executeCommand "certutil" $"-d sql:{nssdbPath} -L"
        if not (listOutput.Contains("ccr-proxy-ca")) then
            let (_, _, certAddError) = executeCommand "certutil" $"-d sql:{nssdbPath} -A -t \"C,,\" -n ccr-proxy-ca -i /root/.ccr/ca-bundle.crt"
            if String.IsNullOrEmpty(certAddError) then
                log "Proxy-CA in Chrome-NSS-Store importiert"

let private setupPlaywright () =
    if Directory.Exists("node_modules") && not (Directory.Exists("node_modules/playwright")) then
        let (_, npmOutput, _) = executeCommand "which" "npm"
        if String.IsNullOrWhiteSpace(npmOutput) |> not then
            let (_, code, _) = executeCommand "npm" "install --no-audit --no-fund --no-save playwright"
            if code = 0 then
                log "Playwright (Node) installiert"
            else
                log "WARNUNG: Playwright-npm-Install fehlgeschlagen"

let private setupGitPushRoute () =
    let (_, gitOutput, _) = executeCommand "git" "rev-parse --is-inside-work-tree"
    if String.IsNullOrWhiteSpace(gitOutput) |> not then
        let scriptPath = Path.Combine(Environment.CurrentDirectory, ".claude/git-credential-pat.sh")
        executeCommand "git" $"config credential.\"https://x-access-token@github.com\".helper \"!{scriptPath}\""
        executeCommand "git" "remote set-url --push origin \"https://x-access-token@github.com/KikiKari/Onboarding.git\""
        log "Git-Push-Route: direkt zu github.com (PAT via Credential-Helper)"

let private setupDockerDaemon () =
    let (_, dockerdOutput, _) = executeCommand "which" "dockerd"
    if String.IsNullOrWhiteSpace(dockerdOutput) |> not then
        let (_, dockerInfoOutput, _) = executeCommand "docker" "info"
        if String.IsNullOrWhiteSpace(dockerInfoOutput) then
            log "Starte Docker-Daemon (Registry-Mirror: mirror.gcr.io) ..."
            
            Directory.CreateDirectory("/etc/docker") |> ignore
            if not (File.Exists("/etc/docker/daemon.json")) then
                File.WriteAllText("/etc/docker/daemon.json", "{\"registry-mirrors\":[\"https://mirror.gcr.io\"]}")
            
            let startInfo = ProcessStartInfo("dockerd")
            startInfo.RedirectStandardOutput <- true
            startInfo.RedirectStandardError <- true
            startInfo.UseShellExecute <- false
            use proc = new Process(StartInfo = startInfo)
            proc.Start() |> ignore
            
            System.Threading.Thread.Sleep(1000)
            
            let mutable success = false
            for i in 1..15 do
                let (_, infoOutput, _) = executeCommand "docker" "info"
                if String.IsNullOrWhiteSpace(infoOutput) |> not then
                    success <- true
                    break
                System.Threading.Thread.Sleep(1000)
            
            if success then
                log "Docker-Daemon laeuft"
            else
                log "WARNUNG: Docker-Daemon nicht gestartet"

let private printVersions () =
    log "Fertig. Versionen:"
    let (_, nodeVersion, _) = executeCommand "node" "--version"
    if not (String.IsNullOrWhiteSpace(nodeVersion)) then
        log $"  node {nodeVersion.Trim()}"
    
    let (_, pythonVersion, _) = executeCommand "python3" "--version"
    if not (String.IsNullOrWhiteSpace(pythonVersion)) then
        log $"  {pythonVersion.Trim()}"
    
    let (_, ffmpegVersion, _) = executeCommand "ffmpeg" "-version"
    if not (String.IsNullOrWhiteSpace(ffmpegVersion)) then
        log $"  {ffmpegVersion.Split('\n').[0].Trim()}"

    let (_, convertVersion, _) = executeCommand "convert" "-version"
    if not (String.IsNullOrWhiteSpace(convertVersion)) then
        log $"  {convertVersion.Split('\n').[0].Trim()}"
    
    if not skipHeavy then
        let (_, gimpVersion, _) = executeCommand "gimp" "--version"
        if not (String.IsNullOrWhiteSpace(gimpVersion)) then
            log $"  {gimpVersion.Split('\n').[0].Trim()}"
        
        let (_, blenderVersion, _) = executeCommand "blender" "--version"
        if not (String.IsNullOrWhiteSpace(blenderVersion)) then
            log $"  {blenderVersion.Split('\n').[0].Trim()}"

[<EntryPoint>]
let main argv =
    Environment.CurrentDirectory <- Path.Combine(Path.GetDirectoryName(System.Reflection.Assembly.GetEntryAssembly().Location), "..")
    
    setupNodeDependencies()
    setupPythonDependencies()
    setupMediaTools()
    setupVisualQA()
    setupPlaywright()
    setupGitPushRoute()
    setupDockerDaemon()
    printVersions()
    
    0
