// abstraction-provenance: {"artifact_sha256": "828349689ab94f2f74e19ee43877f590033d62be667494350aa1e677d2f20263", "source_sha256": "13f974bf78b140bc88bd9f3afe27c500660ef59498ed533c38c18bca0c6f6331", "target_language": "fsharp"}
// changelog-to-html.sh — portiert nach fsharp
// Quelle: shell, workspace@local:skills/github-clones/openclaw/scripts/changelog-to-html.sh
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO
open System.Text.RegularExpressions

let getVersion () =
    match Array.length fsi.CommandLineArgs with
    | 2 -> fsi.CommandLineArgs.[1], ""
    | 3 -> fsi.CommandLineArgs.[1], fsi.CommandLineArgs.[2]
    | _ -> "", ""

let findChangelogFile (scriptDir: string) =
    let paths = [
        Path.Combine(scriptDir, "..", "CHANGELOG.md")
        "CHANGELOG.md"
        Path.Combine("..", "CHANGELOG.md")
    ]
    paths |> List.tryFind File.Exists

let extractVersionSection (version: string) (file: string) =
    use reader = new StreamReader(file)
    let mutable found = false
    let mutable result = ""
    let versionRegex = Regex("^##\\s+" + Regex.Escape(version) + "(\\s.*|$)")
    
    while not reader.EndOfStream do
        let line = reader.ReadLine()
        if line.StartsWith("## ") then
            if versionRegex.IsMatch(line) then
                found <- true
            elif found then
                break
        elif found then
            result <- result + line + "\n"
    
    result.Trim()

let markdownToHtml (text: string) =
    let replacements = [
        ("^##### (.*)$", "<h5>$1</h5>")
        ("^#### (.*)$", "<h4>$1</h4>")
        ("^### (.*)$", "<h3>$1</h3>")
        ("^## (.*)$", "<h2>$1</h2>")
        ("- \\*\\*([^*]*)\\*\\*(.*)$", "<li><strong>$1</strong>$2</li>")
        ("- ([^*].*)$", "<li>$1</li>")
        ("\\*\\*([^*]*)\\*\\*", "<strong>$1</strong>")
        ("`([^`]*)`", "<code>$1</code>")
        ("\\[([^\\]]*)\\]\\(([^\\)]*)\\)", "<a href=\"$2\">$1</a>")
    ]
    
    let mutable result = text
    for (pattern, replacement) in replacements do
        result <- Regex.Replace(result, pattern, replacement)
    result

[<EntryPoint>]
let main argv =
    let version, changelogFile = getVersion()
    
    if String.IsNullOrEmpty(version) then
        eprintfn "Usage: %s <version> [changelog_file]" fsi.CommandLineArgs.[0]
        exit 1
    
    let scriptDir = Directory.GetParent(System.Reflection.Assembly.GetExecutingAssembly().Location).FullName
    let changelogPath = 
        if not (String.IsNullOrEmpty(changelogFile)) then
            changelogFile
        else
            match findChangelogFile scriptDir with
            | Some path -> path
            | None -> 
                eprintfn "Error: Could not find CHANGELOG.md"
                exit 1
    
    if not (File.Exists(changelogPath)) then
        eprintfn "Error: Changelog file '%s' not found" changelogPath
        exit 1
    
    let versionContent = extractVersionSection version changelogPath
    
    if String.IsNullOrEmpty(versionContent) then
        printfn "<h2>OpenClaw %s</h2>" version
        printfn "<p>Latest OpenClaw update.</p>"
        printfn "<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>"
        exit 0
    
    printfn "<h2>OpenClaw %s</h2>" version
    
    let lines = versionContent.Split('\n')
    let mutable inList = false
    
    for line in lines do
        if line.StartsWith("-") then
            if not inList then
                printfn "<ul>"
                inList <- true
            printfn "%s" (markdownToHtml line)
        else
            if inList then
                printfn "</ul>"
                inList <- false
            if not (String.IsNullOrWhiteSpace(line)) then
                printfn "%s" (markdownToHtml line)
    
    if inList then
        printfn "</ul>"
    
    printfn "<p><a href=\"https://github.com/openclaw/openclaw/blob/main/CHANGELOG.md\">View full changelog</a></p>"
    0
