// abstraction-provenance: {"artifact_sha256": "acf90dc68d26b98ae56e870743a46361a21b293d59ad5b24a60eef8c2e82a0c6", "source_sha256": "d5eb18db536b690023fd61c3dfa4d99f899ec602247f48fb044c53baebb78556", "target_language": "fsharp"}
// serve_compare_transfer.sh — portiert nach fsharp
// Quelle: shell, OpenClaw@gateway1:scripts/serve_compare_transfer.sh
// auch in: workspace@local:scripts/serve_compare_transfer.sh
// auch in: workspace@local:vscode/compare/transfer/serve_compare_transfer.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Diagnostics

let COMPARE_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare"
let TRANSFER_DIR = "/home/openclaw/.openclaw/workspace/vscode/compare/transfer"
let HOST_IP = "152.53.145.65"
let PORT = "80"
let SELF_PATH = Path.GetFullPath(System.Reflection.Assembly.GetEntryAssembly().Location)

// Finde alle Dateien im Verzeichnis (ohne Unterverzeichnisse) außer dem Skript selbst
let getFiles () =
    Directory.EnumerateFiles(COMPARE_DIR, "*", SearchOption.TopDirectoryOnly)
    |> Seq.filter (fun f -> f <> SELF_PATH)
    |> Seq.sort

let files = getFiles() |> List.ofSeq

if List.isEmpty files then
    printfn $"Keine Dateien in {COMPARE_DIR} gefunden."
    exit 1

printfn ""
printfn $"Bereitgestellte Dateien aus {COMPARE_DIR}:"
files |> List.iter (fun src -> 
    let fileName = Path.GetFileName(src)
    printfn $"- {fileName}"
)

printfn ""
printfn "Copy/Paste auf anderem Gateway (Download nach {TRANSFER_DIR}):"
files |> List.iter (fun src ->
    let file = Path.GetFileName(src)
    printfn $"curl -fL --retry 3 --connect-timeout 10 -o {TRANSFER_DIR}/{file} http://{HOST_IP}:{PORT}/{file}"
)

printfn ""
printfn $"Server auf Port {PORT} aktiv. Beenden mit STRG+C."
printfn ""

// Starte HTTP Server im Vergleichsverzeichnis
let startServer () =
    let psi = ProcessStartInfo(
        FileName = "python3",
        Arguments = $"-m http.server {PORT} --bind 0.0.0.0",
        WorkingDirectory = COMPARE_DIR,
        UseShellExecute = false
    )
    use proc = Process.Start(psi)
    proc.WaitForExit()

startServer()
