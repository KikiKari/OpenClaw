// abstraction-provenance: {"artifact_sha256": "9ff36410ada13f0abc11b4ec1b59f44d04438c4ece7c1b5de9a85fdfb417be4a", "source_sha256": "25e94789e3af346018b091c7c4d6d65632394c19fcf9eaaeac876efbe534149a", "target_language": "fsharp"}
// bundle-a2ui.sh — portiert nach fsharp
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/bundle-a2ui.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

open System
open System.Diagnostics
open System.IO

let rootDir = 
    let scriptDir = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location)
    Path.GetFullPath(Path.Combine(scriptDir, ".."))

let nodeScriptPath = Path.Combine(rootDir, "scripts", "bundle-a2ui.mjs")

let startInfo = ProcessStartInfo(
    FileName = "node",
    Arguments = sprintf "\"%s\" %s" nodeScriptPath (String.concat " " Environment.GetCommandLineArgs()[1..]),
    UseShellExecute = false
)

try
    use process = Process.Start(startInfo)
    process.WaitForExit()
    exit process.ExitCode
with
| ex -> 
    eprintfn "Error: %s" ex.Message
    exit 1
