// abstraction-provenance: {"artifact_sha256": "b8e9bf1a93bc4317aab89d4028f7bdf0db304c71483fb22399308c0c00740058", "source_sha256": "daf22c296c801d3d533083361cc59fbdc22e5bfe528aa4bad1973b54cc5448a4", "target_language": "fsharp"}
// index.css — portiert nach fsharp
// Quelle: css, OpenClaw@main:src/index.css
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

open System
open System.IO

type CssRule = {
    Selector: string
    Properties: Map<string, string>
}

type StyleSheet = CssRule list

let createCssRule selector properties =
    { Selector = selector; Properties = Map.ofList properties }

let toString (styleSheet: StyleSheet) =
    let formatRule rule =
        let props = 
            rule.Properties 
            |> Map.toList
            |> List.map (fun (key, value) -> $"  {key}: {value};")
            |> String.concat "\n"
        $"{rule.Selector} {{\n{props}\n}}"

    styleSheet |> List.map formatRule |> String.concat "\n\n"

let styleSheet : StyleSheet = [
    createCssRule "body" [
        "margin", "0"
        "font-family", "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue', sans-serif"
        "-webkit-font-smoothing", "antialiased"
        "-moz-osx-font-smoothing", "grayscale"
    ]
    createCssRule "code" [
        "font-family", "source-code-pro, Menlo, Monaco, Consolas, 'Courier New', monospace"
    ]
]

[<EntryPoint>]
let main argv =
    let cssContent = toString styleSheet
    
    match argv with
    | [| filename |] -> 
        File.WriteAllText(filename, cssContent)
        printfn "CSS file written to %s" filename
    | _ -> 
        printfn "Usage: program <output-filename>"
        printfn "Generated CSS:"
        printfn "%s" cssContent
    
    0
