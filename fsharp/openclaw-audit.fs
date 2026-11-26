// abstraction-provenance: {"artifact_sha256": "f15414096e356621dcd84c68470095d0e4081a6960b22bdbf5e531b9988711ae", "source_sha256": "e51b94641336291974fe14bf4bb7299a75ec7dcce49e1d413282c8043e9f09f1", "target_language": "fsharp"}
// openclaw-audit.sh — portiert nach fsharp
// Quelle: shell, OpenClaw@gateway1:scripts/openclaw-audit.sh
// auch in: OpenClaw@gateway2:scripts/openclaw-audit.sh
// auch in: workspace@local:scripts/openclaw-audit.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

open System
open System.Diagnostics
open System.IO
open System.Text

let runCommand (cmd: string) (args: string) : string =
    let startInfo = ProcessStartInfo(cmd, args)
    startInfo.RedirectStandardOutput <- true
    startInfo.RedirectStandardError <- true
    startInfo.UseShellExecute <- false
    startInfo.CreateNoWindow <- true

    use proc = new Process()
    proc.StartInfo <- startInfo
    proc.Start() |> ignore

    let output = proc.StandardOutput.ReadToEnd()
    let error = proc.StandardError.ReadToEnd()
    proc.WaitForExit()

    if String.IsNullOrEmpty(error) then
        output
    else
        output + "\n" + error

let getTimestamp() =
    DateTime.Now.ToString("yyyy-MM-ddTHH:mm:ss")

let getDateStamp() =
    DateTime.Now.ToString("yyyy-MM-dd")

let getScriptDir() =
    Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location)

let writeHeader (writer: StreamWriter) =
    let version = try runCommand "openclaw" "--version" with _ -> "unknown"
    writer.WriteLine("================================================================")
    writer.WriteLine("OpenClaw audit run")
    writer.WriteLine($"Started:  {getTimestamp()}")
    writer.WriteLine($"Host:     {Environment.MachineName}")
    writer.WriteLine($"User:     {Environment.UserName}")
    writer.WriteLine($"Version:  {version.Trim()}")
    writer.WriteLine($"Output:   {Path.Combine(getScriptDir(), $"openclaw-audit-{getDateStamp()}.log")}")
    writer.WriteLine("================================================================")

let runCmd (writer: StreamWriter) (title: string) (cmd: string) (args: string) =
    writer.WriteLine()
    writer.WriteLine("----------------------------------------------------------------")
    writer.WriteLine($"### {title}")
    writer.WriteLine($"### $ {cmd} {args}")
    writer.WriteLine($"### {getTimestamp()}")
    writer.WriteLine("----------------------------------------------------------------")

    try
        let output = runCommand cmd args
        writer.WriteLine(output)
        writer.WriteLine("[exit: 0]")
    with
    | ex ->
        writer.WriteLine($"Error executing command: {ex.Message}")
        writer.WriteLine("[exit: 1]")

[<EntryPoint>]
let main _ =
    let scriptDir = getScriptDir()
    let dateStamp = getDateStamp()
    let outFile = Path.Combine(scriptDir, $"openclaw-audit-{dateStamp}.log")

    using (new StreamWriter(outFile, false, Encoding.UTF8)) (fun writer ->
        writeHeader writer

        let oc = "openclaw"

        runCmd writer "tasks audit --severity error" oc "tasks audit --severity error --no-color"
        runCmd writer "secrets audit" oc "secrets audit --no-color"
        runCmd writer "security audit" oc "security audit --no-color"
        runCmd writer "plugins doctor" oc "plugins doctor --no-color"
        runCmd writer "plugins deps" oc "plugins deps --no-color"
        runCmd writer "plugins registry" oc "plugins registry --no-color"
        runCmd writer "skills check" oc "skills check --no-color"
        runCmd writer "hooks check" oc "hooks check --no-color"
        runCmd writer "gateway status --deep" oc "gateway status --deep --no-color"
        runCmd writer "channels status --probe" oc "channels status --probe --no-color"
        runCmd writer "memory status --deep" oc "memory status --deep --no-color"
        runCmd writer "sessions --all-agents" oc "sessions --all-agents --no-color"
        runCmd writer "tasks list" oc "tasks list --no-color"
        runCmd writer "cron list" oc "cron list --no-color"

        writer.WriteLine()
        writer.WriteLine("================================================================")
        writer.WriteLine($"Audit complete: {getTimestamp()}")
        writer.WriteLine("================================================================")
    )

    printfn $"Audit complete. Output: {outFile}"
    0
